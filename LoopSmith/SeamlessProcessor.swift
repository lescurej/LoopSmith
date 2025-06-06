import Foundation
import AVFoundation
import Accelerate

struct SeamlessProcessor {
    static func process(inputURL: URL,
                        outputURL: URL,
                        fadeDurationMs: Double,
                        format: AudioFileFormat,
                        crossfadeMode: CrossfadeMode,
                        bpm: Double?,
                        progress: ((Double) -> Void)? = nil,
                        completion: @escaping (Result<Double, Error>) -> Void) {

        let workItem = DispatchWorkItem {
            do {
                DispatchQueue.main.async {
                    progress?(0.0)
                }
                // 1. Reading the source audio file
                let inputFile = try AVAudioFile(forReading: inputURL)
                let formatDesc = inputFile.processingFormat
                let totalFrames = AVAudioFrameCount(inputFile.length)
                let sampleRate = formatDesc.sampleRate
                let numChannels = Int(formatDesc.channelCount)

                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: formatDesc, frameCapacity: totalFrames) else {
                    throw NSError(domain: "SeamlessProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate input buffer"])
                }

                try inputFile.read(into: inputBuffer)

                guard let inputChannels = inputBuffer.floatChannelData else {
                    throw NSError(domain: "SeamlessProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to access audio data"])
                }

                let total = Int(totalFrames)
                let midFrame = total / 2
                var fadeSamples = max(1, Int(sampleRate * fadeDurationMs / 1000.0))

                let beatDetection = (crossfadeMode == .beatDetection)
                let spectral = (crossfadeMode == .spectral)

                if beatDetection, let bpm = bpm {
                    let beatFrames = Int(sampleRate * 60.0 / bpm)
                    if beatFrames > 0 {
                        let multiples = max(1, Int(round(Double(fadeSamples) / Double(beatFrames))))
                        fadeSamples = multiples * beatFrames
                    }
                }

                var offsetFrames = 0
                if beatDetection {
                    let searchRange = min(fadeSamples, max(0, total - fadeSamples * 2))
                    if searchRange > 0, numChannels > 0 {
                        let channel = inputChannels[0]
                        var bestScore: Float = .greatestFiniteMagnitude
                        let step: Int
                        if let bpm = bpm {
                            step = max(1, Int(sampleRate * 60.0 / bpm))
                        } else {
                            step = 1
                        }
                        var off = -searchRange
                        while off <= searchRange {
                            let endStart = total - fadeSamples + off
                            if endStart >= 0 && endStart + fadeSamples <= total {
                                var diff: Float = 0
                                vDSP_distancesq(channel + endStart, 1, channel, 1, &diff, vDSP_Length(fadeSamples))
                                if diff < bestScore {
                                    bestScore = diff
                                    offsetFrames = off
                                }
                            }
                            off += step
                        }
                    }
                }

                if spectral, numChannels > 0 {
                    let channel = inputChannels[0]
                    offsetFrames = SpectralLoopAnalyzer.bestOffset(
                        channel: channel,
                        totalFrames: total,
                        fadeSamples: fadeSamples)
                }

                // 2. Creating the output buffer
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: formatDesc, frameCapacity: totalFrames) else {
                    throw NSError(domain: "SeamlessProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate output buffer"])
                }

                outputBuffer.frameLength = totalFrames

                guard let outputChannels = outputBuffer.floatChannelData else {
                    throw NSError(domain: "SeamlessProcessor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to access output buffer"])
                }

                // 3. Parallel processing by channel
                for ch in 0..<numChannels {
                    let input = inputChannels[ch]
                    let output = outputChannels[ch]

                    // Initial copy of the complete file
                    output.assign(from: input, count: total)

                    // Calculating fade length
                    let fade = min(fadeSamples, total / 2)
                    let rightLen = total - midFrame

                    // Fade between end and beginning of file (constant gain)
                    if fade > 1 {
                        let endStart = total - fade + offsetFrames
                        for i in 0..<fade {
                            let t = Float(i) / Float(fade - 1)
                            let fadeOut = 1.0 - t
                            let fadeIn = t
                            let endIdx = endStart + i
                            let endSample = input[endIdx]
                            let startSample = input[i]
                            output[endIdx] = endSample * fadeOut + startSample * fadeIn
                        }
                    }

                    // Shifting the file so the fade zone is centered
                    let temp = UnsafeMutablePointer<Float>.allocate(capacity: total)
                    temp.initialize(repeating: 0, count: total)
                    defer { temp.deallocate() }

                    temp.assign(from: output + midFrame, count: rightLen)
                    temp.advanced(by: rightLen).assign(from: output, count: midFrame)
                    output.assign(from: temp, count: total)

                    // Progress callback
                    let percent = Double(ch + 1) / Double(numChannels)
                    DispatchQueue.main.async {
                        progress?(percent)
                    }
                }

                // 4. Converting to interleaved buffer if needed
                let isAIFF = (format == .aiff)
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: numChannels,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsNonInterleaved: false,
                    AVLinearPCMIsBigEndianKey: isAIFF
                ]

                guard let interleavedFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                             sampleRate: sampleRate,
                                                             channels: formatDesc.channelCount,
                                                             interleaved: true),
                      let interleavedBuffer = AVAudioPCMBuffer(pcmFormat: interleavedFormat,
                                                                frameCapacity: outputBuffer.frameCapacity) else {
                    throw NSError(domain: "SeamlessProcessor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Error creating interleaved buffer"])
                }

                interleavedBuffer.frameLength = outputBuffer.frameLength

                let frames = Int(interleavedBuffer.frameLength)
                let dst = interleavedBuffer.floatChannelData![0]

                for ch in 0..<numChannels {
                    let src = outputChannels[ch]
                    for frame in 0..<frames {
                        dst[frame * numChannels + ch] = src[frame]
                    }
                }

                // 5. Writing the file
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }

                switch format {
                case .wav, .aiff:
                    let outputFile = try AVAudioFile(forWriting: outputURL,
                                                     settings: settings,
                                                     commonFormat: .pcmFormatFloat32,
                                                     interleaved: true)
                    try outputFile.write(from: interleavedBuffer)
                }

                let centerFrame = Double(midFrame - fadeSamples / 2 + offsetFrames)
                let centerTime = centerFrame / sampleRate
                completion(.success(centerTime))
            } catch {
                completion(.failure(error))
            }
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
}

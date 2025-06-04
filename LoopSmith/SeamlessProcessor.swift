import Foundation
import AVFoundation
import Accelerate

struct SeamlessProcessor {
    static func process(inputURL: URL,
                        outputURL: URL,
                        fadeDurationMs: Double,
                        format: AudioFileFormat,
                        progress: ((Double) -> Void)? = nil,
                        completion: @escaping (Result<Void, Error>) -> Void) {

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                DispatchQueue.main.async {
                    progress?(0.0)
                }
                // 1. Lecture du fichier audio source
                let inputFile = try AVAudioFile(forReading: inputURL)
                let formatDesc = inputFile.processingFormat
                let totalFrames = AVAudioFrameCount(inputFile.length)
                let sampleRate = formatDesc.sampleRate
                let numChannels = Int(formatDesc.channelCount)

                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: formatDesc, frameCapacity: totalFrames) else {
                    throw NSError(domain: "SeamlessProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Impossible d'allouer le buffer d'entrée"])
                }

                try inputFile.read(into: inputBuffer)

                guard let inputChannels = inputBuffer.floatChannelData else {
                    throw NSError(domain: "SeamlessProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impossible d'accéder aux données audio"])
                }

                let total = Int(totalFrames)
                let midFrame = total / 2
                let fadeSamples = max(1, Int(sampleRate * fadeDurationMs / 1000.0))

                // 2. Création du buffer de sortie
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: formatDesc, frameCapacity: totalFrames) else {
                    throw NSError(domain: "SeamlessProcessor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Impossible d'allouer le buffer de sortie"])
                }

                outputBuffer.frameLength = totalFrames

                guard let outputChannels = outputBuffer.floatChannelData else {
                    throw NSError(domain: "SeamlessProcessor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Impossible d'accéder au buffer de sortie"])
                }

                // 3. Traitement parallèle par canal
                for ch in 0..<numChannels {
                    let input = inputChannels[ch]
                    let output = outputChannels[ch]

                    let rightLen = total - midFrame
                    cblas_scopy(Int32(rightLen), input + midFrame, 1, output, 1)
                    cblas_scopy(Int32(midFrame), input, 1, output + rightLen, 1)

                    let crossfadeStart = rightLen - fadeSamples / 2
                    let start = max(0, crossfadeStart)
                    let fadeLength = min(total - start, fadeSamples)

                    var fadeIn = [Float](repeating: 0, count: fadeLength)
                    var fadeOut = [Float](repeating: 0, count: fadeLength)

                    vDSP_vgen([0.0], [1.0], &fadeIn, 1, vDSP_Length(fadeLength))
                    vDSP_vgen([1.0], [0.0], &fadeOut, 1, vDSP_Length(fadeLength))

                    var fadeLeft = [Float](repeating: 0, count: fadeLength)
                    var fadeRight = [Float](repeating: 0, count: fadeLength)

                    vDSP_vmul(input, 1, fadeIn, 1, &fadeLeft, 1, vDSP_Length(fadeLength))
                    vDSP_vmul(output + start, 1, fadeOut, 1, &fadeRight, 1, vDSP_Length(fadeLength))
                    vDSP_vadd(fadeLeft, 1, fadeRight, 1, output + start, 1, vDSP_Length(fadeLength))

                    // Appel du callback de progression
                    let percent = Double(ch + 1) / Double(numChannels)
                    DispatchQueue.main.async {
                        progress?(percent)
                    }
                }

                // 4. Conversion en buffer interleaved si nécessaire
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
                    throw NSError(domain: "SeamlessProcessor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Erreur lors de la création du buffer interleaved"])
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

                // 5. Écriture du fichier
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
                case .mp3:
                    throw NSError(domain: "SeamlessProcessor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Le format MP3 n'est pas pris en charge en écriture"])
                }

                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

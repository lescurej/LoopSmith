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

                    // Copie initiale du fichier complet
                    cblas_scopy(Int32(total), input, 1, output, 1)

                    // Calcul de la longueur de fondu
                    let fade = min(fadeSamples, total / 2)
                    let rightLen = total - midFrame

                    // Fondu entre la fin et le début du fichier (gain constant)
                    if fade > 1 {
                        for i in 0..<fade {
                            let t = Float(i) / Float(fade - 1)
                            let fadeOut = 1.0 - t
                            let fadeIn = t
                            let endIdx = total - fade + i
                            let endSample = input[endIdx]
                            let startSample = input[i]
                            output[endIdx] = endSample * fadeOut + startSample * fadeIn
                        }
                    }

                    // Décalage du fichier pour que la zone de fondu soit au centre
                    var temp = [Float](repeating: 0, count: total)
                    cblas_scopy(Int32(rightLen), output + midFrame, 1, &temp, 1)
                    cblas_scopy(Int32(midFrame), output, 1, temp + rightLen, 1)
                    cblas_scopy(Int32(total), temp, 1, output, 1)

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
                }

                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

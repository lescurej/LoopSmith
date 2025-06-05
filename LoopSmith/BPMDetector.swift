import Foundation
import AVFoundation
import Accelerate

enum BPMDetector {
    /// Returns the estimated beats-per-minute for the given audio file.
    /// The algorithm is lightweight and uses envelope following with
    /// autocorrelation. It works best on percussive material.
    static func detect(url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let frameCount = Int(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        guard let channel = buffer.floatChannelData?[0] else { return nil }

        // Envelope follower
        let hop = Int(sampleRate / 200) // ~5ms
        let envCount = frameCount / hop
        var envelope = [Float](repeating: 0, count: envCount)
        for i in 0..<envCount {
            let start = i * hop
            let end = min(start + hop, frameCount)
            var rms: Float = 0
            vDSP_measqv(channel + start, 1, &rms, vDSP_Length(end - start))
            envelope[i] = rms
        }
        // Differentiate and half-wave rectify
        var diff = [Float](repeating: 0, count: envCount - 1)
        for i in 1..<envCount {
            diff[i-1] = max(0, envelope[i] - envelope[i-1])
        }

        let len = diff.count
        var autocorr = [Float](repeating: 0, count: len)
        vDSP_conv(diff, 1, diff.reversed(), 1, &autocorr, 1, vDSP_Length(len), vDSP_Length(len))

        let minBPM = 60.0
        let maxBPM = 200.0
        let minLag = Int(sampleRate * 60.0 / maxBPM / Double(hop))
        let maxLag = Int(sampleRate * 60.0 / minBPM / Double(hop))

        var bestLag = 0
        var bestVal: Float = 0
        for lag in minLag..<min(maxLag, len) {
            let val = autocorr[lag]
            if val > bestVal {
                bestVal = val
                bestLag = lag
            }
        }
        if bestLag > 0 {
            let bpm = 60.0 * sampleRate / Double(bestLag * hop)
            return bpm
        }
        return nil
    }
}

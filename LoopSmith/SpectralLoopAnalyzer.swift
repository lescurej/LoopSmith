import Foundation
import Accelerate

struct SpectralLoopAnalyzer {
    static func bestOffset(channel: UnsafePointer<Float>,
                           totalFrames: Int,
                           fadeSamples: Int) -> Int {
        let searchRange = min(fadeSamples, max(0, totalFrames - fadeSamples * 2))
        if searchRange <= 0 { return 0 }

        let log2n = vDSP_Length(log2(Double(fadeSamples)))
        guard let dft = vDSP.DFT(count: fadeSamples,
                                 direction: .forward,
                                 transformType: .real,
                                 ofType: Float.self) else {
            return 0
        }

        var window = [Float](repeating: 0, count: fadeSamples)
        vDSP_hann_window(&window, vDSP_Length(fadeSamples), Int32(vDSP_HANN_NORM))

        var startSegment = [Float](repeating: 0, count: fadeSamples)
        vDSP_vmul(channel, 1, window, 1, &startSegment, 1, vDSP_Length(fadeSamples))

        var startReal = [Float](repeating: 0, count: fadeSamples/2)
        var startImag = [Float](repeating: 0, count: fadeSamples/2)
        dft.transform(startSegment, realOutput: &startReal, imaginaryOutput: &startImag)
        var startMag = [Float](repeating: 0, count: fadeSamples/2)
        vDSP.squareMagnitudes(startReal, startImag, result: &startMag)
        vDSP.sqrt(startMag, result: &startMag)

        var candidate = [Float](repeating: 0, count: fadeSamples)
        var candReal = [Float](repeating: 0, count: fadeSamples/2)
        var candImag = [Float](repeating: 0, count: fadeSamples/2)
        var candMag = [Float](repeating: 0, count: fadeSamples/2)

        var bestScore: Float = .greatestFiniteMagnitude
        var bestOffset = 0

        for off in (-searchRange)...searchRange {
            let endStart = totalFrames - fadeSamples + off
            if endStart < 0 || endStart + fadeSamples > totalFrames { continue }

            vDSP_vmul(channel + endStart, 1, window, 1, &candidate, 1, vDSP_Length(fadeSamples))
            dft.transform(candidate, realOutput: &candReal, imaginaryOutput: &candImag)
            vDSP.squareMagnitudes(candReal, candImag, result: &candMag)
            vDSP.sqrt(candMag, result: &candMag)

            var diff: Float = 0
            vDSP_distancesq(&candMag, 1, &startMag, 1, &diff, vDSP_Length(fadeSamples/2))
            if diff < bestScore {
                bestScore = diff
                bestOffset = off
            }
        }

        return bestOffset
    }
}

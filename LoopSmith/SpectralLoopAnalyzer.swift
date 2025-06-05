import Foundation
import Accelerate

struct SpectralLoopAnalyzer {
    static func bestOffset(channel: UnsafePointer<Float>,
                           totalFrames: Int,
                           fadeSamples: Int) -> Int {
        let searchRange = min(fadeSamples, max(0, totalFrames - fadeSamples * 2))
        if searchRange <= 0 { return 0 }

        // The vDSP.DFT initializer returns an optional instance.  If the
        // transform cannot be created, simply return offset 0.
        guard let dft = vDSP.DFT(count: fadeSamples,
                                 direction: .forward,
                                 transformType: .complexReal,
                                 ofType: Float.self) else {
            return 0
        }

        var window = [Float](repeating: 0, count: fadeSamples)
        vDSP_hann_window(&window, vDSP_Length(fadeSamples), Int32(vDSP_HANN_NORM))

        var startSegment = [Float](repeating: 0, count: fadeSamples)
        vDSP_vmul(channel, 1, window, 1, &startSegment, 1, vDSP_Length(fadeSamples))

        var startReal = [Float](repeating: 0, count: fadeSamples/2)
        var startImag = [Float](repeating: 0, count: fadeSamples/2)
        dft.transform(startSegment,
                      outputReal: &startReal,
                      outputImaginary: &startImag)
        var startMag = [Float](repeating: 0, count: fadeSamples/2)
        for i in 0..<(fadeSamples/2) {
            let r = startReal[i]
            let im = startImag[i]
            startMag[i] = sqrt(r * r + im * im)
        }

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
            dft.transform(candidate,
                          outputReal: &candReal,
                          outputImaginary: &candImag)
            for i in 0..<(fadeSamples/2) {
                let r = candReal[i]
                let im = candImag[i]
                candMag[i] = sqrt(r * r + im * im)
            }

            var diff: Float = 0
            for i in 0..<(fadeSamples/2) {
                let delta = candMag[i] - startMag[i]
                diff += delta * delta
            }
            if diff < bestScore {
                bestScore = diff
                bestOffset = off
            }
        }

        return bestOffset
    }
}

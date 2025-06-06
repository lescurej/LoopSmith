import Foundation
import Accelerate

struct SpectralLoopAnalyzer {
    /// Compute the optimal alignment offset between the start of the buffer and
    /// its end so that a crossfaded loop is as seamless as possible.
    /// - Parameters:
    ///   - channel: Pointer to the first sample of the audio channel to analyse.
    ///   - totalFrames: Number of frames available in `channel`.
    ///   - fadeSamples: Length of the cross‑fade region in samples.
    /// - Returns: Offset in samples that provides the best spectral match.
    static func bestOffset(channel: UnsafePointer<Float>,
                           totalFrames: Int,
                           fadeSamples: Int) -> Int {
        // Search is limited to the cross‑fade length and bounded by the
        // available frames so that we do not read out of range.
        let searchRange = min(fadeSamples, max(0, totalFrames - fadeSamples * 2))
        guard searchRange > 0 else { return 0 }

        // Window used on both the beginning and candidate end segments.
        var window = [Float](repeating: 0, count: fadeSamples)
        vDSP_hann_window(&window, vDSP_Length(fadeSamples), Int32(vDSP_HANN_NORM))

        // Start segment windowed and its precomputed norm.
        var start = [Float](repeating: 0, count: fadeSamples)
        vDSP_vmul(channel, 1, window, 1, &start, 1, vDSP_Length(fadeSamples))
        var startNorm: Float = 0
        vDSP_dotpr(start, 1, start, 1, &startNorm, vDSP_Length(fadeSamples))
        startNorm = sqrt(startNorm)

        var candidate = [Float](repeating: 0, count: fadeSamples)
        var bestOffset = 0
        var bestScore: Float = -.greatestFiniteMagnitude

        for offset in (-searchRange)...searchRange {
            let endStart = totalFrames - fadeSamples + offset
            if endStart < 0 || endStart + fadeSamples > totalFrames { continue }

            // Windowed candidate segment.
            vDSP_vmul(channel + endStart, 1, window, 1, &candidate, 1, vDSP_Length(fadeSamples))
            var candNorm: Float = 0
            vDSP_dotpr(candidate, 1, candidate, 1, &candNorm, vDSP_Length(fadeSamples))
            candNorm = sqrt(candNorm)

            var dot: Float = 0
            vDSP_dotpr(start, 1, candidate, 1, &dot, vDSP_Length(fadeSamples))

            let normProduct = startNorm * candNorm
            let similarity = normProduct > 0 ? dot / normProduct : 0

            if similarity > bestScore {
                bestScore = similarity
                bestOffset = offset
            }
        }

        return bestOffset
    }
}

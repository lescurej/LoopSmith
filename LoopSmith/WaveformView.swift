import SwiftUI

struct WaveformView: View {
    var samples: [Float]

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let width = geometry.size.width
            let step = width / CGFloat(max(samples.count, 1))
            Path { path in
                for (index, amp) in samples.enumerated() {
                    let x = CGFloat(index) * step
                    let y = CGFloat(1 - amp) * height / 2
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: height - y))
                }
            }
            .stroke(Color.accentSecondary, lineWidth: 1)
        }
    }
}

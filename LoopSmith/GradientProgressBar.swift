import SwiftUI

struct GradientProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.accentMain, .accentSecondary]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .frame(height: 8)
    }
}

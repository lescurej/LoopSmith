import SwiftUI

struct ProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: CGFloat(max(0.0, min(1.0, progress))) * geometry.size.width)
            }
            .cornerRadius(4)
        }
    }
}

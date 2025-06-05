import SwiftUI

struct ProgressBar: View {
    var progress: Double

    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(.linear)
            .tint(.accentSecondary)
            .frame(height: 8)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

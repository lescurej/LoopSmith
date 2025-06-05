import SwiftUI

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    static let accentMain = Color(hex: "#FF6F61")
    static let accentSecondary = Color(hex: "#B86BFF")
    static let backgroundPrimary = Color(hex: "#121212")
    static let backgroundSecondary = Color(hex: "#1E1E1E")
}

import Foundation

enum CrossfadeMode: String, CaseIterable, Identifiable {
    case manual
    case beatDetection
    case spectral

    var id: Self { self }

    var displayName: String {
        switch self {
        case .manual:
            return "Manual"
        case .beatDetection:
            return "Beat Detection"
        case .spectral:
            return "Spectral"
        }
    }
}

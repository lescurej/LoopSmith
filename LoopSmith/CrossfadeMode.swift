import Foundation

enum CrossfadeMode: String, CaseIterable, Identifiable {
    case manual
    case rhythmicBPM

    var id: Self { self }

    var displayName: String {
        switch self {
        case .manual:
            return "Manual"
        case .rhythmicBPM:
            return "Rhythmic (BPM)"
        }
    }
}

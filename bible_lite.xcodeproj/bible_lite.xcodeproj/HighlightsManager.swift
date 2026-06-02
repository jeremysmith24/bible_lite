import SwiftUI
import Combine

// MARK: - Highlight Color

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow, green, blue, pink, purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 1.0,  green: 0.93, blue: 0.35).opacity(0.55)
        case .green:  return Color(red: 0.45, green: 0.90, blue: 0.50).opacity(0.50)
        case .blue:   return Color(red: 0.35, green: 0.75, blue: 1.0 ).opacity(0.50)
        case .pink:   return Color(red: 1.0,  green: 0.45, blue: 0.65).opacity(0.45)
        case .purple: return Color(red: 0.70, green: 0.45, blue: 1.0 ).opacity(0.50)
        }
    }

    var solidColor: Color {
        switch self {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        case .purple: return .purple
        }
    }

    var label: String { rawValue.capitalized }

    static func from(_ string: String?) -> HighlightColor? {
        guard let string else { return nil }
        return HighlightColor(rawValue: string)
    }
}

// MARK: - Highlights Manager

/// Shared in-memory cache of all highlights so views react instantly to changes.
final class HighlightsManager: ObservableObject {

    static let shared = HighlightsManager()

    /// [verseId: HighlightColor]
    @Published private(set) var highlights: [Int: HighlightColor] = [:]

    private init() {
        reload()
    }

    func reload() {
        let raw = DatabaseManager.shared.allHighlights()
        highlights = raw.compactMapValues { HighlightColor(rawValue: $0) }
    }

    func save(verseId: Int, color: HighlightColor) {
        DatabaseManager.shared.saveHighlight(verseId: verseId, color: color.rawValue)
        highlights[verseId] = color
    }

    func remove(verseId: Int) {
        DatabaseManager.shared.removeHighlight(verseId: verseId)
        highlights.removeValue(forKey: verseId)
    }

    func color(forVerseId verseId: Int) -> HighlightColor? {
        highlights[verseId]
    }
}

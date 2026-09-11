import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMute = Self("toggleMute")
    static let nextInput = Self("nextInput")
    static let nextOutput = Self("nextOutput")
}

/// What the menu bar item shows beside the mute glyph.
///
/// Persisted directly by `@AppStorage`, so the raw values are the storage keys —
/// renaming a case silently resets the user's choice.
enum MenuBarLabelMode: String, CaseIterable, Identifiable {
    case iconOnly
    case input
    case output

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .input: return "Input device"
        case .output: return "Output device"
        }
    }
}

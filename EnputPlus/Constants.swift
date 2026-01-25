import Foundation

/// Application-wide constants and configuration values.
enum Constants {
    /// Bundle and connection identifiers.
    enum App {
        static let bundleIdentifier = "com.enputplus.inputmethod.EnputPlus"
    }

    /// Timing configuration for input handling.
    enum Timing {
        /// Debounce delay for candidate updates to avoid excessive API calls during fast typing.
        static let candidateUpdateDebounce: TimeInterval = 0.05
    }

    /// Spelling engine configuration.
    enum Spelling {
        /// Preferred language for spell checking.
        static let preferredLanguage = "en_US"
        /// Maximum number of suggestions to display.
        static let maxSuggestions = 7
    }

    /// Candidate selection key range (1-9).
    enum CandidateSelection {
        static let keyRange = 1...9
    }
}

/// Type-safe notification names.
extension Notification.Name {
    static let enputPlusInitializationFailed = Notification.Name("com.enputplus.initializationFailed")
}

/// Common NSRange patterns used throughout the app.
extension NSRange {
    /// Range indicating no replacement (used for insertions).
    static let noReplacement = NSRange(location: NSNotFound, length: 0)

    /// Empty range at the start.
    static let empty = NSRange(location: 0, length: 0)

    /// Creates a selection range at the given cursor position.
    static func cursor(at position: Int) -> NSRange {
        NSRange(location: position, length: 0)
    }
}

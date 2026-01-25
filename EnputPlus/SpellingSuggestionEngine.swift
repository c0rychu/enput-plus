import Cocoa
import os.log

// MARK: - SpellingSuggestionEngine

/// Provides spelling suggestions and word completions using macOS spell checking.
final class SpellingSuggestionEngine {

    // MARK: - Properties

    private let spellChecker = NSSpellChecker.shared
    private let language: String
    private let maxSuggestions: Int
    private let documentTag: Int

    // MARK: - Initialization

    init(
        language: String = Constants.Spelling.preferredLanguage,
        maxSuggestions: Int = Constants.Spelling.maxSuggestions
    ) {
        self.language = language
        self.maxSuggestions = maxSuggestions
        self.documentTag = NSSpellChecker.uniqueSpellDocumentTag()

        configureLanguage()
        os_log("SpellingSuggestionEngine ready", log: Log.spelling, type: .info)
    }

    // MARK: - Public API

    /// Returns spelling suggestions for the given word.
    /// - Parameter word: The word to get suggestions for.
    /// - Returns: Corrections if misspelled, or completions if correctly spelled.
    func suggestions(for word: String) -> [String] {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let wordRange = NSRange(location: 0, length: trimmed.utf16.count)

        if isMisspelled(trimmed) {
            return corrections(for: trimmed, range: wordRange)
        } else {
            return completions(for: trimmed, range: wordRange)
        }
    }

    /// Checks if a word is correctly spelled.
    func isCorrectlySpelled(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return !isMisspelled(trimmed)
    }

    /// Adds a word to the user's dictionary.
    func learn(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        spellChecker.learnWord(trimmed)
        os_log("Word learned", log: Log.spelling, type: .info)
    }

    // MARK: - Private

    private func configureLanguage() {
        guard !spellChecker.setLanguage(language) else { return }

        os_log("Language %{public}@ unavailable, trying fallback",
               log: Log.spelling, type: .info, language)

        for fallback in spellChecker.availableLanguages {
            if spellChecker.setLanguage(fallback) {
                os_log("Using fallback language: %{public}@",
                       log: Log.spelling, type: .info, fallback)
                return
            }
        }

        os_log("No spell check language available", log: Log.spelling, type: .error)
    }

    private func isMisspelled(_ word: String) -> Bool {
        let range = spellChecker.checkSpelling(of: word, startingAt: 0)
        return range.location != NSNotFound
    }

    private func corrections(for word: String, range: NSRange) -> [String] {
        os_log("Fetching corrections", log: Log.spelling, type: .debug)

        let guesses = spellChecker.guesses(
            forWordRange: range,
            in: word,
            language: language,
            inSpellDocumentWithTag: documentTag
        ) ?? []

        return Array(guesses.prefix(maxSuggestions))
    }

    private func completions(for word: String, range: NSRange) -> [String] {
        os_log("Fetching completions", log: Log.spelling, type: .debug)

        let results = spellChecker.completions(
            forPartialWordRange: range,
            in: word,
            language: language,
            inSpellDocumentWithTag: documentTag
        ) ?? []

        return Array(results.prefix(maxSuggestions))
    }
}

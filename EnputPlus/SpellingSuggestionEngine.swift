import Cocoa
import os.log

class SpellingSuggestionEngine {

    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "EnputPlus", category: "SpellingSuggestionEngine")

    private let spellChecker = NSSpellChecker.shared
    private let language = "en_US"
    private let maxSuggestions = 7

    init() {
        spellChecker.setLanguage(language)
        os_log("SpellingSuggestionEngine initialized with language: %{public}@",
               log: SpellingSuggestionEngine.log, type: .info, language)
    }

    /// Get spelling suggestions for a word
    /// Returns corrections if misspelled, or completions if the word is valid
    func getSuggestions(for word: String) -> [String] {
        guard !word.isEmpty else { return [] }

        let trimmedWord = word.trimmingCharacters(in: .whitespaces)
        guard !trimmedWord.isEmpty else { return [] }

        // Check if the word is misspelled
        let range = spellChecker.checkSpelling(of: trimmedWord, startingAt: 0)

        if range.location != NSNotFound {
            // Word is misspelled, get correction suggestions
            os_log("Word '%{public}@' is misspelled, fetching corrections",
                   log: SpellingSuggestionEngine.log, type: .debug, trimmedWord)

            let guesses = spellChecker.guesses(
                forWordRange: NSRange(location: 0, length: trimmedWord.count),
                in: trimmedWord,
                language: language,
                inSpellDocumentWithTag: 0
            ) ?? []

            return Array(guesses.prefix(maxSuggestions))
        }

        // Word is correctly spelled, provide completions
        os_log("Word '%{public}@' is correct, fetching completions",
               log: SpellingSuggestionEngine.log, type: .debug, trimmedWord)

        let completions = spellChecker.completions(
            forPartialWordRange: NSRange(location: 0, length: trimmedWord.count),
            in: trimmedWord,
            language: language,
            inSpellDocumentWithTag: 0
        ) ?? []

        return Array(completions.prefix(maxSuggestions))
    }

    /// Check if a word is correctly spelled
    func isCorrectlySpelled(_ word: String) -> Bool {
        guard !word.isEmpty else { return true }

        let trimmedWord = word.trimmingCharacters(in: .whitespaces)
        guard !trimmedWord.isEmpty else { return true }

        let range = spellChecker.checkSpelling(of: trimmedWord, startingAt: 0)
        return range.location == NSNotFound
    }

    /// Learn a new word (add to user dictionary)
    func learnWord(_ word: String) {
        guard !word.isEmpty else { return }
        spellChecker.learnWord(word)
        os_log("Learned word: %{public}@", log: SpellingSuggestionEngine.log, type: .info, word)
    }
}

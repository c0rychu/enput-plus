import Cocoa
import InputMethodKit
import Carbon
import os.log

// MARK: - EnputPlusInputController

/// Main input controller handling keyboard events and composition.
@objc(EnputPlusInputController)
final class EnputPlusInputController: IMKInputController {

    // MARK: - Composition State

    private struct CompositionState {
        var buffer = ""
        var cursorPosition = 0  // UTF-16 offset for compatibility with NSRange
        var suggestions: [String] = []
        var selectedIndex = 0
        var isNavigatingSuggestions = false  // True when user used arrow keys to select

        var isEmpty: Bool { buffer.isEmpty }
        var hasSuggestions: Bool { !suggestions.isEmpty }
        var cursorAtEnd: Bool { cursorPosition >= buffer.utf16.count }

        /// Range of the word at cursor position (start index, end index in buffer).
        var wordRangeAtCursor: Range<String.Index> {
            guard !buffer.isEmpty else { return buffer.startIndex..<buffer.startIndex }

            // Convert UTF-16 cursor position to String.Index
            let cursorIndex = buffer.utf16.index(buffer.utf16.startIndex, offsetBy: min(cursorPosition, buffer.utf16.count))
            let cursorStringIndex = String.Index(cursorIndex, within: buffer) ?? buffer.endIndex

            // Find word boundaries
            var wordStart = cursorStringIndex
            var wordEnd = cursorStringIndex

            // Search backward for word start (stop at any word separator)
            while wordStart > buffer.startIndex {
                let prevIndex = buffer.index(before: wordStart)
                if Constants.WordSeparators.isSeparator(buffer[prevIndex]) {
                    break
                }
                wordStart = prevIndex
            }

            // Search forward for word end (stop at any word separator)
            while wordEnd < buffer.endIndex {
                if Constants.WordSeparators.isSeparator(buffer[wordEnd]) {
                    break
                }
                wordEnd = buffer.index(after: wordEnd)
            }

            return wordStart..<wordEnd
        }

        /// The word at cursor position.
        var currentWord: String {
            String(buffer[wordRangeAtCursor])
        }

        /// Whether we have a word to get suggestions for.
        var hasCurrentWord: Bool { !currentWord.isEmpty }

        mutating func reset() {
            buffer = ""
            cursorPosition = 0
            suggestions = []
            selectedIndex = 0
            isNavigatingSuggestions = false
        }

        /// Replaces the word at cursor with the given text.
        mutating func replaceCurrentWord(with text: String) {
            let range = wordRangeAtCursor
            let beforeWord = String(buffer[..<range.lowerBound])
            let afterWord = String(buffer[range.upperBound...])
            buffer = beforeWord + text + afterWord
            // Move cursor to end of inserted word
            cursorPosition = (beforeWord + text).utf16.count
        }

        /// Inserts text at cursor position.
        mutating func insertAtCursor(_ text: String) {
            let cursorIndex = buffer.utf16.index(buffer.utf16.startIndex, offsetBy: min(cursorPosition, buffer.utf16.count))
            let stringIndex = String.Index(cursorIndex, within: buffer) ?? buffer.endIndex
            buffer.insert(contentsOf: text, at: stringIndex)
            cursorPosition += text.utf16.count
        }

        /// Deletes character before cursor (backspace).
        mutating func deleteBeforeCursor() -> Bool {
            guard cursorPosition > 0 else { return false }
            let cursorIndex = buffer.utf16.index(buffer.utf16.startIndex, offsetBy: cursorPosition)
            guard let stringIndex = String.Index(cursorIndex, within: buffer),
                  stringIndex > buffer.startIndex else { return false }
            let deleteIndex = buffer.index(before: stringIndex)
            let charToDelete = buffer[deleteIndex]
            buffer.remove(at: deleteIndex)
            cursorPosition -= String(charToDelete).utf16.count
            return true
        }

        /// Moves cursor left by one character.
        mutating func moveCursorLeft() -> Bool {
            guard cursorPosition > 0 else { return false }
            let cursorIndex = buffer.utf16.index(buffer.utf16.startIndex, offsetBy: cursorPosition)
            guard let stringIndex = String.Index(cursorIndex, within: buffer),
                  stringIndex > buffer.startIndex else { return false }
            let prevIndex = buffer.index(before: stringIndex)
            let char = buffer[prevIndex]
            cursorPosition -= String(char).utf16.count
            return true
        }

        /// Moves cursor right by one character.
        mutating func moveCursorRight() -> Bool {
            let bufferLength = buffer.utf16.count
            guard cursorPosition < bufferLength else { return false }
            let cursorIndex = buffer.utf16.index(buffer.utf16.startIndex, offsetBy: cursorPosition)
            guard let stringIndex = String.Index(cursorIndex, within: buffer),
                  stringIndex < buffer.endIndex else { return false }
            let char = buffer[stringIndex]
            cursorPosition += String(char).utf16.count
            return true
        }
    }

    // MARK: - Properties

    private var state = CompositionState()
    private let spellingEngine = SpellingSuggestionEngine()
    private var pendingCandidateUpdate: DispatchWorkItem?

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        os_log("InputController initialized", log: Log.inputController, type: .info)
    }

    // MARK: - IMKInputController Overrides

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        os_log("Server activated", log: Log.inputController, type: .info)
        state.reset()
    }

    override func deactivateServer(_ sender: Any!) {
        pendingCandidateUpdate?.cancel()
        pendingCandidateUpdate = nil
        commitComposition(sender)
        super.deactivateServer(sender)
        os_log("Server deactivated", log: Log.inputController, type: .info)
    }

    // MARK: - Event Handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event,
              event.type == .keyDown,
              let client = sender as? (any IMKTextInput) else {
            return false
        }

        // Allow system shortcuts
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) || modifiers.contains(.control) {
            return false
        }

        os_log("Key event: code=%d", log: Log.inputController, type: .debug, event.keyCode)

        if let result = handleSpecialKey(Int(event.keyCode), client: client, sender: sender) {
            return result
        }

        return handleCharacterInput(event.characters, client: client)
    }

    // MARK: - Candidates

    override func candidates(_ sender: Any!) -> [Any]! {
        os_log("Candidates requested: %d items", log: Log.inputController, type: .debug, state.suggestions.count)
        return state.suggestions
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let word = candidateString?.string,
              let client = self.client() else { return }

        os_log("Candidate selected via click", log: Log.inputController, type: .debug)
        selectSuggestion(word, client: client)
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let word = candidateString?.string,
              let index = state.suggestions.firstIndex(of: word) else { return }
        state.selectedIndex = index
    }

    // MARK: - Composition

    override func commitComposition(_ sender: Any!) {
        guard !state.isEmpty else { return }

        os_log("Committing composition", log: Log.inputController, type: .debug)

        if let client = sender as? (any IMKTextInput) {
            commitBuffer(to: client)
        } else if let client = self.client() {
            commitBuffer(to: client)
        }
    }

    // MARK: - Special Key Handling

    private func handleSpecialKey(_ keyCode: Int, client: any IMKTextInput, sender: Any!) -> Bool? {
        switch keyCode {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            return handleEnter(client: client)

        case kVK_Delete:
            return handleBackspace(client: client)

        case kVK_ForwardDelete:
            return handleForwardDelete(client: client)

        case kVK_Escape:
            return handleEscape(client: client)

        case kVK_Space:
            return handleSpace(client: client)

        case kVK_Tab:
            return handleTab(client: client)

        case kVK_UpArrow:
            return handleArrowUp(sender: sender)

        case kVK_DownArrow:
            return handleArrowDown(sender: sender)

        case kVK_LeftArrow:
            return handleArrowLeft(client: client)

        case kVK_RightArrow:
            return handleArrowRight(client: client)

        default:
            return nil
        }
    }

    /// Enter: If navigating suggestions, confirm selection. Otherwise, commit buffer.
    private func handleEnter(client: any IMKTextInput) -> Bool {
        guard !state.isEmpty else { return false }

        // If user was navigating suggestions with arrows, first Enter confirms selection
        if state.isNavigatingSuggestions && state.hasSuggestions {
            selectSuggestion(state.suggestions[state.selectedIndex], client: client)
            return true
        }

        // Second Enter (or Enter without navigation) commits the buffer
        commitBuffer(to: client)
        return true
    }

    /// Escape: Commit raw buffer as-is (no corrections)
    private func handleEscape(client: any IMKTextInput) -> Bool {
        guard !state.isEmpty else { return false }

        // Commit exactly what user typed, ignore suggestions
        commitBuffer(to: client)
        return true
    }

    /// Space: Add literal space at cursor, continue composition
    private func handleSpace(client: any IMKTextInput) -> Bool {
        state.insertAtCursor(" ")
        state.suggestions = []
        state.selectedIndex = 0
        state.isNavigatingSuggestions = false

        os_log("Space added, buffer length=%d", log: Log.inputController, type: .debug, state.buffer.count)

        updateMarkedText(client: client)
        hideCandidates()
        return true
    }

    /// Tab: Select first suggestion
    private func handleTab(client: any IMKTextInput) -> Bool {
        guard state.hasSuggestions else { return false }

        selectSuggestion(state.suggestions[0], client: client)
        return true
    }

    /// Backspace: Remove character before cursor
    private func handleBackspace(client: any IMKTextInput) -> Bool {
        guard state.deleteBeforeCursor() else { return false }

        if state.isEmpty {
            hideCandidates()
            clearMarkedText(client: client)
            state.reset()
        } else {
            updateMarkedText(client: client)
            scheduleCandidateUpdate()
        }
        return true
    }

    /// Forward Delete: Delete character after cursor
    private func handleForwardDelete(client: any IMKTextInput) -> Bool {
        guard !state.isEmpty, !state.cursorAtEnd else { return false }

        // Move cursor right then delete before cursor
        if state.moveCursorRight() {
            return handleBackspace(client: client)
        }
        return false
    }

    private func handleArrowUp(sender: Any!) -> Bool {
        // Always consume up/down when we have a buffer to prevent system from interfering
        guard !state.isEmpty else { return false }
        guard state.hasSuggestions else { return true }  // Consume but do nothing

        state.selectedIndex = max(0, state.selectedIndex - 1)
        state.isNavigatingSuggestions = true
        candidatesWindow()?.moveUp(sender)
        os_log("Selection moved up: %d", log: Log.inputController, type: .debug, state.selectedIndex)
        return true
    }

    private func handleArrowDown(sender: Any!) -> Bool {
        // Always consume up/down when we have a buffer to prevent system from interfering
        guard !state.isEmpty else { return false }
        guard state.hasSuggestions else { return true }  // Consume but do nothing

        state.selectedIndex = min(state.suggestions.count - 1, state.selectedIndex + 1)
        state.isNavigatingSuggestions = true
        candidatesWindow()?.moveDown(sender)
        os_log("Selection moved down: %d", log: Log.inputController, type: .debug, state.selectedIndex)
        return true
    }

    /// Left arrow: Move cursor left, update suggestions for word at cursor
    private func handleArrowLeft(client: any IMKTextInput) -> Bool {
        guard !state.isEmpty else { return false }

        let oldWord = state.currentWord
        guard state.moveCursorLeft() else { return false }

        state.isNavigatingSuggestions = false
        updateMarkedText(client: client)

        // If cursor moved to a different word, update suggestions
        if state.currentWord != oldWord {
            scheduleCandidateUpdate()
        }

        os_log("Cursor left: pos=%d, word=%{public}@",
               log: Log.inputController, type: .debug, state.cursorPosition, state.currentWord)
        return true
    }

    /// Right arrow: Move cursor right, update suggestions for word at cursor
    private func handleArrowRight(client: any IMKTextInput) -> Bool {
        guard !state.isEmpty else { return false }

        let oldWord = state.currentWord
        guard state.moveCursorRight() else { return false }

        state.isNavigatingSuggestions = false
        updateMarkedText(client: client)

        // If cursor moved to a different word, update suggestions
        if state.currentWord != oldWord {
            scheduleCandidateUpdate()
        }

        os_log("Cursor right: pos=%d, word=%{public}@",
               log: Log.inputController, type: .debug, state.cursorPosition, state.currentWord)
        return true
    }

    // MARK: - Character Input

    private func handleCharacterInput(_ characters: String?, client: any IMKTextInput) -> Bool {
        guard let characters = characters, !characters.isEmpty else { return false }

        // Number keys 1-9 select candidates when suggestions are showing
        if state.hasSuggestions,
           characters.count == 1,
           let number = Int(characters),
           Constants.CandidateSelection.keyRange.contains(number) {
            let index = number - 1
            if index < state.suggestions.count {
                selectSuggestion(state.suggestions[index], client: client)
                return true
            }
        }

        // Insert at cursor position
        state.insertAtCursor(characters)
        state.isNavigatingSuggestions = false  // New input resets navigation state
        os_log("Buffer updated: length=%d, cursor=%d, currentWord=%{public}@",
               log: Log.inputController, type: .debug,
               state.buffer.count, state.cursorPosition, state.currentWord)

        updateMarkedText(client: client)
        scheduleCandidateUpdate()
        return true
    }

    // MARK: - Suggestion Selection

    /// Select a suggestion: replace word at cursor, add space only if at end
    private func selectSuggestion(_ word: String, client: any IMKTextInput) {
        // Check if we're editing a word at the end (no text after current word)
        let isAtEnd = state.wordRangeAtCursor.upperBound >= state.buffer.endIndex

        state.replaceCurrentWord(with: word)

        // Only add space if at end of buffer (adding new word, not editing middle)
        if isAtEnd {
            state.insertAtCursor(" ")
        }

        state.suggestions = []
        state.selectedIndex = 0
        state.isNavigatingSuggestions = false

        os_log("Selected suggestion: %{public}@, buffer=%{public}@, atEnd=%d",
               log: Log.inputController, type: .debug, word, state.buffer, isAtEnd ? 1 : 0)

        updateMarkedText(client: client)
        hideCandidates()
    }

    // MARK: - Text Operations

    private func updateMarkedText(client: any IMKTextInput) {
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.textColor
        ]
        let attributed = NSAttributedString(string: state.buffer, attributes: attributes)

        client.setMarkedText(
            attributed,
            selectionRange: .cursor(at: state.cursorPosition),
            replacementRange: .noReplacement
        )
    }

    private func clearMarkedText(client: any IMKTextInput) {
        client.setMarkedText("", selectionRange: .empty, replacementRange: .noReplacement)
    }

    private func commitBuffer(to client: any IMKTextInput) {
        client.insertText(state.buffer, replacementRange: .noReplacement)
        state.reset()
        hideCandidates()
    }

    // MARK: - Candidates Management

    private func scheduleCandidateUpdate() {
        pendingCandidateUpdate?.cancel()

        // Only fetch suggestions if we have a current word
        guard state.hasCurrentWord else {
            state.suggestions = []
            state.selectedIndex = 0
            hideCandidates()
            return
        }

        let currentWord = state.currentWord
        let workItem = DispatchWorkItem { [weak self] in
            self?.performCandidateUpdate(for: currentWord)
        }

        pendingCandidateUpdate = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.Timing.candidateUpdateDebounce,
            execute: workItem
        )
    }

    private func performCandidateUpdate(for word: String) {
        // Skip if current word changed since scheduling
        guard state.currentWord == word else {
            os_log("Skipping stale update", log: Log.inputController, type: .debug)
            return
        }

        state.suggestions = spellingEngine.suggestions(for: word)
        state.selectedIndex = 0
        state.isNavigatingSuggestions = false  // New suggestions reset navigation

        os_log("Updated suggestions for '%{public}@': %d",
               log: Log.inputController, type: .debug, word, state.suggestions.count)

        if state.hasSuggestions {
            showCandidates()
        } else {
            hideCandidates()
        }
    }

    private func showCandidates() {
        guard let window = candidatesWindow() else {
            os_log("Candidates window unavailable", log: Log.inputController, type: .error)
            return
        }
        window.update()
        window.show()
    }

    private func hideCandidates() {
        candidatesWindow()?.hide()
    }

    private func candidatesWindow() -> IMKCandidates? {
        (NSApplication.shared.delegate as? AppDelegate)?.candidatesWindow
    }
}

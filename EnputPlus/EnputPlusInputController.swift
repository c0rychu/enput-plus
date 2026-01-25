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
        var suggestions: [String] = []
        var selectedIndex = 0
        var isNavigatingSuggestions = false  // True when user used arrow keys to select

        var isEmpty: Bool { buffer.isEmpty }
        var hasSuggestions: Bool { !suggestions.isEmpty }

        /// The current word being typed (text after the last space).
        var currentWord: String {
            if let lastSpaceIndex = buffer.lastIndex(of: " ") {
                return String(buffer[buffer.index(after: lastSpaceIndex)...])
            }
            return buffer
        }

        /// The prefix before the current word (including trailing space).
        var prefixBeforeCurrentWord: String {
            if let lastSpaceIndex = buffer.lastIndex(of: " ") {
                return String(buffer[...lastSpaceIndex])
            }
            return ""
        }

        /// Whether we have a word to get suggestions for.
        var hasCurrentWord: Bool { !currentWord.isEmpty }

        mutating func reset() {
            buffer = ""
            suggestions = []
            selectedIndex = 0
            isNavigatingSuggestions = false
        }

        /// Replaces the current word with the given text.
        mutating func replaceCurrentWord(with text: String) {
            buffer = prefixBeforeCurrentWord + text
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

    /// Space: Add literal space to buffer, continue composition
    private func handleSpace(client: any IMKTextInput) -> Bool {
        // Add space to buffer
        state.buffer += " "
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

    /// Backspace: Remove last character
    private func handleBackspace(client: any IMKTextInput) -> Bool {
        guard !state.isEmpty else { return false }

        state.buffer.removeLast()

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

    /// Forward Delete: Same as backspace for composition
    private func handleForwardDelete(client: any IMKTextInput) -> Bool {
        return handleBackspace(client: client)
    }

    private func handleArrowUp(sender: Any!) -> Bool {
        guard state.hasSuggestions else { return false }

        state.selectedIndex = max(0, state.selectedIndex - 1)
        state.isNavigatingSuggestions = true
        candidatesWindow()?.moveUp(sender)
        os_log("Selection moved up: %d", log: Log.inputController, type: .debug, state.selectedIndex)
        return true
    }

    private func handleArrowDown(sender: Any!) -> Bool {
        guard state.hasSuggestions else { return false }

        state.selectedIndex = min(state.suggestions.count - 1, state.selectedIndex + 1)
        state.isNavigatingSuggestions = true
        candidatesWindow()?.moveDown(sender)
        os_log("Selection moved down: %d", log: Log.inputController, type: .debug, state.selectedIndex)
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

        // Append to composition buffer
        state.buffer += characters
        state.isNavigatingSuggestions = false  // New input resets navigation state
        os_log("Buffer updated: length=%d, currentWord=%{public}@",
               log: Log.inputController, type: .debug,
               state.buffer.count, state.currentWord)

        updateMarkedText(client: client)
        scheduleCandidateUpdate()
        return true
    }

    // MARK: - Suggestion Selection

    /// Select a suggestion: replace current word, add space, continue composition
    private func selectSuggestion(_ word: String, client: any IMKTextInput) {
        state.replaceCurrentWord(with: word)
        state.buffer += " "  // Auto-add space for next word
        state.suggestions = []
        state.selectedIndex = 0
        state.isNavigatingSuggestions = false

        os_log("Selected suggestion: %{public}@, buffer=%{public}@",
               log: Log.inputController, type: .debug, word, state.buffer)

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
        let cursorPosition = state.buffer.utf16.count

        client.setMarkedText(
            attributed,
            selectionRange: .cursor(at: cursorPosition),
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

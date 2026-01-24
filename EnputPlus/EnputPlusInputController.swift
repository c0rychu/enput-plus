import Cocoa
import InputMethodKit
import Carbon
import os.log

@objc(EnputPlusInputController)
class EnputPlusInputController: IMKInputController {

    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "EnputPlus", category: "InputController")

    private var compositionBuffer = ""
    private let spellingEngine = SpellingSuggestionEngine()
    private var currentSuggestions: [String] = []

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        os_log("EnputPlusInputController initialized", log: EnputPlusInputController.log, type: .debug)
    }

    // MARK: - IMKInputController Overrides

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        os_log("Input server activated", log: EnputPlusInputController.log, type: .debug)
        resetComposition()
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
        os_log("Input server deactivated", log: EnputPlusInputController.log, type: .debug)
    }

    // MARK: - Text Input

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        os_log("Input text: '%{public}@'", log: EnputPlusInputController.log, type: .debug, string ?? "")

        guard let string = string, !string.isEmpty else { return false }
        guard let client = sender as? IMKTextInput else { return false }

        // Handle space - commit current composition and add space
        if string == " " {
            if !compositionBuffer.isEmpty {
                commitComposition(sender)
            }
            // Let the system handle the space
            return false
        }

        // Handle alphanumeric characters
        if isAlphanumeric(string) {
            compositionBuffer += string
            updateMarkedText(client: client)
            updateCandidates()
            return true
        }

        // For punctuation, commit first then let system handle
        if !compositionBuffer.isEmpty {
            commitComposition(sender)
        }
        return false
    }

    override func didCommand(by selector: Selector!, client sender: Any!) -> Bool {
        os_log("Did command: %{public}@", log: EnputPlusInputController.log, type: .debug, NSStringFromSelector(selector))

        guard let client = sender as? IMKTextInput else { return false }

        switch selector {
        case #selector(insertNewline(_:)):
            // Enter/Return - commit composition
            if !compositionBuffer.isEmpty {
                commitComposition(sender)
                return true
            }
            return false

        case #selector(deleteBackward(_:)):
            // Backspace - delete from composition buffer
            if !compositionBuffer.isEmpty {
                compositionBuffer.removeLast()
                if compositionBuffer.isEmpty {
                    hideCandidates()
                    client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                } else {
                    updateMarkedText(client: client)
                    updateCandidates()
                }
                return true
            }
            return false

        case #selector(cancelOperation(_:)):
            // Escape - cancel composition
            if !compositionBuffer.isEmpty {
                resetComposition()
                client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                hideCandidates()
                return true
            }
            return false

        case #selector(moveUp(_:)):
            // Arrow up - navigate candidates
            if !currentSuggestions.isEmpty {
                candidatesWindow()?.moveUp(sender)
                return true
            }
            return false

        case #selector(moveDown(_:)):
            // Arrow down - navigate candidates
            if !currentSuggestions.isEmpty {
                candidatesWindow()?.moveDown(sender)
                return true
            }
            return false

        case #selector(insertTab(_:)):
            // Tab - select first candidate
            if !currentSuggestions.isEmpty {
                selectCandidate(at: 0, client: client)
                return true
            }
            return false

        default:
            return false
        }
    }

    // MARK: - Candidates

    override func candidates(_ sender: Any!) -> [Any]! {
        os_log("Candidates requested, returning %d items", log: EnputPlusInputController.log, type: .debug, currentSuggestions.count)
        return currentSuggestions
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        os_log("Candidate selected: %{public}@", log: EnputPlusInputController.log, type: .debug, candidateString?.string ?? "")

        guard let selectedWord = candidateString?.string else { return }
        guard let client = self.client() as? IMKTextInput else { return }

        // Insert the selected word
        client.insertText(selectedWord, replacementRange: NSRange(location: NSNotFound, length: 0))

        // Reset state
        resetComposition()
        hideCandidates()
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        os_log("Candidate selection changed: %{public}@", log: EnputPlusInputController.log, type: .debug, candidateString?.string ?? "")
    }

    // MARK: - Composition

    override func commitComposition(_ sender: Any!) {
        os_log("Committing composition: '%{public}@'", log: EnputPlusInputController.log, type: .debug, compositionBuffer)

        guard !compositionBuffer.isEmpty else { return }
        guard let client = sender as? IMKTextInput ?? self.client() as? IMKTextInput else { return }

        client.insertText(compositionBuffer, replacementRange: NSRange(location: NSNotFound, length: 0))
        resetComposition()
        hideCandidates()
    }

    // MARK: - Private Helpers

    private func resetComposition() {
        compositionBuffer = ""
        currentSuggestions = []
    }

    private func updateMarkedText(client: IMKTextInput) {
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.textColor
        ]
        let attributedString = NSAttributedString(string: compositionBuffer, attributes: attributes)
        client.setMarkedText(attributedString, selectionRange: NSRange(location: compositionBuffer.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func updateCandidates() {
        currentSuggestions = spellingEngine.getSuggestions(for: compositionBuffer)

        if currentSuggestions.isEmpty {
            hideCandidates()
        } else {
            showCandidates()
        }
    }

    private func showCandidates() {
        guard let candidates = candidatesWindow() else { return }
        candidates.update()
        candidates.show()
    }

    private func hideCandidates() {
        candidatesWindow()?.hide()
    }

    private func candidatesWindow() -> IMKCandidates? {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return nil }
        return appDelegate.candidatesWindow
    }

    private func selectCandidate(at index: Int, client: IMKTextInput) {
        guard index < currentSuggestions.count else { return }
        let selectedWord = currentSuggestions[index]

        client.insertText(selectedWord, replacementRange: NSRange(location: NSNotFound, length: 0))
        resetComposition()
        hideCandidates()
    }

    private func isAlphanumeric(_ string: String) -> Bool {
        let alphanumericSet = CharacterSet.alphanumerics
        return string.unicodeScalars.allSatisfy { alphanumericSet.contains($0) }
    }

    // Handle number key selection (1-9)
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return false }

        // Handle key down events for number selection
        if event.type == .keyDown {
            // Check for number keys 1-9 when we have suggestions
            if !currentSuggestions.isEmpty {
                let keyCode = event.keyCode
                // Number keys 1-9 (keyCode 18-26 on US keyboard, but we check characters instead)
                if let characters = event.characters,
                   let firstChar = characters.first,
                   let number = Int(String(firstChar)),
                   number >= 1 && number <= 9 {
                    let index = number - 1
                    if index < currentSuggestions.count {
                        guard let client = sender as? IMKTextInput else { return false }
                        selectCandidate(at: index, client: client)
                        return true
                    }
                }
            }
        }

        // Call super for default handling
        return false
    }
}

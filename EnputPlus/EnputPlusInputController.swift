import Cocoa
import InputMethodKit
import Carbon

@objc(EnputPlusInputController)
class EnputPlusInputController: IMKInputController {

    private var compositionBuffer = ""
    private let spellingEngine = SpellingSuggestionEngine()
    private var currentSuggestions: [String] = []
    private var selectedCandidateIndex: Int = 0

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        NSLog("EnputPlus: InputController initialized")
    }

    // MARK: - IMKInputController Overrides

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        NSLog("EnputPlus: Server activated")
        resetComposition()
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        super.deactivateServer(sender)
        NSLog("EnputPlus: Server deactivated")
    }

    // MARK: - Event Handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return false }
        guard let client = sender as? (any IMKTextInput) else { return false }

        NSLog("EnputPlus: handle event - type=\(event.type.rawValue), keyCode=\(event.keyCode), chars='\(event.characters ?? "")'")

        // Only handle key down events
        guard event.type == .keyDown else { return false }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommandOrControl = modifiers.contains(.command) || modifiers.contains(.control)

        // Don't handle if Command or Control is pressed (allow shortcuts)
        if hasCommandOrControl {
            return false
        }

        let keyCode = event.keyCode

        // Handle special keys
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if !compositionBuffer.isEmpty {
                // If candidates are showing, select the highlighted one
                if !currentSuggestions.isEmpty && selectedCandidateIndex < currentSuggestions.count {
                    selectCandidate(at: selectedCandidateIndex, client: client)
                } else {
                    commitCompositionWithClient(client)
                }
                return true
            }
            return false

        case kVK_Delete:
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

        case kVK_Escape:
            if !compositionBuffer.isEmpty {
                resetComposition()
                client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
                hideCandidates()
                return true
            }
            return false

        case kVK_Space:
            if !compositionBuffer.isEmpty {
                commitCompositionWithClient(client)
            }
            return false

        case kVK_Tab:
            if !currentSuggestions.isEmpty {
                selectCandidate(at: 0, client: client)
                return true
            }
            return false

        case kVK_UpArrow:
            if !currentSuggestions.isEmpty {
                selectedCandidateIndex = max(0, selectedCandidateIndex - 1)
                candidatesWindow()?.moveUp(sender)
                NSLog("EnputPlus: Arrow up, selected index = \(selectedCandidateIndex)")
                return true
            }
            return false

        case kVK_DownArrow:
            if !currentSuggestions.isEmpty {
                selectedCandidateIndex = min(currentSuggestions.count - 1, selectedCandidateIndex + 1)
                candidatesWindow()?.moveDown(sender)
                NSLog("EnputPlus: Arrow down, selected index = \(selectedCandidateIndex)")
                return true
            }
            return false

        default:
            break
        }

        // Handle character input
        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }

        let char = characters.first!

        // Handle number keys 1-9 for candidate selection
        if !currentSuggestions.isEmpty {
            if let number = Int(String(char)), number >= 1 && number <= 9 {
                let index = number - 1
                if index < currentSuggestions.count {
                    selectCandidate(at: index, client: client)
                    return true
                }
            }
        }

        // Handle alphanumeric characters
        if char.isLetter || char.isNumber {
            compositionBuffer += String(char)
            NSLog("EnputPlus: Buffer = '\(compositionBuffer)'")
            updateMarkedText(client: client)
            updateCandidates()
            return true
        }

        // For punctuation, commit first then let system handle
        if !compositionBuffer.isEmpty {
            commitCompositionWithClient(client)
        }
        return false
    }

    // MARK: - Candidates

    override func candidates(_ sender: Any!) -> [Any]! {
        NSLog("EnputPlus: candidates() called, returning \(currentSuggestions.count) items")
        return currentSuggestions
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        NSLog("EnputPlus: candidateSelected: \(candidateString?.string ?? "nil")")

        guard let selectedWord = candidateString?.string else { return }
        guard let client = self.client() else { return }

        client.insertText(selectedWord, replacementRange: NSRange(location: NSNotFound, length: 0))
        resetComposition()
        hideCandidates()
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        NSLog("EnputPlus: candidateSelectionChanged: \(candidateString?.string ?? "nil")")
    }

    // MARK: - Composition

    override func commitComposition(_ sender: Any!) {
        NSLog("EnputPlus: commitComposition called, buffer='\(compositionBuffer)'")
        guard !compositionBuffer.isEmpty else { return }

        if let client = sender as? (any IMKTextInput) {
            commitCompositionWithClient(client)
        } else if let client = self.client() {
            commitCompositionWithClient(client)
        }
    }

    private func commitCompositionWithClient(_ client: any IMKTextInput) {
        guard !compositionBuffer.isEmpty else { return }

        client.insertText(compositionBuffer, replacementRange: NSRange(location: NSNotFound, length: 0))
        resetComposition()
        hideCandidates()
    }

    // MARK: - Private Helpers

    private func resetComposition() {
        compositionBuffer = ""
        currentSuggestions = []
        selectedCandidateIndex = 0
    }

    private func updateMarkedText(client: any IMKTextInput) {
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.textColor
        ]
        let attributedString = NSAttributedString(string: compositionBuffer, attributes: attributes)
        client.setMarkedText(attributedString, selectionRange: NSRange(location: compositionBuffer.count, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    private func updateCandidates() {
        currentSuggestions = spellingEngine.getSuggestions(for: compositionBuffer)
        selectedCandidateIndex = 0  // Reset selection when candidates change
        NSLog("EnputPlus: Got \(currentSuggestions.count) suggestions for '\(compositionBuffer)'")

        if currentSuggestions.isEmpty {
            hideCandidates()
        } else {
            showCandidates()
        }
    }

    private func showCandidates() {
        guard let candidates = candidatesWindow() else {
            NSLog("EnputPlus: No candidates window available!")
            return
        }
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

    private func selectCandidate(at index: Int, client: any IMKTextInput) {
        guard index < currentSuggestions.count else { return }
        let selectedWord = currentSuggestions[index]

        client.insertText(selectedWord, replacementRange: NSRange(location: NSNotFound, length: 0))
        resetComposition()
        hideCandidates()
    }
}

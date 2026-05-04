import AppKit

/// Records and plays back sequences of editing actions.
class MacroEngine {

    static let shared = MacroEngine()

    private(set) var isRecording = false
    private(set) var recordedActions: [MacroAction] = []
    private(set) var savedMacros: [SavedMacro] = []
    private var currentRecording: [MacroAction] = []

    enum MacroAction {
        case insertText(String)
        case deleteRange(Int) // number of characters
        case moveCursor(Int) // delta
        case newline
    }

    struct SavedMacro {
        let name: String
        var actions: [MacroAction]
    }

    // MARK: - Recording

    func startRecording() {
        isRecording = true
        currentRecording = []
    }

    func stopRecording() {
        isRecording = false
        recordedActions = currentRecording
    }

    func recordAction(_ action: MacroAction) {
        guard isRecording else { return }
        currentRecording.append(action)
    }

    // MARK: - Playback

    func playback(on textView: NSTextView) {
        playActions(recordedActions, on: textView)
    }

    func playbackMultiple(times: Int, on textView: NSTextView) {
        for _ in 0..<times {
            playActions(recordedActions, on: textView)
        }
    }

    func playbackToEndOfFile(on textView: NSTextView) {
        let maxIterations = 10000
        var iteration = 0
        while iteration < maxIterations {
            let posBefore = textView.selectedRange().location
            playActions(recordedActions, on: textView)
            let posAfter = textView.selectedRange().location
            if posAfter >= (textView.string as NSString).length || posAfter == posBefore {
                break
            }
            iteration += 1
        }
    }

    // MARK: - Save/Load

    func saveCurrentMacro(name: String) {
        guard !recordedActions.isEmpty else { return }
        savedMacros.append(SavedMacro(name: name, actions: recordedActions))
    }

    // MARK: - Private

    private func playActions(_ actions: [MacroAction], on textView: NSTextView) {
        for action in actions {
            switch action {
            case .insertText(let text):
                textView.insertText(text, replacementRange: textView.selectedRange())
            case .deleteRange(let count):
                let range = textView.selectedRange()
                if range.location >= count {
                    textView.insertText("", replacementRange: NSRange(location: range.location - count, length: count))
                }
            case .moveCursor(let delta):
                let range = textView.selectedRange()
                let newPos = max(0, min(range.location + delta, (textView.string as NSString).length))
                textView.setSelectedRange(NSRange(location: newPos, length: 0))
            case .newline:
                textView.insertText("\n", replacementRange: textView.selectedRange())
            }
        }
    }
}

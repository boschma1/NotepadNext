import AppKit

/// Provides word-based auto-completion by scanning the current document.
class WordCompleter {

    private weak var textView: NSTextView?
    private var completionWindow: NSWindow?

    init(textView: NSTextView) {
        self.textView = textView
    }

    /// Trigger word completion at the current caret position.
    func complete() {
        guard let tv = textView else { return }

        let cursorPos = tv.selectedRange().location
        let text = tv.string as NSString

        // Find current word prefix
        var start = cursorPos
        while start > 0 {
            let c = text.character(at: start - 1)
            let scalar = UnicodeScalar(c)!
            if CharacterSet.alphanumerics.contains(scalar) || c == UInt16(UInt8(ascii: "_")) {
                start -= 1
            } else {
                break
            }
        }

        guard start < cursorPos else { return }

        let prefix = text.substring(with: NSRange(location: start, length: cursorPos - start))
        guard prefix.count >= 2 else { return }

        // Collect all words in the document
        let words = collectWords(from: tv.string)
        let matches = words.filter { $0.hasPrefix(prefix) && $0 != prefix }
            .sorted()

        guard !matches.isEmpty else {
            NSSound.beep()
            return
        }

        if matches.count == 1 {
            // Single match — insert directly
            let completion = String(matches[0].dropFirst(prefix.count))
            tv.insertText(completion, replacementRange: NSRange(location: cursorPos, length: 0))
        } else {
            // Multiple matches — use NSTextView's built-in completion
            tv.complete(nil)
        }
    }

    private func collectWords(from text: String) -> Set<String> {
        var words = Set<String>()
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil

        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let nonWordChars = wordChars.inverted

        while !scanner.isAtEnd {
            if let word = scanner.scanCharacters(from: wordChars) {
                if word.count >= 2 {
                    words.insert(word)
                }
            } else {
                _ = scanner.scanCharacters(from: nonWordChars)
            }
        }
        return words
    }
}

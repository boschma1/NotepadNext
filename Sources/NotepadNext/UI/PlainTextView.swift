import AppKit

/// NSTextView subclass that always pastes and copies as plain text.
class PlainTextView: NSTextView {

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func copy(_ sender: Any?) {
        let range = selectedRange()
        guard range.length > 0 else { return }
        let selectedText = (string as NSString).substring(with: range)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(selectedText, forType: .string)
    }

    override func cut(_ sender: Any?) {
        copy(sender)
        deleteBackward(sender)
    }
}

import AppKit

/// NSTextView subclass that always pastes as plain text.
class PlainTextView: NSTextView {

    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        pasteAsPlainText(sender)
    }
}

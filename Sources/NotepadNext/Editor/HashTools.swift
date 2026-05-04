import AppKit
import CryptoKit

/// Tools menu: hash generation utilities.
class HashTools {

    static func md5(of string: String) -> String {
        let data = Data(string.utf8)
        return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha1(of string: String) -> String {
        let data = Data(string.utf8)
        return Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(of string: String) -> String {
        let data = Data(string.utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha512(of string: String) -> String {
        let data = Data(string.utf8)
        return SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Shows a dialog to generate hashes of input text or current selection.
    static func showHashDialog(selectedText: String?) {
        let alert = NSAlert()
        alert.messageText = "Generate Hash"

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))

        let inputLabel = NSTextField(labelWithString: "Input text:")
        inputLabel.frame = NSRect(x: 0, y: 236, width: 420, height: 18)
        container.addSubview(inputLabel)

        let inputField = NSTextField(frame: NSRect(x: 0, y: 190, width: 420, height: 44))
        inputField.stringValue = selectedText ?? ""
        container.addSubview(inputField)

        let resultLabel = NSTextField(labelWithString: "Results:")
        resultLabel.frame = NSRect(x: 0, y: 166, width: 420, height: 18)
        container.addSubview(resultLabel)

        let results = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 162))
        results.isEditable = false
        results.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        container.addSubview(results)

        alert.accessoryView = container
        alert.addButton(withTitle: "Generate")
        alert.addButton(withTitle: "Close")

        if alert.runModal() == .alertFirstButtonReturn {
            let input = inputField.stringValue
            let output = """
            MD5:    \(md5(of: input))
            SHA-1:  \(sha1(of: input))
            SHA-256: \(sha256(of: input))
            SHA-512: \(sha512(of: input))
            """
            results.string = output

            // Show again with results
            let resultAlert = NSAlert()
            resultAlert.messageText = "Hash Results"
            let resultView = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 120))
            resultView.string = output
            resultView.isEditable = false
            resultView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 120))
            scrollView.documentView = resultView
            scrollView.hasVerticalScroller = true
            resultAlert.accessoryView = scrollView
            resultAlert.addButton(withTitle: "Copy to Clipboard")
            resultAlert.addButton(withTitle: "Close")

            if resultAlert.runModal() == .alertFirstButtonReturn {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(output, forType: .string)
            }
        }
    }
}

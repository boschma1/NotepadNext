import AppKit

/// Represents a single open document (file or unsaved buffer).
class Document {
    let id: UUID
    var title: String
    var fileURL: URL?
    var content: String
    var encoding: String.Encoding
    var lineEnding: LineEnding
    var language: String
    var isModified: Bool = false
    var cursorPosition: Int = 0

    enum LineEnding: String {
        case unix = "LF"
        case windows = "CRLF"
        case classic = "CR"

        var characters: String {
            switch self {
            case .unix: return "\n"
            case .windows: return "\r\n"
            case .classic: return "\r"
            }
        }
    }

    init(title: String = "new 1", fileURL: URL? = nil, content: String = "", encoding: String.Encoding = .utf8) {
        self.id = UUID()
        self.title = title
        self.fileURL = fileURL
        self.content = content
        self.encoding = encoding
        self.lineEnding = .unix
        self.language = "Normal Text"
    }

    /// Load content from file URL
    func load() throws {
        guard let url = fileURL else { return }
        let data = try Data(contentsOf: url)

        // Detect encoding (simple: try UTF-8, fallback to system)
        if let str = String(data: data, encoding: .utf8) {
            content = str
            encoding = .utf8
        } else if let str = String(data: data, encoding: .macOSRoman) {
            content = str
            encoding = .macOSRoman
        } else {
            content = String(data: data, encoding: .ascii) ?? ""
            encoding = .ascii
        }

        // Detect line endings
        if content.contains("\r\n") {
            lineEnding = .windows
        } else if content.contains("\r") {
            lineEnding = .classic
        } else {
            lineEnding = .unix
        }

        isModified = false
    }

    /// Save content to file URL
    func save(to url: URL? = nil) throws {
        let targetURL = url ?? fileURL
        guard let targetURL else {
            throw DocumentError.noFileURL
        }

        guard let data = content.data(using: encoding) else {
            throw DocumentError.encodingFailed
        }

        try data.write(to: targetURL, options: .atomic)
        fileURL = targetURL
        title = targetURL.lastPathComponent
        isModified = false
    }

    var displayTitle: String {
        let prefix = isModified ? "● " : ""
        return prefix + title
    }

    enum DocumentError: Error, LocalizedError {
        case noFileURL
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .noFileURL: return "No file path specified."
            case .encodingFailed: return "Failed to encode document content."
            }
        }
    }
}

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
    var wordWrapEnabled: Bool = false
    var usesSpaces: Bool = false
    var tabSize: Int = 4
    var isPinned: Bool = false

    /// Snapshot of the file's on-disk identity at the moment we last
    /// read or wrote it. Used to tell external modifications apart
    /// from our own writes.
    var lastKnownDiskSignature: DiskSignature?

    struct DiskSignature: Equatable {
        let inode: UInt64
        let size: Int64
        let mtimeSec: Int64
        let mtimeNsec: Int64
    }

    /// Stats `url` and returns the current disk signature, or `nil`
    /// if the file does not exist or cannot be read.
    static func diskSignature(of url: URL) -> DiskSignature? {
        var st = stat()
        guard stat(url.path, &st) == 0 else { return nil }
        return DiskSignature(
            inode: UInt64(st.st_ino),
            size: Int64(st.st_size),
            mtimeSec: Int64(st.st_mtimespec.tv_sec),
            mtimeNsec: Int64(st.st_mtimespec.tv_nsec)
        )
    }

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
        lastKnownDiskSignature = Document.diskSignature(of: url)
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
        lastKnownDiskSignature = Document.diskSignature(of: targetURL)
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

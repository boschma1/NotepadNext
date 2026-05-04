import AppKit

/// Lightweight syntax highlighter using NSTextStorage delegate.
/// This is a placeholder until Scintilla integration replaces it.
/// It supports basic keyword, string, comment, and number highlighting.
class SyntaxHighlighter: NSObject, NSTextStorageDelegate {

    var language: String = "Normal Text" {
        didSet { updateRules() }
    }

    var theme: SyntaxTheme = .defaultLight

    private var rules: [HighlightRule] = []
    private var isHighlighting = false

    struct HighlightRule {
        let pattern: String
        let options: NSRegularExpression.Options
        let color: NSColor
        let fontTrait: NSFontTraitMask?

        var regex: NSRegularExpression? {
            try? NSRegularExpression(pattern: pattern, options: options)
        }
    }

    override init() {
        super.init()
        updateRules()
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters), !isHighlighting else { return }

        isHighlighting = true
        highlightSyntax(in: textStorage, range: NSRange(location: 0, length: textStorage.length))
        isHighlighting = false
    }

    private func highlightSyntax(in textStorage: NSTextStorage, range: NSRange) {
        // Reset to default style
        let defaultFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textStorage.addAttribute(.foregroundColor, value: theme.defaultColor, range: range)
        textStorage.addAttribute(.font, value: defaultFont, range: range)

        let string = textStorage.string

        for rule in rules {
            guard let regex = rule.regex else { continue }
            regex.enumerateMatches(in: string, range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }
                textStorage.addAttribute(.foregroundColor, value: rule.color, range: matchRange)
                if let trait = rule.fontTrait {
                    let boldFont = NSFontManager.shared.convert(defaultFont, toHaveTrait: trait)
                    textStorage.addAttribute(.font, value: boldFont, range: matchRange)
                }
            }
        }
    }

    private func updateRules() {
        rules = SyntaxRules.rules(for: language, theme: theme)
    }
}

// MARK: - Theme

struct SyntaxTheme {
    let defaultColor: NSColor
    let keywordColor: NSColor
    let stringColor: NSColor
    let commentColor: NSColor
    let numberColor: NSColor
    let typeColor: NSColor
    let preprocessorColor: NSColor
    let operatorColor: NSColor

    static let defaultLight = SyntaxTheme(
        defaultColor: .textColor,
        keywordColor: NSColor(red: 0.0, green: 0.0, blue: 0.8, alpha: 1.0),
        stringColor: NSColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0),
        commentColor: NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1.0),
        numberColor: NSColor(red: 0.8, green: 0.4, blue: 0.0, alpha: 1.0),
        typeColor: NSColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1.0),
        preprocessorColor: NSColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0),
        operatorColor: .textColor
    )

    static let dark = SyntaxTheme(
        defaultColor: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0),
        keywordColor: NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),
        stringColor: NSColor(red: 0.9, green: 0.5, blue: 0.3, alpha: 1.0),
        commentColor: NSColor(red: 0.4, green: 0.7, blue: 0.4, alpha: 1.0),
        numberColor: NSColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1.0),
        typeColor: NSColor(red: 0.3, green: 0.8, blue: 0.8, alpha: 1.0),
        preprocessorColor: NSColor(red: 0.7, green: 0.5, blue: 0.9, alpha: 1.0),
        operatorColor: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
    )
}

// MARK: - Language-specific rules

struct SyntaxRules {

    static func rules(for language: String, theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        switch language {
        case "Swift":
            return cStyleRules(theme: theme, keywords: swiftKeywords, types: swiftTypes)
        case "Python":
            return pythonRules(theme: theme)
        case "JavaScript", "TypeScript":
            return cStyleRules(theme: theme, keywords: jsKeywords, types: jsTypes)
        case "Java":
            return cStyleRules(theme: theme, keywords: javaKeywords, types: javaTypes)
        case "C", "C++", "Objective-C", "Objective-C++":
            return cStyleRules(theme: theme, keywords: cKeywords, types: cTypes)
        case "C#":
            return cStyleRules(theme: theme, keywords: csharpKeywords, types: csharpTypes)
        case "Go":
            return cStyleRules(theme: theme, keywords: goKeywords, types: goTypes)
        case "Rust":
            return cStyleRules(theme: theme, keywords: rustKeywords, types: rustTypes)
        case "Ruby":
            return rubyRules(theme: theme)
        case "PHP":
            return cStyleRules(theme: theme, keywords: phpKeywords, types: phpTypes)
        case "HTML", "XML":
            return markupRules(theme: theme)
        case "CSS":
            return cssRules(theme: theme)
        case "JSON":
            return jsonRules(theme: theme)
        case "Shell":
            return shellRules(theme: theme)
        case "SQL":
            return sqlRules(theme: theme)
        case "Markdown":
            return markdownRules(theme: theme)
        default:
            return []
        }
    }

    // MARK: - C-family rules

    private static func cStyleRules(theme: SyntaxTheme, keywords: [String], types: [String]) -> [SyntaxHighlighter.HighlightRule] {
        let kwPattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        let typePattern = "\\b(" + types.joined(separator: "|") + ")\\b"

        return [
            // Block comments
            .init(pattern: "/\\*[\\s\\S]*?\\*/", options: [], color: theme.commentColor, fontTrait: .italicFontMask),
            // Line comments
            .init(pattern: "//.*$", options: [.anchorsMatchLines], color: theme.commentColor, fontTrait: .italicFontMask),
            // Strings (double-quoted)
            .init(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", options: [], color: theme.stringColor, fontTrait: nil),
            // Strings (single-quoted)
            .init(pattern: "'(?:[^'\\\\]|\\\\.)*'", options: [], color: theme.stringColor, fontTrait: nil),
            // Numbers
            .init(pattern: "\\b(?:0[xX][0-9a-fA-F]+|0[bB][01]+|0[oO][0-7]+|\\d+\\.?\\d*(?:[eE][+-]?\\d+)?)\\b", options: [], color: theme.numberColor, fontTrait: nil),
            // Keywords
            .init(pattern: kwPattern, options: [], color: theme.keywordColor, fontTrait: .boldFontMask),
            // Types
            .init(pattern: typePattern, options: [], color: theme.typeColor, fontTrait: nil),
            // Preprocessor
            .init(pattern: "^\\s*#\\w+", options: [.anchorsMatchLines], color: theme.preprocessorColor, fontTrait: nil),
        ]
    }

    // MARK: - Python

    private static func pythonRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        let kw = ["False", "None", "True", "and", "as", "assert", "async", "await", "break",
                   "class", "continue", "def", "del", "elif", "else", "except", "finally",
                   "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal",
                   "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"]
        let types = ["int", "float", "str", "bool", "list", "dict", "tuple", "set", "bytes",
                     "type", "object", "Exception"]
        let kwPattern = "\\b(" + kw.joined(separator: "|") + ")\\b"
        let typePattern = "\\b(" + types.joined(separator: "|") + ")\\b"

        return [
            .init(pattern: "#.*$", options: [.anchorsMatchLines], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "\"\"\"[\\s\\S]*?\"\"\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "'''[\\s\\S]*?'''", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "'(?:[^'\\\\]|\\\\.)*'", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "\\b\\d+\\.?\\d*(?:[eE][+-]?\\d+)?\\b", options: [], color: theme.numberColor, fontTrait: nil),
            .init(pattern: kwPattern, options: [], color: theme.keywordColor, fontTrait: .boldFontMask),
            .init(pattern: typePattern, options: [], color: theme.typeColor, fontTrait: nil),
            .init(pattern: "@\\w+", options: [], color: theme.preprocessorColor, fontTrait: nil),
        ]
    }

    // MARK: - Markup (HTML/XML)

    private static func markupRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        return [
            .init(pattern: "<!--[\\s\\S]*?-->", options: [], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "</?\\w+[^>]*>", options: [], color: theme.keywordColor, fontTrait: nil),
            .init(pattern: "\\b\\w+(?==)", options: [], color: theme.typeColor, fontTrait: nil),
            .init(pattern: "\"[^\"]*\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "'[^']*'", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "&\\w+;", options: [], color: theme.numberColor, fontTrait: nil),
        ]
    }

    // MARK: - CSS

    private static func cssRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        return [
            .init(pattern: "/\\*[\\s\\S]*?\\*/", options: [], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "[.#]\\w[\\w-]*", options: [], color: theme.keywordColor, fontTrait: .boldFontMask),
            .init(pattern: "@\\w+", options: [], color: theme.preprocessorColor, fontTrait: nil),
            .init(pattern: "\"[^\"]*\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "#[0-9a-fA-F]{3,8}\\b", options: [], color: theme.numberColor, fontTrait: nil),
            .init(pattern: "\\b\\d+\\.?\\d*(px|em|rem|%|vh|vw|s|ms)?\\b", options: [], color: theme.numberColor, fontTrait: nil),
        ]
    }

    // MARK: - JSON

    private static func jsonRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        return [
            .init(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"\\s*:", options: [], color: theme.keywordColor, fontTrait: nil),
            .init(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "\\b(?:true|false|null)\\b", options: [], color: theme.keywordColor, fontTrait: .boldFontMask),
            .init(pattern: "-?\\b\\d+\\.?\\d*(?:[eE][+-]?\\d+)?\\b", options: [], color: theme.numberColor, fontTrait: nil),
        ]
    }

    // MARK: - Shell

    private static func shellRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        let kw = ["if", "then", "else", "elif", "fi", "for", "while", "do", "done",
                   "case", "esac", "function", "return", "exit", "export", "local",
                   "in", "select", "until", "source"]
        let kwPattern = "\\b(" + kw.joined(separator: "|") + ")\\b"

        return [
            .init(pattern: "#.*$", options: [.anchorsMatchLines], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "'[^']*'", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "\\$\\{?\\w+\\}?", options: [], color: theme.typeColor, fontTrait: nil),
            .init(pattern: kwPattern, options: [], color: theme.keywordColor, fontTrait: .boldFontMask),
        ]
    }

    // MARK: - SQL

    private static func sqlRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        let kw = ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
                   "DELETE", "CREATE", "DROP", "ALTER", "TABLE", "INDEX", "VIEW", "JOIN",
                   "INNER", "LEFT", "RIGHT", "OUTER", "ON", "AND", "OR", "NOT", "IN",
                   "IS", "NULL", "AS", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET",
                   "UNION", "ALL", "DISTINCT", "BETWEEN", "LIKE", "EXISTS", "CASE", "WHEN",
                   "THEN", "ELSE", "END", "BEGIN", "COMMIT", "ROLLBACK", "PRIMARY", "KEY",
                   "FOREIGN", "REFERENCES", "DEFAULT", "CONSTRAINT", "IF", "REPLACE"]
        let kwPattern = "\\b(" + kw.joined(separator: "|") + ")\\b"

        return [
            .init(pattern: "--.*$", options: [.anchorsMatchLines], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "/\\*[\\s\\S]*?\\*/", options: [], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "'(?:[^'\\\\]|\\\\.)*'", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "\\b\\d+\\.?\\d*\\b", options: [], color: theme.numberColor, fontTrait: nil),
            .init(pattern: kwPattern, options: [.caseInsensitive], color: theme.keywordColor, fontTrait: .boldFontMask),
        ]
    }

    // MARK: - Ruby

    private static func rubyRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        let kw = ["BEGIN", "END", "alias", "and", "begin", "break", "case", "class",
                   "def", "defined?", "do", "else", "elsif", "end", "ensure", "false",
                   "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
                   "rescue", "retry", "return", "self", "super", "then", "true",
                   "undef", "unless", "until", "when", "while", "yield"]
        let kwPattern = "\\b(" + kw.joined(separator: "|") + ")\\b"

        return [
            .init(pattern: "#.*$", options: [.anchorsMatchLines], color: theme.commentColor, fontTrait: .italicFontMask),
            .init(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "'(?:[^'\\\\]|\\\\.)*'", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: ":\\w+", options: [], color: theme.typeColor, fontTrait: nil),
            .init(pattern: "@\\w+", options: [], color: theme.typeColor, fontTrait: nil),
            .init(pattern: kwPattern, options: [], color: theme.keywordColor, fontTrait: .boldFontMask),
        ]
    }

    // MARK: - Markdown

    private static func markdownRules(theme: SyntaxTheme) -> [SyntaxHighlighter.HighlightRule] {
        return [
            .init(pattern: "^#{1,6}\\s.*$", options: [.anchorsMatchLines], color: theme.keywordColor, fontTrait: .boldFontMask),
            .init(pattern: "\\*\\*[^*]+\\*\\*", options: [], color: theme.defaultColor, fontTrait: .boldFontMask),
            .init(pattern: "\\*[^*]+\\*", options: [], color: theme.defaultColor, fontTrait: .italicFontMask),
            .init(pattern: "`[^`]+`", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "```[\\s\\S]*?```", options: [], color: theme.stringColor, fontTrait: nil),
            .init(pattern: "\\[([^\\]]+)\\]\\([^)]+\\)", options: [], color: theme.typeColor, fontTrait: nil),
            .init(pattern: "^\\s*[-*+]\\s", options: [.anchorsMatchLines], color: theme.numberColor, fontTrait: nil),
            .init(pattern: "^\\s*\\d+\\.\\s", options: [.anchorsMatchLines], color: theme.numberColor, fontTrait: nil),
        ]
    }

    // MARK: - Keyword lists

    private static let swiftKeywords = ["actor", "associatedtype", "async", "await", "break", "case", "catch",
        "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension",
        "fallthrough", "fileprivate", "for", "func", "guard", "if", "import", "in", "init",
        "inout", "internal", "is", "let", "nonisolated", "open", "operator", "override",
        "precedencegroup", "private", "protocol", "public", "repeat", "rethrows", "return",
        "self", "Self", "static", "struct", "subscript", "super", "switch", "throw", "throws",
        "try", "typealias", "var", "where", "while", "nil", "true", "false", "some", "any"]

    private static let swiftTypes = ["Int", "String", "Double", "Float", "Bool", "Array", "Dictionary",
        "Set", "Optional", "Result", "Void", "Any", "AnyObject", "Error", "Codable",
        "Equatable", "Hashable", "Comparable", "Identifiable", "Sendable"]

    private static let jsKeywords = ["async", "await", "break", "case", "catch", "class", "const",
        "continue", "debugger", "default", "delete", "do", "else", "export", "extends",
        "finally", "for", "function", "if", "import", "in", "instanceof", "let", "new",
        "of", "return", "static", "super", "switch", "this", "throw", "try", "typeof",
        "var", "void", "while", "with", "yield", "true", "false", "null", "undefined"]

    private static let jsTypes = ["Number", "String", "Boolean", "Object", "Array", "Function",
        "Symbol", "BigInt", "Map", "Set", "Promise", "Date", "RegExp", "Error"]

    private static let cKeywords = ["auto", "break", "case", "char", "const", "continue", "default",
        "do", "double", "else", "enum", "extern", "float", "for", "goto", "if", "inline",
        "int", "long", "register", "restrict", "return", "short", "signed", "sizeof",
        "static", "struct", "switch", "typedef", "union", "unsigned", "void", "volatile",
        "while", "class", "namespace", "template", "this", "new", "delete", "try", "catch",
        "throw", "virtual", "override", "public", "private", "protected", "using",
        "true", "false", "nullptr", "constexpr", "auto", "decltype", "noexcept"]

    private static let cTypes = ["int", "char", "float", "double", "void", "bool", "long",
        "short", "unsigned", "signed", "size_t", "string", "vector", "map", "set",
        "unique_ptr", "shared_ptr", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
        "int8_t", "int16_t", "int32_t", "int64_t"]

    private static let javaKeywords = ["abstract", "assert", "boolean", "break", "byte", "case",
        "catch", "char", "class", "continue", "default", "do", "double", "else", "enum",
        "extends", "final", "finally", "float", "for", "if", "implements", "import",
        "instanceof", "int", "interface", "long", "native", "new", "package", "private",
        "protected", "public", "return", "short", "static", "strictfp", "super", "switch",
        "synchronized", "this", "throw", "throws", "transient", "try", "void", "volatile",
        "while", "true", "false", "null", "var", "yield", "record", "sealed", "permits"]

    private static let javaTypes = ["String", "Integer", "Long", "Double", "Float", "Boolean",
        "Object", "List", "Map", "Set", "ArrayList", "HashMap", "Optional"]

    private static let csharpKeywords = ["abstract", "as", "base", "bool", "break", "byte", "case",
        "catch", "char", "checked", "class", "const", "continue", "decimal", "default",
        "delegate", "do", "double", "else", "enum", "event", "explicit", "extern", "false",
        "finally", "fixed", "float", "for", "foreach", "goto", "if", "implicit", "in",
        "int", "interface", "internal", "is", "lock", "long", "namespace", "new", "null",
        "object", "operator", "out", "override", "params", "private", "protected", "public",
        "readonly", "ref", "return", "sbyte", "sealed", "short", "sizeof", "stackalloc",
        "static", "string", "struct", "switch", "this", "throw", "true", "try", "typeof",
        "uint", "ulong", "unchecked", "unsafe", "ushort", "using", "var", "virtual", "void",
        "volatile", "while", "async", "await", "record"]

    private static let csharpTypes = ["String", "Int32", "Int64", "Boolean", "Double", "Decimal",
        "Object", "List", "Dictionary", "Task", "IEnumerable"]

    private static let goKeywords = ["break", "case", "chan", "const", "continue", "default",
        "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
        "interface", "map", "package", "range", "return", "select", "struct", "switch",
        "type", "var", "true", "false", "nil", "iota"]

    private static let goTypes = ["int", "int8", "int16", "int32", "int64", "uint", "uint8",
        "uint16", "uint32", "uint64", "float32", "float64", "complex64", "complex128",
        "string", "bool", "byte", "rune", "error", "any"]

    private static let rustKeywords = ["as", "async", "await", "break", "const", "continue",
        "crate", "dyn", "else", "enum", "extern", "false", "fn", "for", "if", "impl",
        "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
        "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe",
        "use", "where", "while", "yield"]

    private static let rustTypes = ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16",
        "u32", "u64", "u128", "usize", "f32", "f64", "bool", "char", "str", "String",
        "Vec", "Option", "Result", "Box", "Rc", "Arc", "HashMap", "HashSet"]

    private static let phpKeywords = ["abstract", "and", "array", "as", "break", "callable",
        "case", "catch", "class", "clone", "const", "continue", "declare", "default",
        "die", "do", "echo", "else", "elseif", "empty", "enddeclare", "endfor",
        "endforeach", "endif", "endswitch", "endwhile", "eval", "exit", "extends",
        "final", "finally", "fn", "for", "foreach", "function", "global", "goto",
        "if", "implements", "include", "instanceof", "interface", "isset", "list",
        "match", "namespace", "new", "or", "print", "private", "protected", "public",
        "readonly", "require", "return", "static", "switch", "throw", "trait", "try",
        "unset", "use", "var", "while", "xor", "yield", "true", "false", "null"]

    private static let phpTypes = ["int", "float", "string", "bool", "array", "object",
        "callable", "iterable", "void", "mixed", "never", "null"]
}

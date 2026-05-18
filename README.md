# NotepadNext

A fast, native macOS text editor in the spirit of Notepad++ — built from the
ground up in Swift on top of AppKit. NotepadNext aims to be the
quick-to-launch, no-friction scratchpad and code editor that macOS has been
missing: open a file, edit it, save it, get out.

> **Status:** v1.0.0 — first public release. Apple Silicon only for now.

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![Architecture arm64](https://img.shields.io/badge/arch-arm64-lightgrey)

---

## Why NotepadNext?

macOS ships with TextEdit, which is fine for the occasional note but isn't
designed for programmers or power users. The other end of the spectrum —
VS Code, Sublime, the JetBrains suite — is overkill when you just want to
peek at a log, tweak a config file, or jot something down.

NotepadNext sits in the middle:

- **Launches instantly.** It's a small, native AppKit app — not Electron.
- **Real tabs, real sessions.** Reopen the app and your tabs come back
  exactly as you left them, including unsaved scratch content.
- **Plain text first.** Copy/cut/paste is always plain text — no surprise
  RTF formatting leaking into your editor or your clipboard.
- **Sensible defaults for developers.** Line numbers, current-line
  highlight, syntax colors for common languages, find & replace, go-to-line,
  word completion, and a status bar with cursor/encoding info — all on by
  default, all configurable.

If you've ever wished Notepad++ ran natively on macOS, this is for you.

## Features

### Editing
- Multi-tab document editor with drag-to-reorder tabs
- Drag a tab **out of the window** to spawn a new instance (or merge tabs
  back in)
- Split-view editing for side-by-side files / file comparison
- Plain-text copy, cut, and paste — RTF formatting is stripped on the way in
  and the way out
- Line operations: duplicate line, move/delete line, etc.
- Word completion as you type
- Macro recorder for repetitive edits
- Clickable URLs in the editor
- Auto-detected indentation per file
- Per-tab word wrap toggle
- Configurable current-line highlight

### Navigation & search
- Find & Replace (per document)
- Find in Files (across a folder)
- Go to Line
- Function List panel — jump to functions/symbols in the current document
- Document Map — minimap-style overview of the current file
- Folder workspace / project panel for browsing a directory tree
- Document List panel for quickly switching between open tabs

### Sessions & files
- Session restore: tabs, cursor positions, and unsaved scratch content
  persist across app restarts
- Recent Files submenu in the File menu
- Single-instance behavior: opening a file from Finder reuses the running
  app (with optional offset for new windows)
- Modified-dot indicator on tabs

### Languages & syntax highlighting
First-class syntax highlighting for:

Swift · Python · Java · C# · Go · Rust · Ruby · PHP · Dart · Kotlin ·
Shell (bash/zsh) · SQL · JSON · CSS · Markdown

Many more file types are recognized for opening (HTML, XML, YAML, TOML,
plist, GraphQL, etc.).

### Customization
- Theme manager (light/dark, configurable colors)
- Shortcut Mapper for rebinding keyboard shortcuts
- User Defined Language (UDL) editor — define your own syntax rules
- Preferences window for fonts, tabs/spaces, indentation, and more
- Plugin manager (extension point for future plugins)

## Requirements

- macOS **13.0 (Ventura)** or later
- Apple Silicon (**arm64**)
- For building from source: **Swift 6.0 toolchain** (Xcode 16 or
  swift.org toolchain)

> An Intel (x86_64) and a universal build are planned; for now the release
> binary is arm64-only.

## Installation

### Download the release

1. Grab `NotepadNext-v1.0.0-macOS-arm64.zip` from
   [Releases](https://github.com/boschma1/NotepadNext/releases/latest).
2. Unzip and drag **NotepadNext.app** into `/Applications`.
3. Because the build is **ad-hoc signed (not notarized)**, the first launch
   will be blocked by Gatekeeper. Either right-click → **Open** the first
   time, or remove the quarantine attribute:

   ```sh
   xattr -dr com.apple.quarantine /Applications/NotepadNext.app
   ```

### Build from source

```sh
git clone https://github.com/boschma1/NotepadNext.git
cd NotepadNext
swift build -c release --arch arm64
# the binary lands at .build/arm64-apple-macosx/release/NotepadNext
```

To run inside the bundled `.app`:

```sh
cp .build/arm64-apple-macosx/release/NotepadNext \
   NotepadNext.app/Contents/MacOS/NotepadNext
open NotepadNext.app
```

## Project layout

```
NotepadNext/
├── Package.swift                  # Swift Package manifest (executable target)
├── NotepadNext.app/               # Curated .app bundle (Info.plist, icon, signature)
├── Resources/                     # App icon and bundled resources
└── Sources/NotepadNext/
    ├── App/                       # AppDelegate, MenuManager, entry point
    ├── Config/                    # Preferences, themes, sessions, recent files, plugins
    ├── Document/                  # Document model & manager
    ├── Editor/                    # Syntax highlighter, macros, word completion, line highlight
    └── UI/                        # Windows, tab bar, panels, find/replace, gutter, status bar
```

## Roadmap

- Universal (arm64 + x86_64) builds
- Developer ID signing and notarization
- Homebrew cask
- Plugin API documentation
- More built-in language definitions

## Contributing

Issues and pull requests are welcome. Please open an issue first for
larger changes so we can discuss the approach.

## License

To be decided. Until a license file is added, all rights are reserved by
the author — please open an issue if you need a specific license for your
use case.

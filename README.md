# NotepadMacMac

A fast, native macOS text editor in the spirit of Notepad++ — built from the
ground up in Swift on top of AppKit. NotepadMacMac aims to be the
quick-to-launch, no-friction scratchpad and code editor that macOS has been
missing: open a file, edit it, save it, get out.

> **Status:** v1.2.0 — universal build (Apple Silicon + Intel).

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![Architecture universal](https://img.shields.io/badge/arch-universal%20(arm64%20%2B%20x86__64)-lightgrey)

---

## Why NotepadMacMac?

macOS ships with TextEdit, which is fine for the occasional note but isn't
designed for programmers or power users. The other end of the spectrum —
VS Code, Sublime, the JetBrains suite — is overkill when you just want to
peek at a log, tweak a config file, or jot something down.

NotepadMacMac sits in the middle:

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
- **External-change detection**: if an open file is modified or deleted
  by another app (e.g. TextEdit), NotepadMacMac prompts you to reload it
  from disk or keep your in-editor version

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
- Apple Silicon (**arm64**) or Intel (**x86_64**) — the release binary is
  a universal Mach-O containing both slices
- For building from source: **Swift 6.0 toolchain** (Xcode 16 or
  swift.org toolchain)

## Installation

### Download the release

1. Grab the latest build from
   [Releases](https://github.com/boschma1/NotepadMacMac/releases/latest).
   Either of these download URLs works:

   - **Latest (always-fresh):**
     `https://github.com/boschma1/NotepadMacMac/releases/latest/download/NotepadMacMac-latest.zip`
   - **A specific version:** the `NotepadMacMac-vX.Y.Z-macOS-universal.zip`
     asset attached to that release.

2. Unzip and drag **NotepadMacMac.app** into `/Applications`.
3. Because the build is **ad-hoc signed (not notarized)**, the first launch
   will be blocked by Gatekeeper. Either right-click → **Open** the first
   time, or remove the quarantine attribute:

   ```sh
   xattr -dr com.apple.quarantine /Applications/NotepadMacMac.app
   ```

### Build from source

```sh
git clone https://github.com/boschma1/NotepadMacMac.git
cd NotepadMacMac
swift build -c release --arch arm64 --arch x86_64
# the universal binary lands at .build/apple/Products/Release/NotepadMacMac
```

To run inside the bundled `.app`:

```sh
cp .build/apple/Products/Release/NotepadMacMac \
   NotepadMacMac.app/Contents/MacOS/NotepadMacMac
open NotepadMacMac.app
```

## Cutting a release

The whole release flow — build, refresh the in-tree `.app` bundle, codesign,
commit, tag, push, and create the GitHub release with both a versioned
asset and the stable `NotepadMacMac-latest.zip` — is wrapped up in a single
script:

```sh
# 1. Bump CFBundleShortVersionString in NotepadMacMac.app/Contents/Info.plist
#    and `static let version` in Sources/NotepadMacMac/Config/AppConfig.swift
#    to the same value (e.g. 1.2.0).
# 2. Make any other source changes for the release. Leave everything uncommitted.
# 3. (Optional) write release notes to a markdown file.
# 4. Run:

./scripts/release.sh \
    --message "Add fancy new feature (v1.2.0)" \
    --notes-file release-notes.md
```

The script verifies that both version strings agree, that the tag doesn't
already exist locally or on the remote, builds the release binary, refreshes
the bundle and re-signs it ad-hoc, shows a summary, and on confirmation
commits + tags + pushes + creates the GitHub release with both:

- `NotepadMacMac-vX.Y.Z-macOS-universal.zip` (versioned, archival)
- `NotepadMacMac-latest.zip` (stable, served from the always-latest URL)

Use `--dry-run` to validate everything and rebuild the bundle without
publishing, and `--yes` to skip the interactive confirmation.

## Project layout

```
NotepadMacMac/
├── Package.swift                  # Swift Package manifest (executable target)
├── NotepadMacMac.app/               # Curated .app bundle (Info.plist, icon, signature)
├── Resources/                     # App icon and bundled resources
└── Sources/NotepadMacMac/
    ├── App/                       # AppDelegate, MenuManager, entry point
    ├── Config/                    # Preferences, themes, sessions, recent files, plugins
    ├── Document/                  # Document model & manager
    ├── Editor/                    # Syntax highlighter, macros, word completion, line highlight
    └── UI/                        # Windows, tab bar, panels, find/replace, gutter, status bar
```

## Roadmap

The next planned release is tracked under the
[**v1.1.0** milestone](https://github.com/boschma1/NotepadMacMac/milestone/1).
Highlights:

- [Universal (arm64 + x86_64) builds](https://github.com/boschma1/NotepadMacMac/issues/1)
- [Developer ID signing and notarization](https://github.com/boschma1/NotepadMacMac/issues/2)
- [Homebrew cask](https://github.com/boschma1/NotepadMacMac/issues/3)
- [Plugin API documentation](https://github.com/boschma1/NotepadMacMac/issues/4)
- [More built-in language definitions](https://github.com/boschma1/NotepadMacMac/issues/5)
- [Automated test suite](https://github.com/boschma1/NotepadMacMac/issues/6)

See [ROADMAP.md](./ROADMAP.md) for the full plan.

## Contributing

Issues and pull requests are welcome. Please open an issue first for
larger changes so we can discuss the approach.

## License

To be decided. Until a license file is added, all rights are reserved by
the author — please open an issue if you need a specific license for your
use case.

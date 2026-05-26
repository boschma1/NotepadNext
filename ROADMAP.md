# Roadmap

This file tracks what's planned for NotepadMacMac beyond
[v1.0.0](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.0.0).
Each item is also a public issue on GitHub so you can follow progress,
comment, or pick one up.

The active milestone is
[**v1.1.0**](https://github.com/boschma1/NotepadMacMac/milestone/1).

## Shipped in v1.0.0

See the [v1.0.0 release notes](https://github.com/boschma1/NotepadMacMac/releases/tag/v1.0.0)
for the full feature list. Highlights:

- Multi-tab editor with drag-to-reorder, drag-out-to-new-instance, split view
- Session restore (tabs + unsaved scratch content)
- Find / Replace, Find in Files, Go to Line
- Function List, Document Map, Folder workspace, Document List panels
- Macro recorder, word completion, per-tab word wrap, indentation detection
- Syntax highlighting for 15 languages
- Theme manager, Shortcut Mapper, User Defined Language editor
- Recent Files, single-instance behavior, plain-text clipboard

## Planned (v1.1.0)

| #   | Item                                                                                          | Area          |
| --- | --------------------------------------------------------------------------------------------- | ------------- |
| [#1](https://github.com/boschma1/NotepadMacMac/issues/1) | Universal (arm64 + x86_64) build           | Distribution  |
| [#2](https://github.com/boschma1/NotepadMacMac/issues/2) | Developer ID signing + notarization        | Distribution  |
| [#3](https://github.com/boschma1/NotepadMacMac/issues/3) | Homebrew cask                              | Distribution  |
| [#4](https://github.com/boschma1/NotepadMacMac/issues/4) | Document the plugin API                    | Plugins       |
| [#5](https://github.com/boschma1/NotepadMacMac/issues/5) | More built-in language definitions         | Languages     |
| [#6](https://github.com/boschma1/NotepadMacMac/issues/6) | Add an automated test suite                | Tests         |

### Notes

- **Universal binary** unblocks Intel Mac users; current release is
  Apple Silicon only.
- **Signing + notarization** removes the Gatekeeper warning on first
  launch and is a prerequisite for the Homebrew cask.
- **Plugin API documentation** turns the existing `PluginManager`
  extension point into something third parties can target safely.
- **More languages**: HTML / XML / YAML / TOML / plist / GraphQL /
  JavaScript / TypeScript / JSX / TSX / C / C++ / Objective-C /
  Lua / Perl / R / Scala / Groovy. These are recognized by file
  extension today but don't have first-class syntax definitions.
- **Tests**: a `swift test` target plus a GitHub Actions workflow.

## Ideas / not yet scheduled

These are things that have been mentioned but aren't on a milestone yet.
Open an issue if you want to push any of them up the list.

- Multi-cursor / column-selection editing
- LSP integration for real code intelligence
- Built-in terminal panel
- Git status decorations in the folder workspace
- Settings sync across Macs
- Linux / Windows builds (would require a non-AppKit UI layer)

## Contributing

If you'd like to take on a roadmap item, comment on the issue first so
we can discuss the approach and avoid duplicate work. Smaller fixes and
typos can go straight to a pull request.

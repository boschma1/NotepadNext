import AppKit

// Register as a regular GUI app before anything else
NSApplication.shared.setActivationPolicy(.regular)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

// Ensure the app is activated and frontmost
NSApplication.shared.activate(ignoringOtherApps: true)
NSApplication.shared.run()

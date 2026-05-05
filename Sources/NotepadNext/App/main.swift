import AppKit

// Check if another instance is already running
let bundleID = "com.notepadnext.app"
let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
let otherInstance = runningApps.first { $0 != NSRunningApplication.current }

if let other = otherInstance {
    // Another instance is running — send files to it and exit
    other.activate()

    // Forward any file arguments via open command
    let args = CommandLine.arguments.dropFirst()
    if !args.isEmpty {
        for arg in args {
            let url = URL(fileURLWithPath: arg)
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: other.bundleURL!,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
    exit(0)
}

// Register as a regular GUI app
NSApplication.shared.setActivationPolicy(.regular)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

NSApplication.shared.activate(ignoringOtherApps: true)
NSApplication.shared.run()

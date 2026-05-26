import AppKit

let args = CommandLine.arguments
let forceNewInstance = args.contains("--new-instance")

// Check if another instance is already running (unless forced)
if !forceNewInstance {
    let bundleID = "com.notepadnext.app"
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let otherInstance = runningApps.first { $0 != NSRunningApplication.current }

    if let other = otherInstance {
        other.activate()
        let fileArgs = args.dropFirst().filter { !$0.starts(with: "-") }
        if !fileArgs.isEmpty {
            for arg in fileArgs {
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
}

NSApplication.shared.setActivationPolicy(.regular)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

NSApplication.shared.activate(ignoringOtherApps: true)
NSApplication.shared.run()

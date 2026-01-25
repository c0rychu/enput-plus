import Cocoa
import InputMethodKit
import os.log

// MARK: - Application Entry Point

/// Input Method applications require manual AppDelegate setup before NSApplicationMain.
/// This is the standard pattern for IMKServer-based input methods.

private let appDelegate = AppDelegate()
private let log = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? Constants.App.bundleIdentifier,
    category: "Main"
)

autoreleasepool {
    os_log("Starting EnputPlus", log: log, type: .info)
    NSApplication.shared.delegate = appDelegate
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}

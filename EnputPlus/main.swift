import Cocoa
import InputMethodKit
import os.log

private let appDelegate = AppDelegate()
private let log = OSLog(subsystem: "com.enputplus.inputmethod.EnputPlus", category: "main")

os_log("EnputPlus: Starting app", log: log, type: .default)
NSApplication.shared.delegate = appDelegate
os_log("EnputPlus: Delegate set, calling NSApplicationMain", log: log, type: .default)
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

import Cocoa
import InputMethodKit
import os.log

private let log = OSLog(subsystem: "com.enputplus.inputmethod.EnputPlus", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {

    var server: IMKServer!
    var candidatesWindow: IMKCandidates!

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("EnputPlus: applicationDidFinishLaunching called", log: log, type: .default)

        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            NSLog("EnputPlus: ERROR - Failed to get InputMethodConnectionName from Info.plist")
            return
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            NSLog("EnputPlus: ERROR - Failed to get bundle identifier")
            return
        }

        NSLog("EnputPlus: Initializing IMKServer with connection: \(connectionName), bundle: \(bundleIdentifier)")

        server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)

        if server == nil {
            NSLog("EnputPlus: ERROR - IMKServer initialization failed!")
        } else {
            NSLog("EnputPlus: IMKServer initialized successfully")
        }

        candidatesWindow = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )

        if candidatesWindow == nil {
            NSLog("EnputPlus: ERROR - IMKCandidates initialization failed!")
        } else {
            NSLog("EnputPlus: IMKCandidates initialized successfully")
        }

        NSLog("EnputPlus: Initialization complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("EnputPlus: applicationWillTerminate called")
    }
}

import Cocoa
import InputMethodKit
import os.log

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "EnputPlus", category: "AppDelegate")

    var server: IMKServer!
    var candidatesWindow: IMKCandidates!

    func applicationDidFinishLaunching(_ notification: Notification) {
        os_log("EnputPlus launching...", log: AppDelegate.log, type: .info)

        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            os_log("Failed to get InputMethodConnectionName from Info.plist", log: AppDelegate.log, type: .error)
            return
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            os_log("Failed to get bundle identifier", log: AppDelegate.log, type: .error)
            return
        }

        os_log("Initializing IMKServer with connection: %{public}@, bundle: %{public}@",
               log: AppDelegate.log, type: .info, connectionName, bundleIdentifier)

        server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)

        candidatesWindow = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )

        os_log("EnputPlus initialized successfully", log: AppDelegate.log, type: .info)
    }

    func applicationWillTerminate(_ notification: Notification) {
        os_log("EnputPlus terminating", log: AppDelegate.log, type: .info)
    }
}

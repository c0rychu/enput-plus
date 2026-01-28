import Cocoa
import InputMethodKit
import os.log

// MARK: - AppDelegate

/// Application delegate responsible for IMKServer and candidates window lifecycle.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private(set) var server: IMKServer?
    private(set) var candidatesWindow: IMKCandidates?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        os_log("Application launching", log: Log.app, type: .info)
        initializeInputMethod()
    }

    func applicationWillTerminate(_ notification: Notification) {
        os_log("Application terminating", log: Log.app, type: .info)
    }

    // MARK: - Private

    private func initializeInputMethod() {
        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            reportFatalError("Missing InputMethodConnectionName in Info.plist")
            return
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            reportFatalError("Missing bundle identifier")
            return
        }

        os_log("Initializing IMKServer: connection=%{public}@, bundle=%{public}@",
               log: Log.app, type: .info, connectionName, bundleIdentifier)

        guard let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier) else {
            reportFatalError("IMKServer initialization failed")
            return
        }

        self.server = server
        os_log("IMKServer initialized", log: Log.app, type: .info)

        initializeCandidatesWindow(server: server)
        os_log("Input method ready", log: Log.app, type: .info)
    }

    private func initializeCandidatesWindow(server: IMKServer) {
        candidatesWindow = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )

        if candidatesWindow == nil {
            os_log("IMKCandidates unavailable - suggestions will not display",
                   log: Log.app, type: .error)
        }
    }

    private func reportFatalError(_ message: String) {
        os_log("FATAL: %{public}@", log: Log.app, type: .fault, message)

        DistributedNotificationCenter.default().post(
            name: .enputPlusInitializationFailed,
            object: nil,
            userInfo: ["error": message]
        )
    }
}

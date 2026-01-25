import Foundation
import os.log

// MARK: - Logging Infrastructure

/// Centralized logging using Apple's unified logging system.
///
/// Usage:
/// ```swift
/// os_log("Message", log: Log.inputController, type: .debug)
/// ```
///
/// Filter in Console.app:
/// ```
/// subsystem:com.enputplus.inputmethod.EnputPlus
/// category:InputController
/// ```
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? Constants.App.bundleIdentifier

    /// Logs for application lifecycle events.
    static let app = OSLog(subsystem: subsystem, category: "App")

    /// Logs for input controller events.
    static let inputController = OSLog(subsystem: subsystem, category: "InputController")

    /// Logs for spelling engine operations.
    static let spelling = OSLog(subsystem: subsystem, category: "Spelling")
}

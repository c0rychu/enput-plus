import Foundation
import os.log

/// Manages user preferences for EnputPlus using UserDefaults.
enum Settings {

    // MARK: - Keys

    private enum Keys {
        static let autoShowSuggestions = "autoShowSuggestions"
    }

    // MARK: - Defaults

    private enum Defaults {
        static let autoShowSuggestions = true
    }

    // MARK: - Properties

    /// When true, suggestions appear automatically as user types.
    /// When false, suggestions only appear on Down arrow key press.
    static var autoShowSuggestions: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.autoShowSuggestions)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.autoShowSuggestions)
            os_log("autoShowSuggestions set to %{public}@",
                   log: Log.settings, type: .info, newValue ? "true" : "false")
        }
    }

    // MARK: - Registration

    /// Registers default values for all settings.
    /// Call this early in app lifecycle (in AppDelegate).
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.autoShowSuggestions: Defaults.autoShowSuggestions
        ])
        os_log("Settings defaults registered", log: Log.settings, type: .debug)
    }
}

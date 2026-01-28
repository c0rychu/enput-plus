import Cocoa

/// Preferences window for EnputPlus settings
final class PreferencesWindow: NSWindow {

    static let shared = PreferencesWindow()

    private var autoShowCheckbox: NSButton?

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "EnputPlus Preferences"
        self.center()
        self.isReleasedWhenClosed = false
        self.level = .floating

        setupContent()
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 260))

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 20, y: 180, width: 64, height: 64))
        iconView.image = NSApp.applicationIconImage
        contentView.addSubview(iconView)

        // App name
        let nameLabel = NSTextField(labelWithString: "EnputPlus")
        nameLabel.frame = NSRect(x: 100, y: 215, width: 240, height: 24)
        nameLabel.font = .boldSystemFont(ofSize: 18)
        contentView.addSubview(nameLabel)

        // Version
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.frame = NSRect(x: 100, y: 190, width: 240, height: 20)
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        contentView.addSubview(versionLabel)

        // Description
        let descLabel = NSTextField(labelWithString: "English Input Method with spelling suggestions")
        descLabel.frame = NSRect(x: 100, y: 165, width: 240, height: 20)
        descLabel.font = .systemFont(ofSize: 11)
        descLabel.textColor = .secondaryLabelColor
        contentView.addSubview(descLabel)

        // Separator between About and Settings
        let aboutSeparator = NSBox(frame: NSRect(x: 20, y: 150, width: 320, height: 1))
        aboutSeparator.boxType = .separator
        contentView.addSubview(aboutSeparator)

        // Settings section
        let settingsLabel = NSTextField(labelWithString: "Settings")
        settingsLabel.frame = NSRect(x: 20, y: 122, width: 320, height: 20)
        settingsLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        settingsLabel.textColor = .secondaryLabelColor
        contentView.addSubview(settingsLabel)

        let autoShowCheckbox = NSButton(checkboxWithTitle: "Auto-show suggestions while typing",
                                        target: self, action: #selector(autoShowChanged(_:)))
        autoShowCheckbox.frame = NSRect(x: 20, y: 95, width: 320, height: 22)
        autoShowCheckbox.state = Settings.autoShowSuggestions ? .on : .off
        contentView.addSubview(autoShowCheckbox)
        self.autoShowCheckbox = autoShowCheckbox

        // Separator before footer
        let footerSeparator = NSBox(frame: NSRect(x: 20, y: 80, width: 320, height: 1))
        footerSeparator.boxType = .separator
        contentView.addSubview(footerSeparator)

        // Copyright
        let copyright = Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
        let copyrightLabel = NSTextField(labelWithString: copyright)
        copyrightLabel.frame = NSRect(x: 20, y: 50, width: 320, height: 20)
        copyrightLabel.font = .systemFont(ofSize: 10)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        contentView.addSubview(copyrightLabel)

        // GitHub link
        let linkButton = NSButton(frame: NSRect(x: 100, y: 12, width: 160, height: 30))
        linkButton.title = "View on GitHub"
        linkButton.bezelStyle = .rounded
        linkButton.target = self
        linkButton.action = #selector(openGitHub)
        contentView.addSubview(linkButton)

        self.contentView = contentView
    }

    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/c0rychu/enput-plus") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func autoShowChanged(_ sender: NSButton) {
        Settings.autoShowSuggestions = (sender.state == .on)
    }

    func showWindow() {
        autoShowCheckbox?.state = Settings.autoShowSuggestions ? .on : .off
        self.center()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

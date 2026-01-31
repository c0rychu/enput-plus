<img src="appicon-64x64@2x.png" width="64">

# EnputPlus

A macOS input method that helps you type English with confidence. Get real-time spelling suggestions and word completions as you type — perfect for non-native English speakers or anyone who wants fewer typos.

<img src="EnputPlus-demo.gif" width="400">

## What It Does

- **Spelling suggestions** — See corrections for misspelled words instantly
- **Word completions** — Start typing and get suggestions to complete your words
- **Works everywhere** — Functions in any app where you can type (browsers, editors, chat apps, Terminal, etc.)
- **Keyboard-friendly** — Navigate suggestions with arrow keys, Tab, or number keys
- **Completely offline** — Uses macOS's built-in spell checker. No data leaves your Mac.
- **Not a grammar checker** — Focuses on spelling and word completion (unlike Grammarly)

## Installation

### Download & Install

1. Go to the [Releases page](https://github.com/c0rychu/enput-plus/releases)
2. Download the latest `.pkg` installer (currently, only supports Apple Silicon Macs, for Intel support please build from source)
3. Open the downloaded file and follow the installation steps:
   - **"Install for me only"** — Installs to `~/Library/Input Methods/` (no admin password needed)
   - **"Install for all users"** — Installs to `/Library/Input Methods/` (requires admin password)
4. **Log out and log back in** (required for macOS to recognize the new input method)

### Enable EnputPlus

1. Open **System Settings** → **Keyboard** → **Input Sources** (or search "Input Sources" in System Settings)
2. Click **Edit...** next to "Input Sources"
3. Click the **+** button at the bottom left
4. Find **EnputPlus** under **English** and click **Add**
5. Switch to EnputPlus using the input menu in your menu bar (flag icon)

## How to Use

Just type normally. EnputPlus shows suggestions in a small popup as you type.

| Key | Action |
|-----|--------|
| **↑ / ↓** | Navigate through suggestions |
| **1-9** | Select a suggestion by number |
| **Tab** | Select the highlighted suggestion |
| **Return** | Confirm your text |
| **Escape** | Keep what you typed (ignore suggestions) |
| **← / →** | Move cursor within input buffer |
| **Backspace** | Delete characters |

### Settings

Click on the input menu (flag icon in menu bar) while EnputPlus is active to access settings:

- **Auto-show Suggestions** — Toggle whether suggestions appear automatically as you type, or only when you press the **down arrow** key

### Tips

- **Switching input methods**: Use `Ctrl + Space` (or `Cmd + Space` on older macOS) to quickly toggle between EnputPlus and the standard English input. You can customize this shortcut in **System Settings** → **Keyboard** → **Keyboard Shortcuts**.
- **Great for commit messages**: EnputPlus works in Terminal, making it useful for typing git commit messages without typos.

## Requirements

- macOS 14.0 (Sonoma) or later

---

## For Developers

<details>
<summary>Building from Source</summary>

### Prerequisites

- Xcode 15.0 or later

### Build & Install

```bash
git clone https://github.com/c0rychu/enput-plus.git
cd enput-plus
./Scripts/install.sh
```

Or open `EnputPlus.xcodeproj` in Xcode and build (Cmd+B).

</details>

<details>
<summary>Creating a PKG Installer</summary>

```bash
./Scripts/build-pkg.sh
```

Requires:
- Developer ID Application certificate
- Developer ID Installer certificate
- Notarization profile in keychain (`xcrun notarytool store-credentials`)

</details>

<details>
<summary>Debug Logging</summary>

```bash
log stream --predicate 'subsystem == "com.enputplus.inputmethod.EnputPlus"'
```

</details>

<details>
<summary>Project Structure</summary>

```
EnputPlus/
├── EnputPlus.xcodeproj/
├── EnputPlus/
│   ├── AppDelegate.swift              # IMKServer initialization
│   ├── EnputPlusInputController.swift # Input handling
│   ├── SpellingSuggestionEngine.swift # Spell checking
│   └── ...
└── Scripts/
    ├── install.sh                     # Build & install script
    └── build-pkg.sh                   # PKG installer builder
```

</details>

## License

MIT License

## Acknowledgments

- [macOS_IMKitSample_2021](https://github.com/ensan-hcl/macOS_IMKitSample_2021) - Reference implementation
- [azooKey-Desktop](https://github.com/azooKey/azooKey-Desktop) - Japanese IME reference

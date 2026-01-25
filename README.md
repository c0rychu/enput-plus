# EnputPlus

Version: 0.1.0-alpha

A macOS input method designed to help non-native English speakers type with confidence by providing real-time spelling suggestions via an inline popup.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building)

## Features

- Real-time spelling suggestions as you type
- Corrections for misspelled words
- Word completions for partial words
- Inline candidates window (IMKCandidates)
- Keyboard navigation (arrow keys, number keys 1-9, Tab)
- Uses macOS built-in spell checker (NSSpellChecker)

## Building

### Prerequisites

1. Install Xcode from the Mac App Store
2. Open Xcode and install additional components if prompted

### Build & Install

```bash
# Clone the repository
git clone https://github.com/yourusername/enput-plus.git
cd enput-plus

# Build and install (Debug configuration)
./Scripts/install.sh
```

Or open `EnputPlus.xcodeproj` in Xcode and build (Cmd+B).

### Enable Input Method

1. Log out and log back in after installation
2. Open **System Settings** → **Keyboard** → **Input Sources**
3. Click the **+** button
4. Find **EnputPlus** under **English**
5. Add it and switch to EnputPlus

## Usage

- **Type normally** - suggestions appear for partial words and misspellings
- **Up/Down** - navigate through suggestions (consumed while composing)
- **Left/Right** - move cursor within the composition
- **Number keys (1-9)** - select a suggestion when suggestions are visible
- **Tab** - select the first suggestion
- **Return** - commit the buffer (or confirm selection after navigating suggestions)
- **Space** - insert a literal space and continue composing
- **Escape** - commit the buffer as typed
- **Backspace/Delete** - delete characters within the buffer

Notes:
- Word boundaries for suggestions use space and `/` as separators.

## Debug Logging

View logs in Console.app or via terminal:

```bash
log stream --predicate 'subsystem == "com.enputplus.inputmethod.EnputPlus"'
```

## Distribution

To create a distributable DMG:

```bash
./Scripts/build-dmg.sh
```

For notarization (requires Apple Developer account), see the script output for instructions.

## Project Structure

```
EnputPlus/
├── EnputPlus.xcodeproj/      # Xcode project
├── EnputPlus/
│   ├── AppDelegate.swift              # IMKServer initialization
│   ├── EnputPlusInputController.swift # Input handling
│   ├── SpellingSuggestionEngine.swift # Spell checking
│   ├── Info.plist                     # IMKit configuration
│   ├── EnputPlus.entitlements         # Sandbox settings
│   └── Assets.xcassets/               # App icons
└── Scripts/
    ├── install.sh                     # Build & install script
    └── build-dmg.sh                   # DMG creation script
```

## License

MIT License

## Acknowledgments

- [macOS_IMKitSample_2021](https://github.com/ensan-hcl/macOS_IMKitSample_2021) - Reference implementation
- [azooKey-Desktop](https://github.com/azooKey/azooKey-Desktop) - Japanese IME reference

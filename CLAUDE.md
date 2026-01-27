# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EnputPlus is a macOS Input Method (IME) that provides real-time spelling suggestions as you type. It uses Apple's InputMethodKit framework and NSSpellChecker for spell-checking and word completions.

**Requirements:** macOS 14.0+, Xcode 15.0+

## Build Commands

```bash
# Build and install to ~/Library/Input Methods/
./Scripts/install.sh

# Create signed and notarized PKG installer (Release build)
./Scripts/build-pkg.sh
```

After installation, enable the input method in System Preferences → Keyboard → Input Sources.

## Architecture

The app follows InputMethodKit's architecture with three main components:

1. **AppDelegate** - Initializes `IMKServer` (the input method server) and `IMKCandidates` (suggestion window)

2. **EnputPlusInputController** - Core keyboard event handler that:
   - Manages composition state (buffer, cursor position, suggestions)
   - Processes all keystrokes (characters, arrows, modifiers, etc.)
   - Detects word boundaries using separators (space, `/`)
   - Coordinates between user input and suggestion display

3. **SpellingSuggestionEngine** - Wraps NSSpellChecker to provide:
   - Spelling corrections for misspelled words
   - Word completions for partial inputs
   - Maximum 7 suggestions per query

**Data flow:** User keystroke → IMKServer → EnputPlusInputController → SpellingSuggestionEngine → IMKCandidates window → User selection → Committed text

## Key Implementation Details

- Composition state is tracked in a nested `CompositionState` struct within the input controller
- Word extraction uses `compositionBufferCursorPosition` to find the current word being typed
- Carbon key codes are used for special key handling (defined in `Constants.swift`)
- Logging uses Apple's unified logging system with subsystem 

## Code Quality

- Review and maintain the codebase as if you are a 20yr+ experienced software engineer proficient in macOS related development. Make code concise, maintainable, clean, and easy to read. Check the latest documentation and use up-to-date syntax and way to write the program. Always think big and make the overall architecture good for extendibility. Review for consistency and make sure using good naming for components.

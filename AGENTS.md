# Repository Guidelines

## Project Structure & Module Organization
- `EnputPlus/`: main macOS Input Method source.
- `EnputPlus/AppDelegate.swift`: bootstraps `IMKServer` and candidates UI.
- `EnputPlus/EnputPlusInputController.swift`: core keystroke handling and composition state.
- `EnputPlus/SpellingSuggestionEngine.swift`: `NSSpellChecker`-based suggestions/completions.
- `EnputPlus/Assets.xcassets` and `EnputPlus/appicon.icon`: app and input-method assets.
- `Scripts/install.sh`: local Debug build + install into `~/Library/Input Methods`.
- `Scripts/build-pkg.sh` and `Scripts/pkg-scripts/postinstall`: signed/notarized PKG pipeline.

## Build, Test, and Development Commands
- `./Scripts/install.sh`: clean, build (`Debug`), and install locally.
- `./Scripts/build-pkg.sh`: build `Release`, sign, package, notarize, and staple installer.
- `xcodebuild -project EnputPlus.xcodeproj -scheme EnputPlus -configuration Debug build`: CI-friendly build.
- `log stream --predicate 'subsystem == "com.enputplus.inputmethod.EnputPlus"'`: runtime debugging.

## Coding Style & Naming Conventions
- Language: Swift (Xcode 15+, macOS 14+).
- Indentation: 4 spaces; keep lines readable and avoid deeply nested conditionals.
- Prefer `final` for concrete types and tight access control (`private`/`fileprivate`).
- Naming: `UpperCamelCase` for types, `lowerCamelCase` for methods/properties, descriptive enum/constant names in `Constants.swift`.
- Keep input-event logic deterministic; isolate state transitions in small helper methods.

## Testing Guidelines
- There is currently no dedicated XCTest target in this repo.
- Minimum validation for each change:
  - Build succeeds via `./Scripts/install.sh` or equivalent `xcodebuild` command.
  - Manual smoke test in a text field: typing, suggestion navigation (`↑/↓`, `Tab`, `1-9`), commit (`Return`), cancel (`Esc`), cursor movement, and backspace behavior.
- If adding tests later, place them under `EnputPlusTests/` and name files `*Tests.swift`.

## Commit & Pull Request Guidelines
- Follow Conventional Commit style seen in history: `feat:`, `fix:`, `refactor:`, `chore:`.
- Keep commits focused and explain behavioral changes, not just file edits.
- PRs should include:
  - concise summary and rationale,
  - linked issue (if available),
  - manual test notes,
  - UI proof (GIF/screenshot) when candidate-panel behavior changes.

## Security & Release Notes
- Never commit signing identities, keychain secrets, or notarization credentials.
- Keep certificate/profile names in local environment only; treat release scripts as operational tooling.

## Code Quality
- Review and maintain the codebase as if you are a 20yr+ experienced software engineer proficient in macOS related development. Make code concise, maintainable, clean, and easy to read. Check the latest documentation and use up-to-date syntax and way to write the program. Always think big and make the overall architecture good for extendibility. Review for consistency and make sure using good naming for components.

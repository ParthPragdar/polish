# Changelog

Notable changes to Polish are listed here. Versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- Default shortcuts are now ⌃⌥G (Control–Option–G) for Correct grammar and ⌃⌥P (Control–Option–P) for Refine prompt. Shortcuts you already recorded are kept; use Restore defaults in Settings to switch.

### Fixed

- Replacing text in web editors (Chrome, Electron apps) no longer fails with "The selected text no longer matches the original" when only spacing or paragraph breaks are reported differently; a whole field is re-selected with Select All when needed.
- In the Changes view, a replacement no longer runs into the struck-out word it replaces.
- The release workflow updates an existing release instead of failing when a tag is pushed again.

### Added

- README banner and screenshots.

## [0.1.0] - 2026-10-08

First public release.

### Added

- Correct grammar (⌥⌘G) and refine AI prompts (⌥⌘P) in the app you are typing in, using the Gemini Live API with your own API key.
- Review-before-applying mode with an editable result, or automatic replacement.
- Rewrites the selection, or the whole focused field when nothing is selected.
- Safe replacement: text is only pasted back if the original app, field, and draft are unchanged; the clipboard is restored afterwards.
- Local history of the latest 80 rewrites, with recent items in the menu-bar menu.
- Configurable global shortcuts and launch at login.
- Setup checklist in Settings, a labeled progress pill, and a brief “Replaced · ⌘Z to undo” confirmation.
- If a result can't be pasted safely, it is copied for you to paste with ⌘V; apps that don't expose their text can still rewrite a selection and copy the result.
- Detects an Accessibility permission left over from an earlier build and explains how to renew it.
- Dark interface built around an Activity dashboard (rewrites by weekday and by app, words polished), a History calendar with search, and one Settings screen.
- A Changes view that highlights exactly which words a rewrite changed, in the review popup and in History.
- Universal (Apple Silicon and Intel) release builds for macOS 14 or later.

[Unreleased]: https://github.com/ParthPragdar/polish/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ParthPragdar/polish/releases/tag/v0.1.0

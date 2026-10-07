# Contributing to Polish

Thank you for helping improve Polish. Small, focused changes are easiest to review. Follow the [community guidelines](CODE_OF_CONDUCT.md) in issues and pull requests.

## Getting started

Follow the [README](README.md) to install the macOS toolchain, build, test, and package the app. No API key is needed for unit tests or UI previews. A live rewrite requires your own key and an Accessibility grant for the packaged app.

```sh
swift build
swift test
./scripts/build-app.sh
```

Fork the repository, create a descriptive branch, and keep unrelated changes separate. Open `Package.swift` in Xcode for debugging. Keep build output, IDE state, API keys, signing certificates, and real rewrite history out of commits.

## Reporting bugs and proposing features

Search existing issues first. For a bug, include macOS and Swift/Xcode versions, the Polish version or commit, destination app/version, apply mode, reproducible steps, and expected/actual behavior. Reproduce using disposable text from `Tests/Fixtures/editor.html` or a short synthetic example. Never post API keys, actual history files, confidential drafts, or screenshots of account settings. Report vulnerabilities through [SECURITY.md](SECURITY.md).

For a larger feature or architectural change, discuss the problem in an issue before investing in implementation. Compatibility reports should distinguish a reproducible result from an assumption about an entire app.

## Code and validation

- Use four spaces in Swift and descriptive names; follow surrounding SwiftUI/AppKit conventions.
- Keep testable validation, history, and geometry logic in `PolishCore`; keep native UI and system integration in `Polish`.
- Explain non-obvious Accessibility, clipboard, concurrency, and protocol constraints in comments. Avoid comments that repeat the code.
- Preserve draft/focus checks, secure-field exclusion, cancellation, clipboard restoration, and structured-output validation.
- Add meaningful tests when logic changes. Documentation-only changes do not need artificial tests.
- Run `swift test` and package the app for source/build changes. Use the relevant [manual checks](docs/RELEASE_CHECKLIST.md#manual-app-checks) when UI, Accessibility, clipboard, or API behavior changes.
- Document configuration or behavioral changes, including privacy effects.

CI uses macOS runners without API or signing secrets. Never change a pull-request workflow to use `pull_request_target` to execute contributed code with privileges. GitHub actions are pinned to commit SHAs; review Dependabot updates before merging them.

## Pull requests

Describe the problem, the resulting behavior, and validation performed. Include redacted/synthetic screenshots for UI changes if useful. State any checks you could not run. Review your complete diff and file list before submitting:

```sh
git diff --check
git status --short
git diff --cached
```

By submitting a contribution, you agree to license it under the project's [MIT License](LICENSE). Retain attribution for third-party material and explain any new dependency or asset license.

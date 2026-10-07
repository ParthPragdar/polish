# Polish for macOS

Polish is a native menu-bar app that corrects grammar and refines AI prompts in the app where you are already typing. Select a passage, press a shortcut, and review the rewrite or apply it automatically.

Built with SwiftUI and AppKit for **macOS 14 or later**, using the Gemini Live API. No third-party Swift dependencies, backend server, or microphone access are required. The current version is **0.1.0**; compatibility with individual editors is best effort.

## Features

- Correct spelling, grammar, punctuation, and phrasing while preserving the writer's voice.
- Turn a rough request into a clearer AI prompt.
- Rewrite a selection, or the whole focused field when it can be read safely.
- Review and edit results before applying, or enable automatic replacement.
- Configure global keyboard shortcuts.
- Position loading and result panels near the editor across multiple displays.
- Copy results and browse the latest 80 completed rewrites locally.
- Cancel requests and reject replacements when the original field or draft changes.

Polish pastes through the destination app's normal paste action. It never presses Return or submits a message, and the destination app's usual Undo remains available. AI output can still change meaning: review important text before using it.

## Requirements

| Requirement | Details |
| --- | --- |
| Operating system | macOS 14 Sonoma or newer; Windows and Linux are unsupported |
| Toolchain | Swift 5.10 or newer; Xcode 15.3 or newer, or compatible Xcode Command Line Tools |
| Hardware | Apple Silicon or Intel Mac; local builds target the current Mac's architecture |
| API access | Your own Google AI Studio API key with access to a compatible Gemini Live model |
| Permission | Accessibility access for the packaged `Polish.app` |
| Network | HTTPS/WSS access to Google's Gemini API; API usage charges and quotas may apply |

Building, running unit tests, and previewing the UI do not require an API key or Accessibility access. Rewriting text requires both.

## Installation from source

There is no prebuilt download assumed by this guide. Install the Xcode tools first if needed:

```sh
xcode-select --install
swift --version
xcode-select -p
```

If you use full Xcode, complete its first-launch setup before building. Download this repository using GitHub's **Code → Download ZIP**, or copy its HTTPS clone URL from **Code** and run:

```sh
git clone https://github.com/ParthPragdar/polish.git polish
cd polish
swift build
swift test
./scripts/build-app.sh
open dist/Polish.app
```

For a ZIP download, open Terminal in the extracted project folder and start at `swift build`.

The script compiles a release executable, generates the app icon, assembles `dist/Polish.app`, and ad-hoc signs and verifies the bundle for local use. Build products are ignored by Git. For regular use, quit Polish, move the bundle to a stable location such as Applications, and reopen it there before granting Accessibility access. A local build is not a notarized download for other users; see the [release checklist](docs/RELEASE_CHECKLIST.md) for binary distribution.

## Setup

1. Open **Settings → Gemini Live** from Polish's menu-bar menu.
2. Create your own key in [Google AI Studio](https://aistudio.google.com/apikey), paste it into **Gemini API key**, and click **Save key**. The key is stored in macOS Keychain.
3. Confirm the **Live model** is available to your Google project. The default is `gemini-3.8-live`; enter a bare model ID without `models/`. Check Google's [model catalog](https://ai.google.dev/gemini-api/docs/models) and [Live API guide](https://ai.google.dev/gemini-api/docs/live-api) if access or availability changes.
4. In **General**, click **Open Accessibility Settings**. Enable Polish under **System Settings → Privacy & Security → Accessibility**, adding the packaged app if needed. Quit and reopen Polish if macOS requests it.
5. Keep **Review before applying**, the default, or choose **Apply automatically**.

### Configuration

| Setting | How it is configured | Storage |
| --- | --- | --- |
| Gemini API key | Settings → Gemini Live → Save key / Remove saved key | Keychain service `app.polish.mac`, account `gemini-api-key` |
| Live model | Settings → Gemini Live | UserDefaults; default `gemini-3.8-live` |
| Apply preference | Settings → General | UserDefaults; review is the default |
| Shortcuts | Settings → Shortcuts | UserDefaults |
| Build directory | Optional `BUILD_PATH` environment variable for the packaging script | Defaults to this checkout's `.build/` |
| Signing identity | Optional `SIGN_IDENTITY` environment variable for the packaging script | Defaults to `-` (local ad-hoc signing) |

The app does **not** read `.env` files or environment variables for its API key/model. No secret-bearing configuration file belongs in the repository. Enter keys only through Settings; do not embed a shared key in a source build or release. A harmless build configuration example is:

```sh
BUILD_PATH="$PWD/.build" SIGN_IDENTITY="-" ./scripts/build-app.sh
```

## Usage

Write in another app, then select the text you want to rewrite. If nothing is selected, Polish uses the current field when it can read and verify its contents.

| Default shortcut | Action |
| --- | --- |
| Option–Command–G (`⌥⌘G`) | Correct grammar |
| Option–Command–P (`⌥⌘P`) | Refine prompt |

In review mode, edit the returned text if needed and choose **Apply rewrite** or **Copy**. Apply is the default Return/Enter action when the preview opens; clicking inside the editor allows further editing. In automatic mode, a successful rewrite replaces the original directly. If replacement cannot be verified, the result stays in History and a notice offers Copy or View in History.

Open **History** to inspect originals and results or copy a result. **Clear history** removes saved entries. Closing Settings keeps Polish running in the menu bar; choose **Quit Polish** to exit.

### Preview without an API key

Use **General → Preview result popup** or **Preview loading** to inspect the UI. A result preview is also available from Terminal:

```sh
dist/Polish.app/Contents/MacOS/Polish --demo
```

Apply in this demo only dismisses the sample result. It does not change another app or save history. Screenshots are not included yet; this preview provides synthetic text suitable for capturing them without exposing real drafts or API settings.

## Privacy and safety

Each rewrite sends the requested selection or field contents to Google over a Live WebSocket connection. The app sends no screenshots or microphone audio and does not implement analytics. Password fields identified as secure by Accessibility are excluded; ordinary text fields can still contain secrets, so choose what you rewrite carefully.

The API key is sent in a request header, stored in Keychain, and is not intentionally written to logs or history. Temporary copy/paste operations restore the prior clipboard if it has not changed; explicit **Copy** leaves the result on the clipboard. Clipboard managers may retain copied text.

The latest 80 completed rewrites include the **original, result, source application, and timestamp** in local plaintext at `~/Library/Application Support/Polish/history.json`. Owner-only file permissions do not encrypt this data. Completed rewrites are saved even if you dismiss review or automatic application fails. Polish does not sync history, but your backups may contain it. See [privacy and storage details](docs/PRIVACY.md).

## Compatibility and troubleshooting

- **Accessibility still says Required:** after a rebuild, remove the stale Polish entry from Accessibility Settings, add the newly built app, and reopen it. Ad-hoc signatures can change between builds. Keychain may also request access approval for a rebuilt executable.
- **No editor detected:** click inside the draft and select text explicitly. Chromium/Electron accessibility trees can take time to appear. Custom canvases, terminals, remote desktops, and individual web editors may be unsupported.
- **Draft or field changed:** return to the original field and retry, or copy the result. Automatic mode does not switch back to another app to replace text.
- **Gemini request failed:** check connectivity, saved key, model access, project quota, and billing. Requests have a 60-second deadline. A response without the required structured rewrite is rejected.
- **Shortcut conflict:** choose two distinct shortcuts in Settings. Recording requires Command or Control with a supported character key; Escape cancels recording.
- **Build fails:** confirm the selected toolchain supports Swift 5.10+ and macOS 14+. The project cannot build against Linux or Windows SDKs.

Inputs are limited to 12,000 UTF-16 code units. Rich-text formatting and Undo behavior depend on the destination editor. Clipboard restoration waits 700 ms; unusually slow paste handlers may need adjustment. Cross-app behavior and live API access require manual verification.

## Development and project structure

Open `Package.swift` in Xcode, or use the build commands above. `PolishCoreTests` cover response validation, UTF-16 selection bounds, history persistence, focus retries, cancellation, delivery modes, and popup geometry without contacting Google or manipulating another app. CI builds, tests, packages, and verifies the app on macOS; it does not run live API or Accessibility scenarios.

```text
Package.swift                 Swift package; no external dependencies
Sources/
  Polish/                     Menu bar, settings, UI, Keychain, shortcuts, Accessibility
  PolishCore/                 Gemini Live client and testable rewrite/history/geometry logic
Tests/
  PolishCoreTests/            Unit tests
  Fixtures/editor.html        Disposable browser editor for manual testing
Resources/Info.plist          App metadata and minimum macOS version
scripts/
  build-app.sh                Release app packaging and local signing
  make-icon.swift             Procedural icon generation
.github/                      CI, issue forms, PR template, action updates
docs/                         Architecture, privacy, and release guidance
```

See [architecture](docs/ARCHITECTURE.md) for the Live protocol and replacement flow, [CONTRIBUTING.md](CONTRIBUTING.md) for development conventions, and [SECURITY.md](SECURITY.md) for private vulnerability reporting. Before distributing a version, complete the [release checklist](docs/RELEASE_CHECKLIST.md).

## Contributing and license

Bug reports, documentation improvements, compatibility fixes, and focused pull requests are welcome. Use synthetic text in reports and screenshots, and follow the [contribution guide](CONTRIBUTING.md) and [community guidelines](CODE_OF_CONDUCT.md).

Developed by **Parth Pragdar**. Licensed under the [MIT License](LICENSE). Gemini API access is governed separately by Google's terms; this project is not affiliated with Google.

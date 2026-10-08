# Polish

**Fix grammar and sharpen AI prompts in any Mac app, with one shortcut.**

[![macOS CI](https://github.com/ParthPragdar/polish/actions/workflows/ci.yml/badge.svg)](https://github.com/ParthPragdar/polish/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/ParthPragdar/polish?sort=semver)](https://github.com/ParthPragdar/polish/releases/latest)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Polish is a small, native menu-bar app. Select text in Mail, Slack, Chrome, an AI chat, or almost any editor, press a shortcut, and Polish rewrites it in place using Google's Gemini Live API with your own API key.

- **⌥⌘G — Correct grammar.** Fixes spelling, grammar, and punctuation while keeping your tone, language, and formatting.
- **⌥⌘P — Refine prompt.** Turns a rough request into a clear, well-structured prompt for an AI assistant, without inventing details.
- **Review or auto-apply.** Edit the result in a small popup before applying, or let Polish replace the text directly.
- **Stays out of the way.** No account, no backend server, no analytics, no microphone. It never presses Return or sends a message for you, and the app's normal Undo still works.
- **Local history** of your last 80 rewrites, plus configurable shortcuts and launch at login.

## Install

1. Download `Polish-<version>.zip` from the [latest release](https://github.com/ParthPragdar/polish/releases/latest) and unzip it.
2. Move **Polish.app** to your **Applications** folder.
3. Open it. Polish isn't notarized by Apple yet, so macOS blocks the first launch:
   - **macOS 15 or later:** click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to Polish.
   - **macOS 14:** Control-click Polish.app, choose **Open**, then confirm **Open**.

Release builds are universal and run on Apple Silicon and Intel Macs. If you prefer, [build it from source](#build-from-source).

## Set up

Polish opens its Settings window until setup is complete. After that it lives in the menu bar (the **text-with-checkmark** icon).

1. **Add a Gemini API key.** Create one in [Google AI Studio](https://aistudio.google.com/apikey), then paste it in **Settings → Gemini Live** and click **Save key**. The key is stored in your macOS Keychain. Gemini API usage may be billed by Google depending on your plan.
2. **Allow Accessibility access.** In **Settings → General**, click **Open Accessibility Settings** and turn on Polish. This lets it read the text you select and paste the rewrite back. Reopen Polish if macOS asks.
3. **Optional:** turn on **Launch at login**, choose **Review before applying** or **Apply automatically**, and change the shortcuts in **Settings → Shortcuts**.

The default model is `gemini-3.8-live`. You can change it in **Settings → Gemini Live** to any [Live API model](https://ai.google.dev/gemini-api/docs/models) your key can use; enter the bare ID without `models/`.

## Use

1. Select text in any app. If nothing is selected, Polish uses the whole focused text field when it can read it.
2. Press **⌥⌘G** to correct grammar or **⌥⌘P** to refine a prompt. A small indicator appears while Gemini works; use its cancel button to stop.
3. In review mode, edit the result if you like, then press **Return** to apply or click **Copy**. In automatic mode the text is replaced directly.

Recent rewrites are in the menu-bar menu, and the full list is in **Settings → History**.

Polish only replaces text if the same app, field, and draft are still there; if you kept typing or switched windows, it keeps the result in History and offers to copy it instead. Inputs are limited to 12,000 characters. AI output can still change meaning, so review important text.

## Privacy

- Each rewrite sends only the selected or focused text, directly from your Mac to Google's Gemini API. No screenshots, audio, app names, or history are sent, and Polish has no analytics.
- Fields that macOS marks as password fields are never read. Other fields can still contain sensitive text, so choose what you rewrite.
- The API key is kept in Keychain. History (original text, result, app name, time) is stored unencrypted at `~/Library/Application Support/Polish/history.json` and can be cleared from **Settings → History**.

Details: [privacy and local storage](docs/PRIVACY.md). Google's handling of API requests is covered by the [Gemini API terms](https://ai.google.dev/gemini-api/terms).

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Accessibility shows **Required** after an update or rebuild | Remove Polish from System Settings → Privacy & Security → Accessibility, add the new copy, then reopen Polish. |
| "No editor detected" | Click inside the text field and select the text explicitly. Chrome and Electron apps can take a moment to expose text. Terminals, remote desktops, and canvas-based editors may not be supported. |
| Gemini request failed | Check your connection, saved key, model ID, quota, and billing in AI Studio. Requests time out after 60 seconds. |
| A shortcut does nothing | Another app may already use it. Record a different combination in Settings → Shortcuts. |
| Keychain asks for permission | Allow it. This can happen once after installing a new build. |

To try the UI without a key or permissions, use **Settings → General → Preview result popup**, or run `/Applications/Polish.app/Contents/MacOS/Polish --demo`.

## Build from source

Requires macOS 14 or later and Xcode 15.3+ (or the Xcode Command Line Tools with Swift 5.10+). There are no third-party dependencies.

```sh
git clone https://github.com/ParthPragdar/polish.git
cd polish
swift test
./scripts/build-app.sh
open dist/Polish.app
```

`build-app.sh` builds a release binary for your Mac's architecture, assembles `dist/Polish.app`, and signs it ad hoc for local use. Set `UNIVERSAL=1` for an Apple Silicon + Intel build (needs full Xcode), or `SIGN_IDENTITY` to sign with your own certificate.

See [architecture](docs/ARCHITECTURE.md) for how capture, the Gemini Live protocol, and safe replacement work, and [releasing](docs/RELEASING.md) for publishing a new version.

## Contributing

Bug reports, compatibility notes for specific apps, and focused pull requests are welcome. Please read the [contribution guide](CONTRIBUTING.md) and use synthetic text — never real drafts, history, or API keys — in issues and screenshots. Report security problems privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © 2026 Parth Pragdar. Polish is an independent project and is not affiliated with or endorsed by Google.

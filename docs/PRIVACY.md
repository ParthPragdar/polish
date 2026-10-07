# Privacy and local storage

## Data sent to Google

Invoking a rewrite sends the requested selection or field text, rewrite instructions, and protocol configuration directly to Google's Gemini Live API. An API key authenticates the request. Polish does not send the screen, source app name, saved history, or microphone input. It does not implement analytics or diagnostic payload logging.

Google's processing and retention are governed by its [Gemini API terms](https://ai.google.dev/gemini-api/terms) and the settings/terms applicable to your account. API use may incur charges. Polish's source-code license does not govern Google's service.

Only password fields identified as secure by Accessibility are excluded. Secrets or personal information in ordinary editors are still text and can be sent if you invoke a rewrite. Use disposable samples for testing and reporting problems.

## Storage on this Mac

| Data | Location and handling |
| --- | --- |
| API key | macOS Keychain generic password; service `app.polish.mac`, account `gemini-api-key`; accessible when unlocked, device-only accessibility policy |
| Model, apply preference, shortcuts | UserDefaults for the running app; packaged bundle identifier `app.polish.mac` |
| Completed rewrites | `~/Library/Application Support/Polish/history.json`; newest 80 entries, including original, result, mode, source app, timestamp, UUID |
| Clipboard | Temporarily used for capture verification and paste; explicit Copy keeps the result there |
| Build output | This checkout's `.build/` and `dist/`; local IDE state under `.swiftpm/` |

History is **unencrypted plaintext**. The application creates its storage directory with mode `0700`, writes atomically, and sets the history file to mode `0600`. These permissions restrict normal file access; they do not protect against software running as your user, administrator access, or backups. The application does not sync this file itself. Existing parent-directory permissions are not repaired automatically.

Completed rewrites are saved before delivery, including dismissed reviews and automatic replacement failures. Failed/cancelled requests do not create completed entries. If loading fails, the unreadable file is preserved until explicit clearing; if saving fails, session results remain in memory and History shows an error.

Clipboard restoration occurs only if its change count still matches, avoiding overwriting a later clipboard change. Clipboard managers or destination apps may independently retain copied/pasted text. Removing Polish does not remove data retained by those apps or Google.

## Removing stored data

1. Use **Settings → History → Clear history** and confirm. This saves an empty history list; it does not securely erase previous disk blocks or backups. Resolve any reported storage error before assuming clearing succeeded.
2. Use **Settings → Gemini Live → Remove saved key** to request deletion of the Keychain entry. You can also verify/remove that named entry in Keychain Access. This does not revoke the key at Google; revoke it in AI Studio if needed.
3. To remove local history outside the app, quit Polish first and remove `~/Library/Application Support/Polish/history.json` using Finder. Avoid copying it into the repository or an issue.
4. Preferences can be reset for a packaged app after quitting it with `defaults delete app.polish.mac`. This resets configuration and shortcuts but does not delete the Keychain key or history.

Never attach real history, Keychain exports, signing credentials, or API settings screenshots to public bug reports. See [SECURITY.md](../SECURITY.md) for private reporting.

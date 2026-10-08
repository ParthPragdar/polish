# Architecture

Polish is a macOS accessory app. `PolishApp` starts AppKit's event loop, `AppDelegate` owns the status menu, and `AppController` coordinates preferences, windows, rewrite tasks, and history. SwiftUI provides Settings, review, loading, and history views. The package uses only Apple frameworks.

## Source map

| File | Responsibility |
| --- | --- |
| `Sources/Polish/App.swift` | Lifecycle, menu, task state, result delivery, floating panels |
| `Sources/Polish/Settings.swift` | UserDefaults, Keychain, launch-at-login item, Carbon global hotkeys |
| `Sources/Polish/TextAccess.swift` | Accessibility capture, target validation, copy/paste, clipboard restoration |
| `Sources/Polish/Views.swift` | Settings, editable result popup, shortcut recorder |
| `Sources/Polish/HistoryView.swift` | History list, details, Copy, confirmed clearing |
| `Sources/Polish/LoadingIndicator.swift` | Cancellable progress UI with Reduce Motion support |
| `Sources/Polish/AutomaticApplyNotice.swift` | Nonactivating notice after automatic replacement fails |
| `Sources/Polish/DesignSystem.swift` | Shared colors, spacing, and button styles |
| `Sources/PolishCore/Rewrite.swift` | Rewrite instructions, Live client, response validation, UTF-16 text guards |
| `Sources/PolishCore/FocusLookup.swift` | Bounded focus retries and cancellation |
| `Sources/PolishCore/RewriteDelivery.swift` | Automatic versus review delivery policy |
| `Sources/PolishCore/RewriteHistory.swift` | Retention, atomic persistence, edited results, storage errors |
| `Sources/PolishCore/PopupPlacement.swift` | Coordinate conversion, anchor validation, display choice, panel bounds |

## Rewrite flow

1. Capture the foreground application at shortcut time.
2. Check Accessibility access and resolve an explicitly focused editable element. Chromium/Electron accessibility trees are requested and retried briefly. Abort if the app changes.
3. Reject secure fields and capture the selection or readable field. AX ranges use UTF-16. Clipboard copy is a fallback when the editor omits relevant attributes.
4. Show a nonactivating loading panel and send the requested text to Gemini.
5. Validate the structured rewrite and save the completed result to History.
6. Read the current apply preference. Review mode opens an editable panel; automatic mode attempts replacement directly.
7. Before pasting, verify the original app, field, unchanged draft, and restored selection. Use the host's normal paste action, then restore the previous clipboard only if it has not changed.

Errors and cancellations do not create completed history entries. A completed rewrite remains in history even when automatic application fails. Edited results update the same entry after Copy or successful Apply, preserving its original timestamp. Preview actions never record history or modify a host field.

## Gemini Live protocol

Each rewrite opens an independent `URLSession` ephemeral WebSocket connection to Google's public v1beta `BidiGenerateContent` endpoint. The API key is sent in the `x-goog-api-key` handshake header, outside the URL. The client sends setup, waits for `setupComplete`, and sends a user turn with `turnComplete: true`.

The app requests the `AUDIO` response modality and declares `submit_rewrite(text)`. The model must return exactly one call to that function, containing a nonblank rewrite of at most 50,000 UTF-16 code units. Polish acknowledges receipt and closes the session. Audio is discarded and transcriptions are never inserted. The function only returns text; it cannot run shell commands or other computer actions. There is no fallback to the standard `generateContent` API.

The client validates model IDs, caps incoming WebSocket messages at 4 MiB, checks cancellation, and closes requests after a 60-second deadline. Authentication, model availability, quota, and real output quality require live testing with a user-owned key.

Protocol references: [Live WebSocket API](https://ai.google.dev/api/live), [capabilities](https://ai.google.dev/gemini-api/docs/live-api/capabilities), and [function calling](https://ai.google.dev/gemini-api/docs/live-api/tools).

## Panel placement and system boundaries

Panels anchor to caret/selection bounds, then field bounds, then the source window. AX top-left coordinates are converted to AppKit global points using the primary display origin. Invalid/stale bounds are ignored; panels are constrained to a display's visible frame. Geometry is refreshed on completion to account for moved windows. When no usable geometry exists, the primary display is the fallback.

`PolishCore` isolates logic that can be tested without GUI permissions. Unit tests do not exercise native Accessibility, Carbon hotkeys, Keychain, real clipboard timing, or the remote API. Changes to those integrations need manual testing in supported destination editors.

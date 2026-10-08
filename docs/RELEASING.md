# Releasing Polish

Releases are built by the [Release workflow](../.github/workflows/release.yml) when a `v*` tag is pushed. It runs the tests, builds a universal (Apple Silicon + Intel) `Polish.app`, zips it with a SHA-256 checksum, and publishes a GitHub release using the matching section of [CHANGELOG.md](../CHANGELOG.md) as release notes.

## Steps

1. Run the [manual app checks](#manual-app-checks) on a local build (`./scripts/build-app.sh`).
2. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`.
3. Add a `## [x.y.z] - YYYY-MM-DD` section to `CHANGELOG.md` and its link at the bottom.
4. Commit, then tag and push. The tag must equal `v` + the Info.plist version, or the workflow stops:

   ```sh
   git tag -a v0.2.0 -m "Polish 0.2.0"
   git push origin main v0.2.0
   ```

5. Check the workflow run and the published release. Download the zip on another Mac, or another user account without your settings, and confirm first launch, Gatekeeper's **Open Anyway** step, Accessibility, and a real rewrite.

If a release build is wrong, delete the GitHub release and tag, fix the problem, and release a new patch version rather than replacing assets in place.

## Manual app checks

Unit tests cover response validation, history, focus retries, delivery modes, and panel geometry. They do not cover Accessibility, global shortcuts, Keychain, the clipboard, or the live API, so check these by hand with synthetic text in TextEdit, a browser editor (`Tests/Fixtures/editor.html`), and any Electron apps you want to call supported.

- [ ] Grammar and prompt rewrites with a real key preserve language, facts, formatting, and intent.
- [ ] Selected text and whole-field capture, Unicode and emoji, review, edited results, Copy, Apply, automatic mode, and host Undo.
- [ ] Apply never submits the destination message.
- [ ] Cancel while waiting; bad key, bad model, no network, and quota errors show useful messages.
- [ ] Typing during generation, switching fields or apps, and closing the source app all refuse unsafe replacement and keep the result in History.
- [ ] Clipboard is restored, and is not overwritten if it changed during the request.
- [ ] Password fields are refused (use disposable input).
- [ ] Shortcut conflicts, restored defaults, Accessibility denial and re-grant, and Keychain access after an update.
- [ ] Launch at login turns on and off, and a login launch stays in the menu bar without opening Settings.
- [ ] Multiple displays, moved windows, Reduce Motion, and keyboard confirmation in the popup.
- [ ] History reload, edited-result updates, clearing, and storage-error reporting.

## Signing and notarization

Release builds are signed ad hoc, so macOS asks users to approve the first launch, and Accessibility must be re-granted after each update. Signing with a Developer ID certificate and notarizing with Apple removes both problems. It requires an Apple Developer Program membership; follow Apple's [notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and add the signing steps to the Release workflow using encrypted repository secrets. Never commit certificates, private keys, or notarization credentials.

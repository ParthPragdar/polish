# Release checklist

Use this checklist for a first public repository and subsequent releases. Publishing source and distributing a notarized macOS binary are separate steps.

## Before making the repository public

- [ ] Confirm you have the right to publish the source and generated artwork under the MIT license and that the public author attribution is correct.
- [ ] Replace the example clone URL in the README with the actual GitHub owner/repository URL.
- [ ] Review every file selected for the initial commit, including hidden files. Exclude `.build/`, `.swiftpm/`, `dist/`, local IDE state, logs, secrets, certificates, and real history.
- [ ] Review all history that will be published. This source folder initially had no `.git` directory, so no prior commits were available for audit. If you import an existing Git repository, scan its complete history before changing visibility.
- [ ] Scan staged files and history with a maintained secret scanner, such as [Gitleaks](https://github.com/gitleaks/gitleaks). Revoke any exposed credential before removing it from files/history. Pattern scans alone cannot prove an absence of secrets.
- [ ] Build, test, and package a fresh checkout using only the README. Keep real keys outside the source tree.
- [ ] Enable GitHub private vulnerability reporting so the SECURITY.md reporting route works.
- [ ] Enable GitHub secret scanning/push protection where available and require successful CI checks before merging.
- [ ] Confirm the GitHub Actions workflow succeeds on both configured macOS runners. Local tests do not confirm hosted-runner results.
- [ ] Add a concise repository description and topics such as `macos`, `swift`, `swiftui`, `gemini`, and `writing-assistant`.

Review commands after Git initialization:

```sh
git status --short --ignored
git ls-files
git ls-files -ci --exclude-standard
git diff --cached --check
git diff --cached
```

The ignored-but-tracked command should print nothing. `.gitignore` does not remove files already committed. Review author emails in imported history as well as file contents. Never publish the audit's disposable local build output.

## Manual app checks

Use synthetic text in TextEdit, a browser textarea/contenteditable editor (`Tests/Fixtures/editor.html`), and any Electron apps you intend to claim as supported. Record macOS and destination-app versions with results.

- [ ] Authenticate using a user-owned key and a model available to that project. Verify grammar and prompt rewrites preserve language, facts, formatting, and intent.
- [ ] Test selected text and whole-field capture, Unicode/emoji, review, editable results, Copy, Apply, automatic mode, and normal host Undo.
- [ ] Confirm Apply never submits the destination message.
- [ ] Cancel while waiting; check timeout, bad key/model, unavailable network, and quota errors.
- [ ] Type during generation, switch fields/apps, and close the source app. Confirm unsafe replacement is refused and completed results remain available.
- [ ] Check clipboard restoration, a clipboard change during the request, and slow destination paste handlers.
- [ ] Check secure-field refusal using disposable test input; do not send a real password.
- [ ] Test shortcut conflicts, restored defaults, permission denial/regrant, and a rebuilt bundle's Keychain access.
- [ ] Check multiple displays, moved source windows, light/dark popups, Reduce Motion, and keyboard confirmation.
- [ ] Check history reload, edited-result updates, confirmed clearing, and storage-error reporting.

Live API authentication and cross-app replacement are not covered by unit tests. Claim support only for environments you have actually tested.

## Optional screenshots

Capture Settings → General, the synthetic result preview, and synthetic History examples. Avoid capturing the Gemini settings pane, real history, clipboard managers, account details, or unrelated apps. Crop screenshots and remove identifying metadata before adding them to a `docs/images/` folder. Include descriptive alt text in README embeds; do not commit broken image links or substitute mockups for real screenshots.

## Before distributing an app bundle

- [ ] Set the version/build in `Resources/Info.plist` and update release notes.
- [ ] Build and test the intended architectures. The packaging script makes a current-architecture bundle, not a universal binary.
- [ ] For downloads intended for other users, sign with your own Developer ID identity, configure the signing/notarization requirements, notarize with Apple, and staple/verify the ticket. The script's default ad-hoc signing only supports local development and does not establish distribution readiness.
- [ ] Keep certificates, private keys, team/account credentials, and notarization profiles outside the repository. Review bundled files before upload.
- [ ] Test installation and first-run permissions on another Mac without your development settings/key.
- [ ] Include the MIT license with distributed copies; list version, minimum macOS, architecture, and known compatibility limitations in release notes.

Follow Apple's [notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) for current signing requirements. A public source repository can be useful before offering prebuilt downloads.

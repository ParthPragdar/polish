# Security policy

## Supported versions

Polish is an early-stage project. Security fixes are made on the `main` branch and shipped in the next [release](https://github.com/ParthPragdar/polish/releases); older versions are not patched separately. Update to the latest release to get fixes.

## Reporting a vulnerability

Do not disclose API keys, private text, or exploitable vulnerabilities in public issues or pull requests. Report it privately through [**Security → Report a vulnerability**](https://github.com/ParthPragdar/polish/security/advisories/new) on this repository. Only the maintainer can see these reports.

Include the affected commit/version, macOS version, reproduction steps with synthetic text, expected/actual behavior, and potential impact. Remove credentials and personal data from all evidence. There is no guaranteed response time or bug bounty.

## Areas of particular interest

- Reading secure fields or capturing text outside the requested editor.
- Sending text or credentials to unintended endpoints.
- Replacing text after a field, application, or draft changes.
- Exposing API keys, clipboard contents, or saved history.
- Allowing model output to execute actions beyond the verified text replacement.

See [privacy and storage](docs/PRIVACY.md) for intended data handling. If a credential was accidentally committed or shared, revoke it promptly; deleting the current file alone does not remove it from Git history or copies.

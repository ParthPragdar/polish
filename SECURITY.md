# Security policy

## Supported versions

Polish is an early-stage project. Security fixes target the latest source on the default branch; older snapshots and locally built binaries do not have a separate maintenance commitment. Update and rebuild to obtain fixes.

## Reporting a vulnerability

Do not disclose API keys, private text, or exploitable vulnerabilities in public issues or pull requests. Use this repository's **Security → Advisories → Report a vulnerability** feature to contact the maintainers privately. The maintainer must enable private vulnerability reporting before publication, as described in the [release checklist](docs/RELEASE_CHECKLIST.md).

If that feature is unavailable, use a private contact method explicitly listed by the repository owner on their GitHub profile. If no private route is listed, open an issue asking for a security contact without including exploit details or private data.

Include the affected commit/version, macOS version, reproduction steps with synthetic text, expected/actual behavior, and potential impact. Remove credentials and personal data from all evidence. There is no guaranteed response time or bug bounty.

## Areas of particular interest

- Reading secure fields or capturing text outside the requested editor.
- Sending text or credentials to unintended endpoints.
- Replacing text after a field, application, or draft changes.
- Exposing API keys, clipboard contents, or saved history.
- Allowing model output to execute actions beyond the verified text replacement.

See [privacy and storage](docs/PRIVACY.md) for intended data handling. If a credential was accidentally committed or shared, revoke it promptly; deleting the current file alone does not remove it from Git history or copies.

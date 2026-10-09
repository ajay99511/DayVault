# Security Policy

> **Maintainer:** Ajay Elika ([@ajay99511](https://github.com/ajay99511)) — ajayelika99511@gmail.com

## Supported versions

DayVault has no long-term support branches. Security fixes go into `main` and
ship in the next release.

| Version | Supported |
| --- | --- |
| Latest release and `main` | :white_check_mark: |
| Anything older | :x: Upgrade to the latest release |

## Reporting a vulnerability

**Please do not open a public issue, discussion or pull request for a security
problem.** Report it privately:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**, or go straight to
   [the advisory form](https://github.com/ajay99511/DayVault/security/advisories/new).
3. If that isn't available to you, email the maintainer at the address above
   with `[DayVault security]` in the subject line.

### What to include

- What the vulnerability is and what an attacker could do with it.
- Steps to reproduce; a minimal proof of concept if you have one.
- The affected version or commit, the platform, and the device and OS version.
- Any logs or screenshots. **Remove real journal content first.**

### What happens next

| Step | Target |
| --- | --- |
| Acknowledgement | within 3 business days |
| Initial assessment: accepted, needs more information, or declined with reasons | within 7 business days |
| Fix released for accepted reports | within 90 days, sooner for high-severity issues |

We'll agree a disclosure date with you and credit you in the release notes,
unless you'd rather stay anonymous. We won't take legal action against
good-faith research that follows this policy, avoids other people's data, and
gives us reasonable time to fix the issue before disclosure.

## Security model

DayVault is offline-first: there is no DayVault server or account, and your
data stays on your device unless you export it. Knowing what the app does and
doesn't protect helps you judge whether something is a vulnerability.

**What the app protects**

- **App lock PIN.** Stored only as a salted PBKDF2-HMAC-SHA256 hash (100,000
  iterations) in the platform's secure storage (Keystore-backed on Android,
  the Keychain on iOS and macOS, the OS-protected equivalent on desktop).
  After 5 wrong attempts, entry is locked out; each further lockout lasts
  longer, up to 1 hour.
- **Privacy Vault passcode.** Hashed the same way, with its own salt and its own
  attempt limit.
- **Exported backups.** Encrypted with AES-256-GCM when encryption is selected
  at export. The key is the app's data key, which is itself protected by a key
  derived from your PIN.

**What it does not protect, by design**

- **Journal content is not encrypted at rest.** Entries are stored as plain text
  in the app's private storage. The Privacy Vault hides entries behind a
  passcode inside the app; it doesn't encrypt them. Anyone who can read the
  app's private storage can read the journal; for example, someone with
  access to a rooted device or an unlocked desktop session.
- **Images are stored as references.** An entry points to a photo, file or URL
  that stays where it was. DayVault doesn't copy or protect the image itself.

## Scope

**In scope**

- Bypassing the app lock, the Privacy Vault, or their attempt limits and
  lockouts.
- Recovering a PIN or vault passcode from what DayVault stores.
- Journal data reaching another app or process through DayVault, for example
  through an exported Android component, a share intent, or a file written
  outside the app's private storage.
- Weaknesses in backup encryption, or importing a crafted backup that leads to
  code execution, path traversal, or corruption beyond the imported data.
- Demo mode exposing or overwriting real data, or skipping the lock screen.

**Out of scope**

- Reading plain-text journal data with root, a jailbreak, or full access to an
  unlocked device or user account. This is the documented trade-off above,
  not a bypass.
- Reports against versions that are no longer supported.
- Vulnerabilities in Flutter or a third-party package that DayVault doesn't make
  exploitable. Report those upstream; we'll pick up the fix.
- Missing hardening with no demonstrated impact.

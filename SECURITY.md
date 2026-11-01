# Security policy

KeyCase is a local-first Android password manager and TOTP authenticator.
There is no account, cloud sync, analytics, or telemetry. The only network
request is the user-triggered GitHub release check.

## Reporting a vulnerability

Please use GitHub's **private security advisory** flow for
[LumiDesk/key-case](https://github.com/LumiDesk/key-case/security/advisories/new)
instead of a public issue. Include:

- the affected version (`Settings → About` shows it),
- reproduction steps,
- the impact you believe it has.

Do not include real vault data, master passwords, or TOTP secrets in a report.
Use a freshly created test vault.

## Threat model

Protected against:

- someone who obtains the encrypted `vault.tkv` file without the master
  password or an enrolled biometric credential;
- a malicious backup/Aegis/icon-pack file that tries to exhaust memory or
  otherwise crash the app during import (bounded file size, scrypt memory cap,
  image sampling and decompression limits);
- accidental plaintext persistence of secrets in Activity saved state;
- screenshots and screen recording when **Block screenshots** is enabled.

Not protected against:

- a rooted or otherwise compromised device, a malicious keyboard/IME, or an
  attacker who can read the app's memory while it is unlocked;
- a forgotten master password (there is no recovery key);
- metadata visible to a backup provider (file names and timestamps; the
  content itself is encrypted);
- the update check beyond normal Android TLS validation. The request goes only
  to `api.github.com` and is only made after the user taps the button.

## Vault format and cryptography

The on-disk contract is documented in
[docs/design/vault-format-v1.md](docs/design/vault-format-v1.md):
Argon2id derives a password key, AES-256-GCM wraps a random vault key, and the
gzip-compressed JSON payload is encrypted with the vault key and bound to the
vault id as AAD.

The biometric credential is an additional Android Keystore-wrapped copy of the
vault key. It is bound to the vault id and invalidated when biometric
enrollment changes.

## Supported versions

Security fixes are applied to the latest release on `main`. Old APKs are not
maintained.

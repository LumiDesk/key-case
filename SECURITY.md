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

- someone who obtains the encrypted `vault.kcv` file without the master
  password or an enrolled biometric credential;
- a malicious backup, Aegis export, or image file that tries to exhaust memory
  or crash the app during import (64 MB import cap, bounded KDF/scrypt parameters,
  header/payload size caps, images downsampled to 256 px);
- accidental plaintext persistence: secrets are not written to logs,
  preferences, caches, or temporary files;
- screenshots and screen recording: `FLAG_SECURE` is on by default and can be
  disabled in Settings;
- clipboard residue: copied passwords and codes are cleared after 60 seconds when
  the clipboard still contains the value KeyCase wrote (on by default).

Not protected against:

- a rooted or otherwise compromised device, a malicious keyboard/IME, or an
  attacker who can read the app's memory while it is unlocked;
- an attacker who can execute code with the app's UID: the Keystore key is
  protected by the Android Keystore but is not cryptographically bound to a
  biometric prompt; the prompt is enforced by the app layer;
- a forgotten master password (there is no recovery key);
- metadata visible to a backup provider (file names and timestamps; the
  content itself is encrypted);
- the update check beyond normal Android TLS validation. The request goes only
  to `api.github.com` and is only made after the user taps the button.

## Vault format and cryptography

The on-disk format is `KCV1` (`formatVersion 1`) with a `schemaVersion 2`
payload, implemented in
[`lib/app/vault/vault_container.dart`](lib/app/vault/vault_container.dart).
Argon2id (64 MiB, 3 iterations, p=2 by default) derives a password key from the
master password and the per-vault salt. That key wraps a random 256-bit vault
key with AES-256-GCM. The payload is gzip-compressed JSON encrypted with the
vault key; the vault id is bound as AAD, and the ciphertext carries a 16-byte
GCM tag. KDF parameters are stored in the container header, but are bounded
before use. Each item carries exactly one of `login` or `totp`; there are no
top-level credential fields.

Biometric unlock is an additional copy of the vault key encrypted by a
non-exportable Android Keystore key. The copy is bound to the vault id; a stale
copy from another vault is cleared on the next read. The system
`BiometricPrompt` gates the app flow, but the Keystore key itself is not
authentication-bound; the master password is always available as fallback.

The automatic snapshots and manual exports are the same encrypted container,
not a plaintext export. `schemaVersion 1` vaults and backups are not readable by
the current app.

## Supported versions

Security fixes are applied to the latest release on `main`. Older APKs are not
maintained.

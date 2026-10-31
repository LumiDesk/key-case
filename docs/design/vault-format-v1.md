# KeyCase vault container v1

> Status: implemented in `:core` (`VaultContainer`). This document is the on-disk contract; changes require a format-version bump.

## File layout

```
offset  size      field
0       4         magic "TKV1" (ASCII)
4       1         format version = 1
5       4         header length N (uint32, big endian)
9       N         header JSON (UTF-8)
9+N     rest      payload ciphertext (AES-256-GCM, tag included)
```

The header is plaintext on purpose: the password slot's KDF parameters and salt must be readable before the vault can be decrypted. It contains no usable secret.

## Header JSON

```json
{
  "formatVersion": 1,
  "vaultId": "uuid",
  "cipher": "AES-256-GCM",
  "compression": "gzip",
  "createdAt": "2026-10-31T08:00:00Z",
  "payloadNonce": "base64",
  "slots": [
    {
      "id": "uuid",
      "type": "password",
      "salt": "base64",
      "kdf": { "memoryKib": 32768, "iterations": 3, "parallelism": 2 },
      "nonce": "base64",
      "wrappedKey": "base64"
    }
  ]
}
```

## Key hierarchy

```
master password
  -> Argon2id(salt, memoryKib, iterations, parallelism) -> 32-byte password key
  -> AES-256-GCM(password key, AAD = slot id/type) -> 32-byte vault key

random 32-byte vault key
  -> AES-256-GCM(vault key, random 12-byte nonce, AAD = magic|version|vaultId|payload)
  -> gzip(JSON(VaultData))

VaultData
  -> JSON, schema = 1, items / groups
```

- The password key only wraps the vault key. Changing the master password re-wraps the vault key; the payload is not re-encrypted.
- Every slot has its own salt and KDF parameters, so biometric/recovery slots can be added without changing existing slots.
- AAD binds the payload to `vaultId` and the slot ciphertext to its slot id/type.

## Cryptographic choices

| Purpose | Choice |
|---|---|
| Password KDF | Argon2id (BouncyCastle `Argon2BytesGenerator`) |
| Default KDF parameters | 32768 KiB, 3 iterations, parallelism 2 |
| Accepted KDF range | memory 8 KiB–256 MiB, iterations 1–10, parallelism 1–8 |
| Encryption | AES-256-GCM, 96-bit nonce, 128-bit tag |
| Randomness | `java.security.SecureRandom` |
| Payload encoding | UTF-8 JSON, gzip before encryption |
| Integrity | GCM tag, plus AAD binding |

The accepted KDF range is deliberately capped so a malicious header cannot request gigabytes of memory or an unbounded iteration count.

## Size limits

- Header: 1 MiB maximum.
- Payload: 64 MiB maximum (ciphertext).
- File: no separate cap; derived from the two above.

## Error behavior

`VaultContainer.open` throws `VaultFormatException` for:

- bad magic / unsupported version;
- truncated or oversized header;
- missing password slot;
- wrong password or tampered key slot;
- wrong password or tampered payload;
- invalid gzip / JSON;
- mismatched `vaultId`.

The caller must treat all of these as "cannot open" rather than leaking which check failed to the UI.

## Implemented operations

- create from a master password;
- unlock into an in-memory `UnlockedVault`;
- re-seal edits with a fresh payload nonce;
- rotate the password slot without re-keying the payload.

## Not in v1 yet

- biometric slot (Android Keystore–wrapped vault key);
- recovery-code slot;
- attachments;
- streaming/mmap for very large vaults.

These are planned without changing the basic envelope: add slots and operations, keep the `TKV1` envelope.

## Test coverage (JVM)

- round trip preserves items and groups;
- wrong password rejected;
- tampered ciphertext rejected;
- bad magic rejected;
- RFC 6238 TOTP vectors (SHA-1/256/512);
- RFC 4226 HOTP vectors;
- Base32 round trip and invalid input;
- `otpauth://` parsing.

Run:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat :core:test
```

# Changelog

All notable user-visible changes are recorded here. Internal refactors, tests and docs are not.

## [Unreleased]

## [1.0.0] - 2026-11-02

Complete Flutter rewrite of KeyCase. The Kotlin implementation stays available at tag `v0.1.3`.

### Added

- Vault creation and unlock with a master password; the container is `AES-256-GCM` with an
  `Argon2id` (64 MiB / 3 / p=2) wrapped vault key.
- Biometric unlock: the vault key is wrapped by an Android Keystore key and gated by the system
  fingerprint prompt, with the master password always available as fallback.
- Password CRUD with random password generator, URL opening and clipboard copy.
- TOTP, HOTP and Steam codes with one shared ticker, countdown ring, per-settings grouping and
  optional next-code preview.
- QR scanning for `otpauth://` links, plus manual Base32 entry and advanced options
  (algorithm, digits, period, counter).
- A–Z grouped lists, global search, favorites, three sort orders, trash with restore and purge.
- Security center: weak, reused and outdated passwords.
- Built-in Aegis Simple Icons pack with automatic brand matching and letter avatars fallback.
- Encrypted backup export/import (`.kcbak`) and 10 rotating automatic snapshots after each save.
- Appearance settings: system/light/dark, five accent presets, custom accent color, Chinese and
  English UI.
- Auto-lock when leaving the app, optional screenshot protection, show/hide code settings.

### Changed

- UI rebuilt on the same visual language as Veri Fin: opaque surfaces, 16dp page gutters,
  56dp headers, 16dp cards, single accent color.
- Localization moved to ARB files with a Chinese template and English translations.
- Sorting and secondary actions use the shared `anchored_menu` component.
- Vault format is new (`KCV1`); the previous Kotlin `.tkv` container is not read.

### Security

- `allowBackup=false`; no network permission is requested, so no telemetry or sync is possible.
- Master password, vault key and TOTP secrets never reach logs, preferences or temporary files.

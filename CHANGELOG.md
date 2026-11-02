# Changelog

All notable user-visible changes are recorded here. Internal refactors, tests and docs are not.

## [Unreleased]

## [1.0.3] - 2026-11-02

### Fixed

- Home empty-state card had lost its horizontal margins and stretched edge to edge.
- Importing a backup created by the Kotlin app failed with "backup failed": legacy `TKV1`
  containers are now detected and read directly, then converted to the new vault on import
  (same master password as the backup).

### Changed

- "Check for updates" no longer shows the redundant "only contacts GitHub when tapped" line.

## [1.0.2] - 2026-11-02

### Fixed

- Biometric unlock failed with "fingerprint verification failed" on real devices: the
  Activity now extends `FlutterFragmentActivity`, which `BiometricPrompt` requires.
- Home overview card and the item card below it had no vertical gap.
- List headers showed a bare number; they now read "共 N 条" / "N items".

### Changed

- Display mode, accent color, language, auto-lock and code grouping are chosen from anchored
  menus (`anchored_menu`) instead of bottom-sheet pickers.
- Custom accent color uses the same HSV picker as Veri Fin (preview + hue/saturation/brightness).
- Change master password is a dialog with the same password-strength bar as vault creation.
- Automatic snapshots now require a backup folder: pick a SAF folder (stored under its
  `KeyCase` subdirectory), keep the last 10 snapshots, and see the last backup time.

### Added

- Check for updates in About: reads the GitHub release feed only when tapped, and offers to
  open the release page when a newer version exists.

## [1.0.1] - 2026-11-02

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
- Icon picker: searchable brand list, custom image (PNG stored encrypted in the vault) and
  "back to automatic matching".
- Aegis vault import (plain or password-encrypted exports), merged with duplicate detection.
- Google Authenticator migration import: paste the `otpauth-migration://` link or scan its QR.
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

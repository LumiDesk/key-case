# Changelog

All notable user-visible changes are recorded here. Internal refactors, tests and docs are not.

## [Unreleased]

### Added

- A favourite star in the detail header for both logins and tokens.

### Changed

- Notes are shown as a full-height block that can be selected and copied by long-press, instead of a two-line row with a copy button.
- The notes field in the editor grows with its content instead of stopping at four lines.
- Detail page cards and section labels line up with the home and settings screens.
- Toggling a favourite no longer shows a feedback message; the star changes immediately.

### Fixed

- The token detail page no longer repeats the "Notes" heading.

## [1.1.0] - 2026-11-03

### Added

- Restore an encrypted backup directly from the unlock or create screen, and delete the local vault
  without unlocking first.
- Tokens can store notes; logins support multiple URLs.
- Steam QR codes are recognised, including links that mark the encoder as `steam`.
- Copied passwords and codes are cleared from the clipboard after 60 seconds (can be disabled).
- Screenshot protection is enabled by default (can be disabled).
- An open-source licenses entry in Settings.

### Changed

- The vault payload is `schemaVersion 2`: login and token fields are stored in separate,
  mutually exclusive objects.
- Unlocking the vault after a backup restore disables fingerprint unlock until it is enabled again.
- Automatic snapshots are written only after content changes, at most once per minute, and only
  files named `keycase-*.kcbak` are rotated.

### Fixed

- Locking during a save no longer restores the vault session or decrypted data in memory.
- Rapid consecutive edits no longer lose updates.
- The editor's system back gesture now asks before discarding changes.
- Malformed or hostile backup headers can no longer force an unbounded Argon2id allocation.
- TOTP parameters are validated before use, so a damaged token cannot crash the list.
- Importing a backup clears the stale Keystore-wrapped vault key.
- Token codes no longer sit in an oversized capsule or align toward the top of the row.
- The fingerprint prompt uses the selected app language and no longer repeats the same
  sentence as title, hint, and reason.
- The bottom feedback pill follows the light/dark theme instead of always being dark in light mode.
- Feedback messages keep the selected language when the device locale includes a region
  (`zh_CN`, `en_US`).
- The fingerprint switch is disabled when the device has no usable biometric hardware or enrollment.
- “Check for updates” shows an inline spinner and cannot be triggered twice while running.

## [1.0.7] - 2026-11-03

### Changed

- The login editor keeps a single random-password button in the password field instead of
  repeating it below the field.

### Fixed

- Scanning a token QR no longer saves it immediately: the scanned data now opens in the
  new-token editor, and the token is written only after you tap Save.
- Unlocking now returns to the screen and tab you were on before locking instead of the
  Home tab.

## [1.0.6] - 2026-11-02

### Added

- About now links to the public GitHub repository.

### Changed

- The trash row in Settings shows "共 N 条" or "暂无" instead of a bare number.

### Fixed

- Exporting an encrypted backup now opens Android's system save dialog and writes through SAF;
  choosing a destination no longer fails with "backup operation failed".

## [1.0.5] - 2026-11-02

### Fixed

- Pressing back on a non-home tab now returns to Home instead of closing the app.
- Pressing back on Home now shows a "press back again to exit" hint; the app closes only on a
  second back press within two seconds.

## [1.0.4] - 2026-11-02

### Added

- The token tab's add button now expands into "scan" and "manual" actions instead of opening a
  bottom sheet.
- The icon picker can browse and search the complete bundled icon pack instead of the first 120
  results.

### Changed

- Every static single-choice menu now uses the same anchored menu; editor advanced settings no
  longer open a bottom-sheet option list.

### Fixed

- The unlock screen now prompts for fingerprint automatically when biometric unlock is enabled.
- Hidden token codes show exactly one dot per digit and keep the next code hidden until revealed.
- Tapping a hidden token code reveals and copies it; tapping elsewhere or waiting 10 seconds hides
  it again.
- Tapping a search result now opens the item detail instead of only closing search.
- Trash timestamps such as "5 minutes ago" now follow the selected app language.

### Security

- Locking now closes any open detail/editor screens and drops the decrypted vault data from
  memory immediately, in addition to zeroing the vault key.

## [1.0.3] - 2026-11-02

### Fixed

- Home empty-state card had lost its horizontal margins and stretched edge to edge.

### Changed

- "Check for updates" no longer shows the redundant "only contacts GitHub when tapped" line.

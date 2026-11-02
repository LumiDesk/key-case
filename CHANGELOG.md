# Changelog

All notable user-visible changes are recorded here. Internal refactors, tests and docs are not.

## [Unreleased]

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

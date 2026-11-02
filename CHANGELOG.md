# Changelog

All notable user-visible changes are recorded here. Internal refactors, tests and docs are not.

## [Unreleased]

### Security

- Locking now closes any open detail/editor screens and drops the decrypted vault data from
  memory immediately, in addition to zeroing the vault key.

## [1.0.3] - 2026-11-02

### Fixed

- Home empty-state card had lost its horizontal margins and stretched edge to edge.

### Changed

- "Check for updates" no longer shows the redundant "only contacts GitHub when tapped" line.

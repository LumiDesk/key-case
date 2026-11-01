# Review remediation status

> Branch: `feat/review-remediation`  
> Based on: `review/systematic-review` (review report + evidence)  
> Date: 2026-10-31

## Completed in this pass

### P0 — data/security

- **P0-1** Master-password rotation now gives the rotated session its own
  `vaultKey` copy; added a regression test that seals after closing the old
  session. Verified on the emulator: change password → favorite/save → lock →
  unlock with the new password → data intact.
- **P0-2** Removed `rememberSaveable` from master passwords, item passwords,
  notes, TOTP secrets, backup passwords, and migration/otpauth links.
- **P0-3** All external pickers (icon image, icon pack, settings icon pack) call
  `prepareExternalActivity()`. Verified: opening the system photo picker and
  returning keeps the editor alive.
- **P0-4** Aegis import rejects files over 64 MiB and scrypt parameters that
  would allocate more than 256 MiB. Added a regression test for the 4 GiB case.
- **P0-5** Biometric enrollment is bound to `vaultId`; a wrapped key from a
  different vault is cleared instead of retried. Backup import also invalidates
  the old enrollment through the vault-id check.

### P1 — correctness and UX

- TOTP ticker uses one second-aligned clock; codes and the progress bar no
  longer use separate time sources.
- HOTP and Steam are fully supported: type selection, HOTP counter/Next,
  HOTP persistence, Steam 5-character format, scanning/importing all types.
- OTP digits/period are validated on parse/import (1..8 digits, 1..300s).
- Password/token list search clears when closed and auto-focuses when opened.
- URL field disables capitalization/autocorrect; URL can be opened in a browser.
- Item deletion now says "Move to Trash?"; single permanent delete has its own
  confirmation.
- Timestamps are formatted in the device time zone instead of slicing UTC ISO.
- Route/detail and editor targets survive rotation via `rememberSaveable`; dirty
  editors ask before discarding. Secrets still reset on recreation by design.
- Static UI copy migrated to `values/strings_ui.xml` + `values-zh/strings_ui.xml`
  with `stringResource`; dynamic accessibility descriptions are localized.
- Contrast is derived from black/white ratio; light accents (green/amber) use
  dark ink; custom accents get a readable `onPrimaryContainer`.
- 48dp accent swatches with semantic labels; A–Z index exposes custom
  accessibility actions; code pills expose a copy/reveal description; switches
  use `toggleable`.
- Vault import is bounded, keeps `vault.tkv.pre-import`, and triggers auto
  backup; auto backup also runs after password rotation/imports.
- Backup filenames include milliseconds, prune by filename, and clean up partial
  files.
- Icon avatars render at size buckets; custom/imported images decode with
  bounds + `inSampleSize`; icon pack validation no longer fully decodes images.
- Duplicate secrets are skipped during Aegis/Google imports.
- Accessibility contrast test + date formatting/URL tests added.

### P2 / infrastructure

- Favorites toggle in detail; type icon in "Recently updated".
- "Delete vault" danger zone with confirmation and biometric cleanup.
- "Last backup" row no longer shows a dead chevron; settings count excludes
  trash; Aegis copy no longer mentions removed group UI.
- Search page uses the app background color.
- `MainViewModel` import writes now trigger backups; single source of truth for
  weak-password rules (`SecurityRules.kt`).
- `SECURITY.md` added.
- PR CI workflow added (unit tests + lint + debug build).
- README/DESIGN updated for HOTP/Steam, backups, auto-lock, localization.

## Verification

```text
./gradlew :core:test :app:testDebugUnitTest :app:assembleDebug \
          :app:assembleRelease :app:lintDebug --rerun-tasks
BUILD SUCCESSFUL
release APK: app/build/outputs/apk/release/app-release.apk (7.63 MB)
```

Connected tests were run on the final code (`connectedDebugAndroidTest`);
`test-result-exit-code.txt` is `0`. Manual emulator checks covered: create/unlock,
password CRUD, favorite, URL opening, search, password rotation + save + reopen,
auto-lock on background, icon-picker external activity, HOTP create/Next, delete
vault.

## Commits in this pass

```text
a3f42fd fix(core): keep rotated session key after password change
5e01f8d fix(app): protect secrets in state and external pickers
4d0be7b fix(core): cap Aegis scrypt memory and import size
536a52a fix(app): bound vault imports and keep a pre-import copy
96b6e67 fix(app): bind biometric enrollment to the vault id
0cbf0b3 refactor(app): drive auto-lock from process lifecycle
739c346 fix(app): clear filters, sanitize URL input and localize dates
c3f796e feat(app): support HOTP and Steam tokens
2ee40df fix(app): preserve navigation state and confirm discarded edits
aea573a feat(app): add favorites, URL opening and vault deletion
572feb6 feat(app): migrate copy to string resources and improve accessibility
c2d1ff2 fix(app): decode icons at the requested size
c816ff5 refactor(app): share security rules and add CI
eefd618 fix(app): refresh backups after sensitive writes
ab854d3 fix(app): localize accessibility labels and sync system bars
6626f07 docs: describe HOTP/Steam, backups and localization
3ffaa11 feat(app): skip duplicate tokens during imports
416b746 docs(review): record remediation status and refresh screenshots
a614655 test(app): update editor test and compile android tests in CI
```

## Latest cleanup round

- Removed the unused Aegis SVG → `ImageVector` parser (~120 lines), the dead
  `InfoLine` composable, `parseAccentHex`, example unit/instrumented tests, and
  legacy density launcher PNGs (the project is minSdk 26 and uses adaptive
  icons).
- Added explicit `dataExtractionRules`, removed the redundant Activity label and
  the legacy fixed-orientation scanner override.
- Added `localizedError()` for the most common vault/network exceptions;
  unknown errors still fall back to the dictionary.
- CI now also compiles `assembleDebugAndroidTest`, which caught a missing
  `onPrepareExternal` argument in `PasswordEditorSheetTest`.
- Extracted `VaultRepository`: it owns `vault.tkv`, the unlocked session and the
  single write mutex. `MainViewModel` is down to ~660 lines and no longer
  touches `AndroidVaultStore`/`UnlockedVault` directly. Verified on the emulator:
  create → change master password → save item → background/lock → unlock with
  new password → item intact.
- Extracted `VaultBackupService` and `SettingsRepository`, and moved the
  `AppSettings`/`DarkMode`/`CodeGrouping` models to `data/`. `MainViewModel` is
  now ~565 lines and only coordinates state/imports; no direct file I/O or
  SharedPreferences keys remain.
- Verified again: unit tests, Lint, debug/debug-androidTest build, connected
  tests (`test-result-exit-code.txt = 0`), release build (7.63 MB).

## Remaining work

1. **Full localization cleanup** — static copy is in resources, but dynamic
   error messages from `:core`/`MainViewModel` and some legacy dictionary
   strings still need mapping to error codes/resources. `LocalizedText.kt`
   remains as a fallback.
2. **Further architecture split** — `MainViewModel` is ~565 lines; import
   orchestration/state mapping still lives there. `VaultRepository`,
   `VaultBackupService` and `SettingsRepository` now own the disk/session,
   backup I/O and preference boundaries.
3. **Accessibility deep pass** — TalkBack/fontScale 1.3–2.0/RTL/3-button nav
   verification; fixed-height cards and some dialog rows still need visual
   testing.
4. **Screenshots** — light screenshots were refreshed; dark-mode screenshots
   (`home-dark`, `settings-dark`) are still from the old UI and need recapture.
5. **Dependencies / tooling** — update lifecycle/activity/core/compose BOM,
   evaluate R8 full mode, add ktlint/detekt and a clean lint invocation in CI
   (lint has shown an incremental-analysis crash on AGP 9.4.1; a fresh run
   passes).
6. **Emulator ANR observation** — one manual session produced an
   `Input dispatching timed out` while a Gradle build was running in parallel;
   the stack was inside a LazyColumn fling/Compose frame, not a blocked vault
   operation. It was not reproduced with the emulator idle. Re-check on a quiet
   emulator/device before release.

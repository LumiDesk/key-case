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
release APK: app/build/outputs/apk/release/app-release.apk (7.69 MB)
```

Connected tests were run earlier in the pass (`connectedDebugAndroidTest`,
exit code 0). Manual emulator checks covered: create/unlock, password CRUD,
favorite, URL opening, search, password rotation + save + reopen, auto-lock on
background, icon-picker external activity, HOTP create/Next, delete vault.

## Remaining work

1. **Full localization cleanup** — static copy is in resources, but dynamic
   error messages from `:core`/`MainViewModel` and some legacy dictionary
   strings still need mapping to error codes/resources. `LocalizedText.kt`
   remains as a fallback.
2. **Architecture split** — `MainViewModel` is still ~760 lines; split vault
   repository / import / backup / settings concerns. Pure refactor, no behavior
   change.
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

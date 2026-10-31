# KeyCase

**Local-first, offline Android password manager and TOTP authenticator.**
No account, no cloud, **no `INTERNET` permission**.

> Status: early development. The product design is frozen at v0.5. The pure-JVM `:core` module now has the encrypted vault container, Argon2id/AES-GCM, and TOTP/HOTP/Steam with JVM tests; the Android UI and file storage are next.

## What it is

KeyCase keeps two kinds of items in one local, encrypted vault:

- **Passwords** — accounts, passwords, URLs, notes, groups, favourites.
- **Dynamic tokens (TOTP)** — scanned or manually entered secrets, with codes generated on-device.

The app is built for Android and is intentionally offline. There is no sync server, no account system, and no telemetry.

## Principles

- The vault is encrypted on the device; the master password never leaves it.
- The app declares **no `INTERNET` permission**, so it cannot upload data.
- Backups are explicit, encrypted files written to a folder the user chooses.
- Data must be portable: encrypted export/import, plus Aegis and Google Authenticator import.

## Documentation

- [Design decisions v0.5](docs/design/design-decisions-v0.5.md)
- [Vault container format v1](docs/design/vault-format-v1.md)
- [Research notes](docs/design/research.md)
- [Clickable prototype](docs/prototype/index.html)
- [Archived early plans](docs/archive/)

## Build

Requirements: Android Studio (with its bundled JBR), Android SDK, JDK 17+.

```powershell
# Windows
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
.\gradlew.bat assembleDebug
```

`local.properties` is machine-specific and is not committed.

Current baseline:

- `applicationId` / `namespace`: `top.talyra42.keycase`
- `minSdk`: 26
- `compileSdk` / `targetSdk`: 37
- Kotlin + Jetpack Compose + Material 3

## Project layout

```
app/                 Android app shell
core/                pure-JVM vault, crypto, TOTP, importers
docs/                design notes and the HTML prototype
gradle/              version catalog and wrapper
```

The `:core` module is deliberately free of Android APIs so its security-critical logic can be tested on the JVM. The Android layer (`app/`) owns files, Keystore, biometrics, and UI.

## Icon packs

The built-in icon pack is [Aegis Simple Icons](https://github.com/alexbakker/aegis-simple-icons), derived from [Simple Icons](https://simpleicons.org/). Simple Icons are CC0; brand logos remain trademarks of their owners. The pack is stored at `app/src/main/assets/iconpacks/aegis-simple-icons-v269.zip`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

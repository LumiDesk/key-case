# KeyCase UI redesign notes

The first Android build used a saturated accent as a background color and a fixed blue-grey surface, which made the app feel purple-on-blue and uncentered. This redesign treats color as a single accent role over neutral surfaces.

Reference: [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) design intelligence; password-manager product guidance (Minimalism & Swiss Style + Accessible & Ethical; trust blue + security green + dark neutral).

## Design principles

- **One accent role.** Accent is used for primary actions, selected navigation, focus rings and small icon containers. Large surfaces stay neutral.
- **Neutral canvas, coherent dark mode.** Dark surfaces are deep navy-grey, not a purple tint; light surfaces are near-white over a cool neutral background.
- **One information hierarchy per screen.** Title → section label → grouped card → row. No nested decorative cards.
- **4/8dp rhythm.** 16dp screen gutters, 14–18dp card radii, 16dp card padding, 10dp gaps between cards.
- **Touch first.** Primary controls are 48dp; icon-only controls have at least 48dp hit targets via `IconButton`.
- **No emoji as icons.** Material outlined icons only; the Aegis pack supplies real brand marks.

## Color tokens

| Role | Light | Dark |
|---|---|---|
| Background | `#F5F7FA` | `#0B111B` |
| Surface | `#FFFFFF` | `#121B29` |
| Surface variant | `#F0F3F7` | `#1A2535` |
| Ink | `#111827` | `#E9EFF7` |
| Muted ink | `#5B6779` | `#9BA9BC` |
| Outline | `#D6DEE8` | `#2B394D` |
| Default accent | `#2563EB` | same |
| Optional accents | teal/green/amber/rose | same |

Amber uses dark foreground text (`luminance > 0.30` selects ink instead of white), so button and chip labels stay readable.

## Components

- **Stat cards:** 88dp high, icon at left, number and label vertically centered as one column. The first card uses a 10% accent container; the rest are surface cards with a 1dp outline.
- **Settings:** section label outside the card, rows inside, 1dp dividers inset past the icon; no full-saturation panels.
- **Theme selector:** three equal 48dp segments; selected segment is accent, not a Material FilterChip row.
- **Bottom navigation:** surface-colored bar with a hairline divider; selected item uses accent icon/text and a subtle accent container indicator.
- **Detail/edit:** grouped information card; destructive action is icon + confirmation dialog; forms use labeled fields, not placeholders only.

## Verification checklist

- [x] Stat card content vertically centered (fixed `fillMaxSize` + `CenterVertically`).
- [x] Light and dark surface pairs checked on the Android 37 emulator.
- [x] 48dp theme segments and icon controls.
- [x] Safe-area padding through Scaffold / system bar insets.
- [x] No emoji structural icons.
- [x] Accent used sparingly; neutral background remains stable when accent changes.
- [ ] Largest Dynamic Type and landscape still need a dedicated pass.
- [ ] Imported icon packs and a full icon picker are not implemented yet.

## Screens to review

| Screen | File |
|---|---|
| Unlock (dark) | `docs/screenshots/unlock.png` |
| Home (light) | `docs/screenshots/home.png` |
| Passwords | `docs/screenshots/passwords.png` |
| Password detail | `docs/screenshots/password-detail.png` |
| Tokens + QR scan | `docs/screenshots/tokens.png` |
| Token detail | `docs/screenshots/token-detail.png` |
| Settings (light) | `docs/screenshots/settings-light.png` |
| Settings (dark) | `docs/screenshots/settings-dark.png` |
| Group management | `docs/screenshots/groups.png` |

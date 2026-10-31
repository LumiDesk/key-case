# KeyCase UI redesign notes

The first Android build used a saturated accent as a background color, oversized cards and a fixed blue-grey surface. It felt purple-on-blue, and the list pages did not match the prototype. This revision follows the prototype's compact list language and treats color as a single accent role over neutral surfaces.

Reference: [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) design intelligence; password-manager product guidance (Minimalism & Swiss Style + Accessible & Ethical; trust blue + security green + dark neutral).

## Design principles

- **One accent role.** Accent is used for primary actions, selected navigation, focus rings and small icon containers. Large surfaces stay neutral.
- **Neutral canvas, coherent dark mode.** Dark surfaces are deep navy-grey, not a purple tint; light surfaces are near-white over a cool neutral background.
- **Compact, list-first screens.** Titles sit inline with a count; search/sort are icon actions; rows are 8dp vertical padding with a 34dp avatar.
- **A–Z index on lists.** Every password/token list has a 27-letter index on the right; letters without entries are dimmed and non-clickable.
- **FAB owns creation.** The token tab has no top scan button and no overflow menu. The bottom-right plus expands upward into “扫码” and “手动添加”.
- **Imports live in Settings → 数据.** No import action is hidden in a list overflow.
- **4/8dp rhythm.** 16dp screen gutters, 14–18dp card radii, 14dp card padding, 8–10dp gaps between cards.
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

Accent changes and light/dark switches animate every large surface with `animateColorAsState` over 360ms. Amber uses dark foreground text (`luminance > 0.30` selects ink instead of white), so labels stay readable.

## Components

- **Stat cards:** 72dp high, 30dp icon, 21sp number and 11sp label vertically centered as one column. The first card uses a 10% accent container; the rest are surface cards with a 1dp outline.
- **List header:** title + count inline; search and A–Z sort icon buttons; search field expands/collapses with `AnimatedVisibility`.
- **List rows:** 34dp avatar, 14sp title, 11sp subtitle, 8dp vertical padding, hairline divider inset past the avatar.
- **Token row:** monospace code in an accent capsule plus a small circular countdown ring.
- **Token FAB:** expands two extended actions with fade/slide, rotates the plus into a close mark.
- **Settings:** section label outside the card, compact 10dp rows inside, 1dp dividers inset past the icon. No non-clickable informational rows in 安全.
- **Theme selector:** Material 3 `SingleChoiceSegmentedButtonRow` / `SegmentedButton` with a check on the active mode.
- **Custom accent:** HSV canvas (saturation/value board) + hue slider + live hex preview + restore-default, not a raw hex field.
- **Bottom navigation:** surface-colored bar with a hairline divider; selected item uses accent icon/text and a subtle accent container indicator; tab content crossfades/slides.
- **Detail/edit:** grouped information card; destructive action is icon + confirmation dialog; forms use labeled fields, not placeholders only.

## Verification checklist

- [x] Stat card content vertically centered, 72dp tall.
- [x] Light and dark surface pairs checked on the Android 37 emulator.
- [x] 48dp theme segments and icon controls.
- [x] Safe-area padding through Scaffold / system bar insets.
- [x] No emoji structural icons.
- [x] Accent used sparingly; neutral background remains stable when accent changes.
- [x] Full A–Z list index with dimmed unavailable letters.
- [x] Token creation is only via the expandable FAB.
- [x] All import actions are in Settings → 数据.
- [ ] Largest Dynamic Type and landscape still need a dedicated pass.
- [ ] Imported Aegis icon packs are not implemented yet; the built-in picker and custom image import are.

## Screens to review

| Screen | File |
|---|---|
| Create / unlock | `docs/screenshots/create.png`, `docs/screenshots/unlock.png` |
| Home (light/dark) | `docs/screenshots/home.png`, `docs/screenshots/home-dark.png` |
| Passwords | `docs/screenshots/passwords.png` |
| Password detail | `docs/screenshots/password-detail.png` |
| Tokens | `docs/screenshots/tokens.png` |
| Token FAB expanded | `docs/screenshots/fab-expanded.png` |
| Token detail | `docs/screenshots/token-detail.png` |
| Settings light/dark | `docs/screenshots/settings-light.png`, `docs/screenshots/settings-dark.png` |
| Color canvas | `docs/screenshots/color-canvas.png` |
| Group management | `docs/screenshots/groups.png` |
| Icon picker | `docs/screenshots/icon-picker.png` |

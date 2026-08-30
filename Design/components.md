# Picker component catalogue

The SeatLayer buyer picker, described so a Swift, Kotlin or React Native
engineer can build it without reading Dart. Names here are the Dart API's
names, deliberately: the four SDKs should agree on what things are called.

Every token reference (`size.dockBarHeight`, `color.dark.surface`,
`motion.duration.sheet`) resolves in [`tokens.json`](./tokens.json).

## Corner radius: buttons are not pills

**Decision, 2026-08-28.** Actions carry `radius.button` — 8 pt, which is
what the web picker's own buttons measure: its primary call to action rounds to
`calc(var(--sl-radius) * .55)` = 7.7 pt at the default 14 pt host radius, its
confirm-card actions to 9 pt and its view/3D buttons to 8 pt. Material's default
stadium button is therefore **wrong** for this design, and every native action
overrides it: `Continue`, `Hold seats & checkout`, `Cancel`, `Select`, `Find N
best seats`, `View from here`, `See it in 3D`, `Open venue 360°`, `Back to
venue`, `Apply filters`, `Try again` and the prompts' pairs.

`radius.button` is its own role, not a fraction of `radius.base`: a brand that
rounds its cards to 20 pt must not thereby grow pill buttons, and the organizer's
branding radius is never inherited by it.

Exactly three things stay true pills, at `radius.pill` / `radius.chip` (999):
the hold countdown pill, the price-legend chips, and the Map/3D segmented
control. Round icon controls (map buttons, the 3D seat stepper) are circles and
are unaffected.

Dart: `SeatLayerPickerThemeData(buttonRadius:)` moves every action at once, and
the per-element slots — `primaryButtonStyle`, `secondaryButtonStyle`,
`continueButtonStyle`, `iconButtonStyle` — and each widget's `style:` parameter
still win over it.

## Shared model

Every component reads one **picker snapshot** and calls back into a
**controller**. No component fetches anything itself.

Snapshot fields the catalogue refers to:

| Field | Meaning |
| --- | --- |
| `event` | name, venue, currency, branding, test mode |
| `map.rung` | `venue` (overview) or `seats` (a section is focused) |
| `map.focusedSectionId` | the focused section, or null |
| `map.isVenue3D` | whether the immersive scene is up |
| `map.categoryFilter` | the active price-chip filter |
| `sections[]` | `id`, `label`, `displayLabel`, `color`, `seatsLeft`, `priceMin`, `priceMax`, `zoneId` |
| `categories[]` | `key`, `label`, `color`, `priceMin` |
| `selection[]` | `SelectedSeat`: `label`, `sectionLabel`, `rowLabel`, `seatNumber`, `price`, `currency`, `objectType`, `tiers` |
| `cart` | `lines[]`, `ticketCount`, `cartTotal` |
| `hold` | `holdId`, `expiresAt`, `owner` |
| `capabilities` | which optional features are available — venue 3D, seat view, best available |
| `branding.attributionRequired` | whether the attribution line must render |

Two rules bind every component:

1. **The venue map owns the venue; native owns the chrome.** Everything in
   this catalogue is drawn natively, on top of the map.
2. **A row name may already contain its section.** Print
   `rowLabel` with the section prefix removed (Dart: `pickerRowLabel`), or the
   card reads `Stalls D · Row Stalls D C`.

## Layout

Phone below `size.phoneBreakpoint` (640). Wide at or above
`size.wideBreakpoint` (840). The phone composition is a column:

```
Header                                  size.headerHeight
┌ map surface (WebView) ─────────────────────────────────┐
│  top rail: PriceLegend │ ViewModeControl               │
│  TestModeBadge                                         │
│  corner controls (accessibility ◦ fit)                 │
│  ConfirmCard / Venue3D chrome / status overlay         │
│  DockBar                              size.dockBarHeight│
└────────────────────────────────────────────────────────┘
CartSheet peek                          size.peekHeight
```

The legend and the Map/3D control share one rail rather than stacking, because
their translated labels have no fixed width and either would otherwise be drawn
over the other.

---

## Header

**Name** `SeatLayerPickerHeader` · **Style slot** `headerStyle` · **Instance
override** `style:`

- **Inputs** `event.name`, `event.venue`, `branding.logo`, `hold`.
- **States** compact (phone, one line) / full (wide, two lines); with and
  without a hold.
- **Anatomy** `size.headerHeight` tall, ground `color.*.surface`, elevation
  `elevation.header`. Left: brand tile `size.headerLogoSize`. Centre: event
  name, `type.headerTitle`, ellipsized. Right: the HoldPill, then the dismiss
  control.
- **Callbacks** `onClose`.
- **Commands** none.

## PriceLegend

**Name** `SeatLayerPriceLegend` · **Style slots** `legendChipStyle`,
`chipShape` · **Instance override** `style:`

- **Inputs** `categories[]`, `map.categoryFilter`, `event.currency`.
- **States** chip idle / selected; empty (renders nothing); over the immersive
  scene it adopts the dark palette whatever the resolved mode is.
- **Anatomy** one horizontally scrolling row, 30 pt compact. Each chip: dot in
  the category colour, then the price, `type.legendChip`. Idle ground is the
  surface tinted 4 % with the ink; selected ground is the accent.
- **Callbacks** none.
- **Commands** `picker.setCategoryFilter { keys, focus }` — the first tap
  filters and drills in, the second clears.

## MapControls

**Name** `SeatLayerPickerMapControls` · **Style slot** `iconButtonStyle`

- **Inputs** `map.isVenue3D`, `map.focusedSectionId`, `capabilities`.
- **States** phone corners / wide rail; the map-only controls stand down while
  the immersive scene is up.
- **Anatomy** round controls `size.mapControlSize`, except the accessibility
  control at `size.accessibilityControlSize` (`size.minimumHitTarget`).
  Bottom-left accessibility, bottom-right fit; both lift by
  `size.dockBarHeight` while the dock is up.
- **Commands** `picker.zoomToFit`, `picker.setAccessibilityFilters`,
  `picker.setColorblindSafe`, `picker.setBuyerView`.
- **Note** `SeatLayerPickerViewModeControl` (the Map/3D segmented control) is a
  member of this stack on wide layouts only; on a phone the top rail owns it.

## DockBar

**Name** `SeatLayerDockBar` · **Style slot** `dockBarStyle` · **Instance
override** `style:`

- **Inputs** `sections[]`, `map.focusedSectionId`, `map.rung`.
- **States** hidden at rung `venue`; visible at rung `seats`; step controls
  disabled at the ends of `sections[]` (never wrapping around).
- **Anatomy** edge-to-edge, `size.dockBarHeight` plus the bottom safe area,
  elevation `elevation.dockBar`. Left: a 10 pt dot in the section's colour, the
  section name (`type.dockSection`, ellipsizes) and `N left`
  (`type.dockCount`, never ellipsizes; omitted when `seatsLeft` is unknown).
  Right: `‹ ›` section steps, then `‹ Venue`.
- **Motion** slides in over `motion.duration.dock`; the name cross-fades over
  `motion.duration.crossfade` when the focus changes.
- **Callbacks** `onSectionChanged(id)`, `onOverview`.
- **Commands** `picker.focusSection { id }`, `picker.overview`.

## ConfirmCard

**Name** `SeatLayerConfirmCard` · **Style slots** `confirmCardStyle`,
`primaryButtonStyle`, `secondaryButtonStyle`, `pillStyle` · **Instance
override** `style:`

- **Inputs** the newest unconfirmed `SelectedSeat`, `capabilities`
  (`seatView`, `venue3d`), the event's seat-view photo.
- **States** with photo and 3D (161 pt tall), with neither (89 pt); busy.
- **Anatomy** screen width less `2 × size.confirmCardGutter`, capped at
  `size.confirmCardMaxWidth`, radius `radius.card`, elevation
  `elevation.confirmCard`.
  1. Identity row, `size.confirmIdentityHeight`: dot, `Section · Row X · Seat
     N` (`type.confirmIdentity`), price right. The section may ellipsize; the
     row, seat and price may not.
  2. Photo strip, `size.confirmPhotoHeight`, only when a photo or 3D exists,
     with the `View from here` and `3D` pills overlaid.
  3. Actions, `size.confirmActionHeight`: `Cancel` and `✓ Select`, split 1:1,
     Select filled. The strip's `View from here` and `3D` controls are actions,
     not chips: they carry `radius.button`.
- **Motion** opens anchored to the tapped seat with `motion.curve.spring` over
  `motion.duration.enter`; leaves over `motion.duration.exit`. Select fires the
  `selectionAdded` haptic and a fly-to-peek indicator over
  `motion.duration.fly`.
- **Callbacks** `onConfirm`, `onCancel`, `onViewFromSeat`, `onShow3D`.
- **Commands** `picker.openSeatView`, `picker.showSeatIn3D`,
  `picker.deselect` on cancel.

## CartSheet

**Name** `SeatLayerCartSheet` · **Style slots** `sheetStyle`,
`continueButtonStyle` · **Instance overrides** `style:`,
`continueButtonStyle:`

- **Inputs** `cart`, `hold`, `capabilities.bestAvailable`, `event.currency`.
- **States** peek empty, peek with tickets, expanded empty (the best-seats
  form), expanded with tickets.
- **Anatomy** radius `radius.sheet`, elevation `elevation.sheet`.
  - **Peek** `size.peekHeight`: left `N tickets · total`, or `From <min>` when
    empty (`type.peekSummary`); right the filled `Continue · total` and the
    chevron. No best-seats control in the peek.
  - **Expanded** content height, capped at
    `size.sheetMaxHeightFraction` of the screen; the empty tray is capped at
    `size.emptyTrayMaxHeight`. Header is one line, `N tickets` plus the ✦
    best-seats control and the chevron — no title and no repeated total.
  - **Footer** the full-width BookButton, then the attribution when
    `branding.attributionRequired`.
- **Rules** the sheet never opens itself; any map tap while expanded collapses
  it to peek.
- **Motion** `motion.duration.sheet`.
- **Commands** `picker.checkout` from either call to action.

## CartList

**Name** `SeatLayerCartList`

- **Inputs** `cart.lines[]` joined to `selection[]`.
- **Anatomy** one `size.denseLineHeight` line per entry:
  `● Section · Row · Seat …… price ✕` (`type.denseLine`). Consecutive entries
  sharing section, row, category and price fold into one line:
  `Section · Row · 1–6   6 × €25   €150`, tapped to open in place. An opened
  run lists its members **in seat order**, matching the range its own label
  states. A run of one is not a group and keeps its category dot. Beyond
  `size.denseVisibleLines` lines the rest collapse behind `+N more`.
- **Rules** a range is only drawn when the seat numbers really are consecutive;
  anything else lists up to three labels and then `+N`. A ticket that carries
  its own control (a table's guest count, a tier choice) never folds.
- **Commands** `picker.deselect { label }`, offered back for
  `motion.durationOutsideBudget.undoWindow` as an undo.

## BookButton

**Name** `SeatLayerBookButton` · **Style slot** `primaryButtonStyle` ·
**Instance override** `style:`

- **Inputs** `cart`, `hold`, busy state.
- **Anatomy** full width, 46 pt, radius `radius.button`, `type.bookButton`.
  Carries its own label only — the total is already on the peek bar.
- **States** idle, busy (spinner), disabled when checkout is not possible.
- **Commands** `picker.checkout`, then `picker.rejectHandoff` if the host
  refuses the handoff, so a rejected hold is never stranded.

## Venue3D chrome

**Name** `SeatLayerVenue3D` · **Style slot** `pillStyle`

- **Inputs** the focused `SelectedSeat`, `map.isVenue3D`, `capabilities`.
- **States** live seat view / venue 360°; stepper disabled in venue mode.
- **Anatomy** the dark scene palette whatever the resolved mode is. `‹ Back to
  venue` and `Open venue 360°` are actions at `radius.button`; the caption chip
  naming the seat is a chip at `radius.chip`. Top-left
  `‹ Back to venue`. Bottom: a caption chip naming the seat, then
  `‹` previous seat, `Open venue 360°`, `›` next seat, and recentre.
- **Motion** `motion.duration.immersive`.
- **Commands** `picker.showSeatIn3D`, `picker.openVenue360`,
  `picker.setBuyerView`, `picker.recentre3D`.

## HoldPill

**Name** rendered by `SeatLayerPickerHeader` (`showHoldPill`) · **Style slot**
`pillStyle`

- **Inputs** `hold.expiresAt`.
- **States** counting down; absent when there is no picker-owned hold — a hold
  handed to the host is the host's to display.
- **Anatomy** a true pill (`radius.pill`) with a timer glyph and `mm:ss`,
  `type.pill`.
- **Haptics** `holdCreated` on creation, `holdExpired` on expiry.

## TestModeBadge

**Name** `SeatLayerPickerTestModeIndicator`

- **Inputs** `event.mode`.
- **Rules** required chrome: it has no host switch, and exactly one may render.
  It steps below the immersive scene's own back control rather than under it.
- **Anatomy** an amber pill reading `strings.testMode`.

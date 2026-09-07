# Changelog

## 0.4.0

The native picker follows the SeatLayer buyer picker's current phone design
item by item, on hosted runtime `seatlayer-js@0.84.1`. Views load
`https://cdn.seatlayer.io/seatlayer-js@0.84.1/mobile.html`.

**Design system**

- Every colour, size, radius, duration, curve, haptic strength and buyer-facing
  string is now generated from the shared picker design sources
  (`Design/tokens.json`, `Design/locale_strings.json`) into
  `SeatLayerPickerTokens*.g.swift`, checked in and verified in CI; the Swift
  never carries a transcribed number. Strings are typed (`SeatLayerPickerStringKey`),
  every one overridable; English defaults come from the token table and a
  locale dictionary is used only when a host names a locale.
- Both themes are complete ground sets; the accent, its ink, the font and the
  host radius are the organizer's brand in both. `SeatLayerPickerTheme` gains
  `fontFamily`, `logo`, `radius`, `buttonRadius` and `layout` overrides.

**The seat card**

- The card is a fixed sheet at the foot of the map. The map is lifted so the
  tapped seat rests above it at unchanged zoom, behind a veil with a clear
  hole around the seat, and returns when the card leaves unless the buyer
  moved the map. The runtime paints the candidate seat (thick ring, halo,
  paled neighbours) while the card asks.
- Section, row and seat as three cells; the category as a full-bleed band with
  its ink chosen per colour; every seat attribute as a band under it —
  accommodation types, wheelchair provision, restricted and obstructed view,
  premium seat, the organizer's note — with the shared glyph set and tones
  that meet 4.5:1 in both themes; a photograph of the view from the seat with
  the distance to the stage, where the runtime offers one.
- `Add seat` invites once, breathes until touched, sweeps and ticks on the
  press; a second tap on a carted seat raises the card in its Remove state
  instead of dropping the seat in silence. Swipe down, tap outside, or the
  platform's back gesture give the seat back. The card answers with haptic
  cues and sizes itself to what it says.
- The card comes up inside the 3D venue too, with `View from this seat`.

**The ticket sheet**

- One surface: a disc handle straddling the sheet's edge, a footer that reads
  "N tickets · total" or "No seats selected" with the seats listed under it,
  and one button that says what it is doing — hold seats and checkout,
  continue, securing your seats, opening checkout, or why it is waiting.
- Open, the cart shows one card per ticket (capped at three and a sliver
  before it scrolls), each with its × and its eye; tapping a card takes the
  map to that seat and the sheet stays where the buyer put it; a card swipes
  to remove. Removal is silent and answers the press, not the server.
- An empty cart offers a full-width `Find best seats` that opens the
  best-seats form: `Find seats together` with its ⓘ, a stepper, the ticket
  type and, where the venue has zones, a zone.
- After `Add seat`, a chip flies from the seat to the footer; the count and
  total swell when it lands, and only then does the map pull back.

**The map's chrome**

- Prices sit in a row of their own above the venue, `All prices` pinned first
  and clearing the filter to the whole venue; the Map | 3D control and the
  `Test mode` chip keep their corners; the floor rail is a track on the map.
- One control column in the bottom-right corner: the accessibility control at
  its head, `+`, and `Show whole venue`. `+` retires at the seats or the zoom
  ceiling but keeps its slot; the whole-venue disc is always live.
- Every control drawn over the map tells the runtime where it stands, so a
  tap on native chrome never reaches the seat under it.
- The section dock is off by default on every width (`showDockBar`).

**Accessibility**

- The accessibility sheet applies as its switches are flipped, one line per
  provision with the shared glyph, a note behind ⓘ where the chart authors
  one, live free counts, a `View` group for the two map switches, and a
  count that jumps to the first section holding a matching space. A stepper
  beside the control walks the rest.
- VoiceOver reading order and live regions, Dynamic Type with the design's
  clamps, Reduce Motion (every duration collapses; motion with no reduced
  form is skipped) and Reduce Transparency are honoured on every surface.

**Buyer-facing states**

- Loading draws the venue's silhouette and holds until the runtime has framed
  the map once. A chart that fails to load says so and offers Retry.
- Access lost, sales closed, sold out, a seat taken by another buyer, an
  expired or lapsed hold, and "You're all set" each have their native
  surface; `onBooked` fires once when a handed-off hold becomes a sale, and
  `showBookedOverlay` lets a host with its own confirmation keep the overlay
  down.
- The hold countdown lives in the header pill only. A buyer back from checkout
  keeps their seats, sees "Your seats are already in checkout" with
  "Release and change seats", and any seat added afterwards joins the cart;
  `Continue` replaces the hold with every seat.

**Runtime contract**

- Protocol 2 with Flutter's required and optional capability sets: an
  optional capability the runtime does not advertise withholds its surface,
  never fails. New: `seat-view-thumbnail-v1`, `accessibility-focus-v1`,
  `section-access-counts-v1`; `seat.retap`; `picker.setSelectionFocus`,
  `picker.setBlockedRegions`, `picker.frameSeat`,
  `picker.focusAccessibilityFilter`, `picker.focusNextAccessibleSection`.
- Composition: three new parts (`accessPanel`, `bookedOverlay`, `toast`),
  each replaceable by name. The picker's own toast band carries the messages
  it has to volunteer.

**Breaking**

- `SeatLayerPickerAccessNeed.count` and `SeatLayerPickerMapState.atVenueFit`
  are optional: "not reported" is no longer read as zero or false.
- Removed: the dense ticket-list helpers and tokens, `fromPrice`, the
  stringly string overrides, the older string-key spellings. Deprecated:
  `phoneZoom`, `phoneFit` (the controls are always drawn).

**Verification**

- 405 unit tests on macOS; 16 simulator golden tests (32 images, light and
  dark) in the example project; the example CI step runs them.

## 0.3.4

- Preserves the `0.2.x` one-argument `onHoldChanged` callback, Boolean
  overview/zoom/colorblind chrome properties, and presentation close/back
  overloads while adding richer hold-transition and close-reason APIs.
- Adds a complete native picker for SwiftUI and UIKit around one headless
  protocol-2 renderer session, while preserving the protocol-1 raw chart API.
- Refines the responsive native chrome with a bounded scrolling legend, fixed
  map/3D selector, compact required truth, measured renderer insets, and
  collision-free compact, large-phone, RTL, and wide decision layouts.
- Adds public native confirmation, GA/table, cart, checkout, accessibility,
  floor, section, 3D, seat-view, hold-lapse, loading/error/empty, attribution,
  and test-mode components.
- Adds native multi-price ticket-tier decisions whose exact tier and quoted
  price are applied to the runtime before confirmation and preserved through
  hold, cart, and the host-owned checkout handoff.
- Adds capability-gated targeted 3D navigation, focused-section previous/next
  state, panorama ownership, and deterministic immersive back navigation
  without confirming an inspected pending seat.
- Adds one-part builders and styles for the canonical 25-part matrix, plus
  scoped custom composition with a public controller and presentation model.
- Adds deterministic back handling, exact pending-seat projection, per-line
  cart removal with exact undo (including the last line), checkout
  single-flight, typed handoff rejection, hold ownership, foreground
  availability reconciliation, and in-place theme updates.
- Ships the canonical 37-locale catalog and design-token locks shared with the
  Flutter and React Native SDKs; supplemental iOS-only strings remain
  host-overridable English fallbacks until the shared catalog expands.
- Pins production to `seatlayer-js@0.71.5/mobile.html`, validates the complete
  protocol-2 handshake surface, and restricts WebKit messages to the configured
  main-frame HTTPS origin (including default-port normalization).
- Adds transferable WebKit prewarming, structured chart-load timing, native
  selection flight and haptics, and Reduce Motion/Reduce Transparency-aware
  presentation behavior.
- Adds portable protocol/schema/concept/behavior/helper fixtures, contract
  tests, and a generic UIKit example for the public picker APIs.
- Hardens command cancellation/timeouts, session-generation ownership,
  superseded loads, WebView teardown, prewarm mismatch/TTL cleanup, and
  retryable/fatal error recovery without adding production logging or
  persistent credential state.

## 0.2.0

- Loads the pinned hosted `seatlayer-js@0.66.0/mobile.html` document at the
  exact buyer-access allowed origin `https://cdn.seatlayer.io`.
- Separates `hostedWebVersion` (`0.66.0`) from the explicit legacy fixture
  version (`0.59.0`) and synchronizes the runnable demo to the verified fixture.
- Adds renewable private buyer access, origin-locked navigation, programmatic
  selection/category controls, exact-count validators, typed validity/access
  events, and fail-closed capability negotiation.
- Retains explicit local fixture loading for demo and contract-test pages.

## 0.1.2

- Updated the vendored buyer runtime to `seatlayer-js@0.59.0` (sha256
  `89bc29fb…`), pulled from the production CDN and byte-verified against the
  published release. Native buyers get the mobile buyer round — an
  always-visible price rail, a section locator that survives a filling cart, a
  venue overview that no longer covers the seats, accessibility filters that
  cannot be missed, and a checkout button clear of the home indicator — plus
  the engine fixes that reach every surface: section focus frames the section
  rather than its whole zone, the price filter dims section blocks and not only
  seats, and map type is sized for the device.

## 0.1.1

- Updated the vendored buyer runtime to `seatlayer-js@0.48.1` (sha256
  `b459b0b6…`) so native buyers receive the current mobile sizing, picker chrome,
  access-token, checkout, and duplicate-title fixes.
- Corrected the SDK and bundled-Web version metadata; 0.1.0 embedded Web 0.35.0
  while reporting 0.29.0, which also left CI red.

## 0.1.0

- Initial Swift Package for iOS 15 and later.
- Vendored SeatLayer web renderer with no separate CDN startup dependency.
- Versioned native bridge with async commands, delegate events, typed errors,
  protocol negotiation and forward-compatible payload decoding.
- Holds, best available, general admission, ticket tiers, floors, view modes,
  colorblind-safe rendering and zoom controls.
- UIKit example application and bridge unit tests.

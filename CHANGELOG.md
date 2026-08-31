# Changelog

## 0.3.0

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
  tests, a hosted UIKit demo, and redacted end-to-end validation evidence.
- Adds an optional DesiPass events → details → Book Now example that exchanges
  a launch-only development API key for short-lived mobile buyer access, then
  runs the real hosted native picker and typed checkout handoff without
  embedding or persisting credentials.
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

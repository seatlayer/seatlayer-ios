# Native picker validation — 2026-08-30

This record covers the iOS 0.3.0 release candidate on branch
`feat/native-picker`. It intentionally contains no event key, buyer token, hold
identifier, or other private checkout credential.

## Hosted runtime pin

- URL: `https://cdn.seatlayer.io/seatlayer-js@0.71.5/mobile.html`
- Runtime source tag: `v0.71.5`
- Runtime source commit: `4628345457409976a7fd477a3bdb41e2077c4b49`
- Runtime source tree: `846844b36ce3cf219b4df59e37934e39ad1bf2ea`
- `mobile.html`: 945 bytes, SHA-256
  `5c553fde192ca6cf1ffd73705fe5cc743b6731d4289c237fd960ed007ef7ac58`
- `seatlayer-buyer.js`: 1,049,235 bytes, SHA-256
  `ff420b05891d515eefb1aeca864893b5f8fd3c147983e6173146429a0e8ed04e`
- `mobile-bootstrap.js`: 103 bytes, SHA-256
  `4ae4bb0603e6fafd22089706e91539b7bbf1929cc1d4977f0c7fc4346b2d61c7`
- CDN response observed HTTP 200 with `cache-control: public,
  max-age=14400, s-maxage=31536000, immutable, no-transform` and
  `x-content-type-options: nosniff`.

## Automated checks

- Canonical design regeneration: passed. Tokens SHA-256
  `0667fdddab037b3f63eaf18b4ba099f477cb630edc93f9ea90f90862609e492f`;
  locale source SHA-256
  `9401509eb3704d0ec1d61d9ec8a6a4126b0d76ad8f0c3c204c890f24d9a55048`;
  component catalogue SHA-256
  `c091ace21b09f484dc516748d660f5d24ef4554826f8037ee30231addaa8e190`.
- Pure-helper fixtures: all 7 executed against shipping Swift projections.
- Behavior fixtures: all 15 stable IDs and complete outcome fields validated.
- Public concepts: exact 25-part enum and ten builder-context fields matched.
- Protocol: protocol-2 core/conditional handshake profile matched its portable
  lock; raw protocol-1 constants remained unchanged.
- Direct presentation checks: newest unanswered selection, confirmed-cart
  boundary, checkout single-flight/one callback, exact host rejection, and the
  six-layer back ladder passed.
- Complete Swift package suite: 104/104 passed with zero failures.
- Generic physical-device library build: passed for arm64, deployment target
  iOS 15.
- Generic iOS Simulator demo build: passed for arm64 and x86_64, including the
  external ready/custom SwiftUI/UIKit consumer examples.

## Hosted UIKit journey

The demo was built as a native `SeatLayerPickerViewController` host and run on
a 390×844 iPhone simulator against a controlled hosted test event and the
pinned production CDN runtime. The visual journey below was one uninterrupted
renderer session. After removing unnecessary event/expiry fields from demo
diagnostics, a second final-binary pass repeated selection → confirmation →
Continue → receipt and produced the redacted log result below.

Observed in one uninterrupted renderer session:

1. Ready negotiated protocol 2, test mode, iOS transport, with zero initial
   selection and no active hold.
2. The native accessibility sheet opened; colorblind-safe mode updated the map.
3. Venue 3D opened with native immersive chrome and returned to the map without
   remounting.
4. Venue overview focused one section and reported live remaining inventory.
5. Tapping one hosted seat opened the native confirmation card with section,
   row, seat, price, Select, and Cancel. Cart/checkout were not exposed to
   accessibility while the decision was pending.
6. The demo changed dark → light in place after selection. The selected seat
   remained selected and no second ready event occurred.
7. Select acknowledged the existing runtime selection locally. The compact
   cart exposed a separate accessibility Continue button.
8. Continue transferred one host-owned hold, invoked the typed callback exactly
   once, and delivered one line with the same displayed total.
9. The receipt displayed only “transferred to native host”; the opaque
   identifier remained absent from logs and screenshots.

Final redacted device-only screenshots:

- [Light native confirmation](native-picker-ios-confirmation-light.png)
- [Light compact cart and independent Continue action](native-picker-ios-cart-light.png)
- [Privacy-safe typed checkout receipt](native-picker-ios-checkout.png)
- [Native 3D chrome over the same renderer session](native-picker-ios-venue-3d.png)

The final-binary diagnostic sequence contained only:

- ready: protocol 2, test mode, iOS transport;
- selection: zero, then one exact inventory label;
- theme: light, with one selection preserved;
- hold: active, owner host;
- checkout: callback 1, transferred true, one line, total €60.

No second ready event appeared. No event key, bearer, opaque hold identifier,
or hold expiry was logged.

## UX comparison

The iOS phone composition follows the approved Flutter and React Native buyer
hierarchy: map remains the visual anchor; price/floor context is above it;
overview, zoom, fit, 3D, and accessibility controls remain reachable without
covering inventory; focused-section navigation sits above a compact cart; and
confirmation or GA/table decisions temporarily own interaction. iOS uses
native sheets, typography, Dynamic Type, safe areas, VoiceOver, haptics, and
44pt controls while retaining the shared design roles. Android should use its
native 48dp touch-target rule rather than copy the iOS metric.

## Known release exceptions

- This is a local release candidate. No public tag, push, or PR was created.
- Owner visual sign-off is an external release gate, not inferred from this
  technical validation.
- Supplemental iOS-only accessibility/disclosure copy uses English fallback
  unless the host overrides it; the canonical shared source still contains 37
  locale dictionaries.
- Optional native seat-view chrome, viewport insets, floor stack, chart-load
  trace, availability refresh, access-needs, and hold-selection behavior stays
  capability gated. Core picker operation does not assume them.
- Ordinary snapshots intentionally omit the opaque hold identifier even though
  an older component catalogue described it; only the typed checkout handoff
  contains it.

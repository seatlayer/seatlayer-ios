# Native picker validation — 2026-08-30

This is the release-quality evidence record for the local SeatLayer iOS
`0.3.0` native-picker candidate. The immutable iOS commit/tree/archive hashes
are recorded in the Android handoff after the local candidate commit is
created. Nothing was pushed, tagged, or submitted as a pull request.

No event key, bearer, customer identifier, opaque hold ID, or hold expiry is
recorded in this document, screenshots, or diagnostic excerpts.

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

## Automated and build gates

- Canonical design validation passed. Tokens SHA-256
  `0667fdddab037b3f63eaf18b4ba099f477cb630edc93f9ea90f90862609e492f`;
  locale source SHA-256
  `9401509eb3704d0ec1d61d9ec8a6a4126b0d76ad8f0c3c204c890f24d9a55048`;
  component source SHA-256
  `c091ace21b09f484dc516748d660f5d24ef4554826f8037ee30231addaa8e190`;
  exactly 37 locale dictionaries regenerated with no stale diff.
- Complete Swift package suite: **145/145 passed**, zero failures.
- Contract coverage inside that suite: protocol-2 core/conditional profile,
  additive snapshot schema, exact 25-part/ten-context public matrix, 15
  behavior fixtures, and 7 executable pure-helper fixtures.
- Direct closure coverage: tier quote/order/handoff, authored and fallback 3D
  positions, target/section/overview back, panorama wording/ownership,
  independent access-filter mutations, chart-trace timing, prewarm lifecycle,
  selection flight, Reduce Motion, haptic deduplication, Reduce Transparency,
  and status-bar contrast.
- Generic arm64 physical-device library target: built for iOS 15 with no SDK
  source warnings.
- Phone Simulator demo: built and installed from the final sources.
- iPad Simulator demo: built and rendered at 1024×1366 in wide mode.
- Clean external iOS 15 Simulator consumer source: typechecked while importing
  ready UIKit, headless UIKit, custom SwiftUI, builders, and styles.
- Deterministic fixture checks: JavaScript parsed successfully, Xcode project
  plist passed, resource loaded from the app bundle, and the live protocol-2
  handshake completed.
- `git diff --check`: passed after source implementation; repeated after final
  documentation/handoff generation.

## Hosted end-to-end journey

The final rebuilt `SeatLayerPickerViewController` ran on the 390×844 iPhone
Simulator against controlled hosted test inventory and the pinned production
CDN runtime.

Observed on the final binary:

1. protocol 2 negotiated in test mode over iOS transport;
2. the native map rendered the live hosted category/venue state;
3. venue 3D opened with native overview/camera chrome and returned without a
   second session;
4. Best Available created a server-backed test hold for Stalls SA seats 13–14;
5. the expanded native cart showed quantity 2, total €190, and a live 14:5x
   countdown;
6. Continue transferred ownership to the app;
7. the typed callback ran exactly once; and
8. the receipt showed two matching lines and €190, without the opaque ID.

The hosted event exposes single category prices. It cannot demonstrate an
Adult/Child choice, authored unselected 3D row target, or panorama state. Those
combinations were validated through the deterministic protocol closure below,
not misreported as hosted inventory proof.

## Deterministic protocol-2 closure

The validation-only page supplies authored states absent from the hosted
event, while the production Swift bridge/controller/native tree remains in
use. One uninterrupted phone journey passed:

1. Gold / Adult €100 / Child €60 tier card;
2. targeted A-12 3D without acknowledging the pending seat;
3. previous to A-11 with Previous disabled at the row boundary;
4. next to A-13 with Next disabled at the other boundary;
5. runtime-owned panorama open and close;
6. target → 3D overview → Seat map → the unchanged tier decision;
7. Child €60 local quote, then `picker.setSeatTier`, then confirmation;
8. cart `1 ticket · €60`, Continue €60, one host callback, and €60 receipt;
9. access sheet with Wheelchair 12, Companion 8, and step_free 25; and
10. applying Wheelchair returned to the map with active badge 1.

The accessibility title fits at phone width, tier rows expose selected state,
3D boundary buttons expose disabled state, and pending decisions remove map,
cart, and checkout from the assistive tree until answered.

## Wide composition

At 1024×1366, the map, floors, legend, test truth, map controls, and dock stay
inside the renderer column. The 320-point native rail owns section navigation,
cart line/removal, checkout, and attribution. Both the wide Adult/Child
decision and the confirmed-cart rail were visually inspected without overlap.

## Transferable prewarm timing

The prewarm host loads only the pinned page in a nonpersistent data store. It
contains no event, bearer, token provider, controller, or session state. The
same `WKWebView` is transferred once to the picker, then receives configuration
and credentials in memory.

All six samples used the final debug binary, same hosted event, same simulator,
and cache-hit CDN trace:

| Mode | Tap-to-ready samples | Median | Runtime/API notes |
| --- | --- | ---: | --- |
| Cold | 2195, 3461, 1395 ms | **2195 ms** | median API 311 ms; median host remainder 1308 ms |
| Prewarm | 930, 596, 543 ms | **596 ms** | pre-tap boot makes host remainder clamp to 0 ms |

The median reduction was **72.8%**. This is simulator debug evidence, not a
physical-device production SLA.

## Evidence files

- [Final hosted hold](native-picker-ios-hosted-final-hold-2026-08-30.jpeg)
- [Final hosted checkout](native-picker-ios-hosted-final-checkout-2026-08-30.jpeg)
- [Targeted native 3D](native-picker-ios-targeted-3d-closure-2026-08-30.jpeg)
- [Runtime-owned panorama](native-picker-ios-panorama-closure-2026-08-30.jpeg)
- [Child tier confirmed in cart](native-picker-ios-child-tier-confirmed-2026-08-30.jpeg)
- [Child tier checkout](native-picker-ios-child-tier-checkout-2026-08-30.jpeg)
- [Accessibility sheet](native-picker-ios-accessibility-sheet-2026-08-30.jpeg)
- [Accessibility applied](native-picker-ios-accessibility-applied-2026-08-30.jpeg)
- [Wide tier decision](native-picker-ios-wide-tier-2026-08-30.png)
- [Wide cart/checkout rail](native-picker-ios-wide-cart-2026-08-30.png)
- [Hosted prewarmed overview](native-picker-ios-prewarmed-overview.png)

## Known release exceptions and open external gates

- No public tag, push, or pull request was authorized or created.
- Owner visual/API approval and publication authorization remain external.
- The hosted `0.71.5` runtime does not yet emit all additive 3D
  target/neighbour/focused-section fields; iOS has exact capability-gated
  support and a bounded older-runtime fallback.
- A controlled hosted multi-tier event is still required for live Adult/Child
  inventory proof.
- A hosted event with target panorama content is still required for real
  panorama pixels/gestures and unavailable-state proof.
- Physical-device release-mode performance remains open if a formal SLA is
  required.
- Supplemental iOS-only disclosure/accessibility copy uses host-overridable
  English fallback when the canonical 37-locale source has no shared key.
- Performance Groups and Seasons require separate native product contracts;
  single-event tier support does not cover them.

See [iOS closure parity](native-picker-closure-parity-2026-08-30.md) and
[security and hold ownership](native-picker-security.md).

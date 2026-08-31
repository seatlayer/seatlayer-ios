# Native picker validation — final audit 2026-08-31

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
- Fresh CDN response: HTTP 200, `Content-Type: text/html`,
  `X-Content-Type-Options: nosniff`, and
  `Cache-Control: public, s-maxage=31536000, max-age=3600, immutable, no-transform`.

## Automated and build gates

- Canonical design validation passed. Tokens SHA-256
  `0667fdddab037b3f63eaf18b4ba099f477cb630edc93f9ea90f90862609e492f`;
  locale source SHA-256
  `9401509eb3704d0ec1d61d9ec8a6a4126b0d76ad8f0c3c204c890f24d9a55048`;
  component source SHA-256
  `c091ace21b09f484dc516748d660f5d24ef4554826f8037ee30231addaa8e190`;
  exactly 37 locale dictionaries regenerated with no stale diff.
- Complete Swift package suite: **171/171 passed**, zero failures.
- Contract coverage inside that suite: protocol-2 core/conditional profile,
  additive snapshot schema, exact 25-part/ten-context public matrix, 15
  behavior fixtures, and 7 executable pure-helper fixtures.
- Direct closure coverage: tier quote/order/handoff, authored and fallback 3D
  positions, target/section/overview back, panorama wording/ownership,
  independent access-filter mutations, chart-trace timing, prewarm lifecycle,
  selection flight, Reduce Motion, haptic deduplication, Reduce Transparency,
  and status-bar contrast.
- Deterministic launch states cover loading, retryable error, fatal error,
  available inventory with an empty cart, sold out, sales closed, active hold
  countdown, and foreground-reconciled hold lapse.
- Generic arm64 physical-device library target: built for iOS 15 with no SDK
  source warnings.
- Phone Simulator demo: built and installed from the final sources.
- iPad Simulator demo: built and rendered at 1024×1366 in wide mode.
- Clean external iOS 15 SwiftPM executable and Xcode application: built while
  importing ready UIKit, headless UIKit, ready/custom SwiftUI, styles, normal
  and throwing builders, retained callbacks/options, and legacy/new close/back
  APIs using only `import SeatLayer`.
- Deterministic fixture checks: JavaScript parsed successfully, Xcode project
  plist passed, resource loaded from the app bundle, and the live protocol-2
  handshake completed.
- `git diff --check`: passed after source implementation; repeated after final
  documentation/handoff generation.
- Swift package API break diagnostic against `origin/main`: no breaking
  changes detected.

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
8. an explicit picker-owned hold retained Child and €60, then the cart,
   Continue, one host callback, and the €60 receipt retained the same tier;
9. dedicated countdown and foreground-reconciled lapse states exercised the
   native countdown, lapse notice, and recover action;
10. access sheet with Wheelchair 12, Companion 8, and Step-free 25; and
11. applying Wheelchair, Hide limited-view, and colourblind-safe independently
    returned to the map with active badge 3.

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
and cache-hit CDN trace. Each prewarm sample also logged `prewarm ready=true`
and `hostMs=0`; the runtime's `load=cold` field describes its chart render and
does not mean the page-transfer pool was bypassed.

| Mode | Tap-to-ready samples | Median | Runtime/API notes |
| --- | --- | ---: | --- |
| Cold | 2622, 2459, 2652 ms | **2622 ms** | API 281, 280, 288 ms; host 1537, 1532, 1771 ms |
| Prewarm | 458, 509, 596 ms | **509 ms** | API 303, 314, 290 ms; host 0 ms in all three |

The median reduction was **80.6%**. This is simulator debug evidence, not a
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
- [Loading, dark](native-picker-ios-loading-dark-2026-08-31.png)
- [Empty inventory, light](native-picker-ios-empty-light-2026-08-31.png)
- [Retryable error, light](native-picker-ios-retryable-error-light-2026-08-31.png)
- [Fatal error, dark](native-picker-ios-fatal-error-dark-2026-08-31.png)
- [Sold out, dark](native-picker-ios-sold-out-dark-2026-08-31.png)
- [Sales closed, light](native-picker-ios-sales-closed-light-2026-08-31.png)
- [Active hold countdown](native-picker-ios-hold-countdown-dark-2026-08-31.png)
- [Foreground-reconciled hold lapse](native-picker-ios-hold-lapsed-dark-2026-08-31.png)
- [Large Dynamic Type and Arabic RTL](native-picker-ios-large-type-rtl-light-2026-08-31.png)
- [In-place light theme continuity](native-picker-ios-theme-continuity-light-2026-08-31.png)
- [Wide tier decision](native-picker-ios-wide-tier-2026-08-30.jpeg)
- [Wide cart/checkout rail](native-picker-ios-wide-cart-2026-08-30.jpeg)
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
- A paired iPhone 16 Pro Max on iOS 26.6.1 exposed Developer Mode, DDI, launch,
  and installation services. The Release app and generic device SDK both
  compiled, but physical installation is externally blocked: the repository
  intentionally disables demo signing, this Mac has no Xcode account or
  development provisioning profile for `io.seatlayer.SeatLayerDemo`, and iOS
  rejected the unsigned app with `0xe800801c`. No physical-device smoke or SLA
  is claimed until an authorized profile is supplied.
- Supplemental iOS-only disclosure/accessibility copy uses host-overridable
  English fallback when the canonical 37-locale source has no shared key.
- Performance Groups and Seasons require separate native product contracts;
  single-event tier support does not cover them.

See [iOS closure parity](native-picker-closure-parity-2026-08-30.md) and
[security and hold ownership](native-picker-security.md).

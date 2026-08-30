# iOS picker closure parity — 2026-08-30

## Verdict

The iOS `0.3.0` single-event native picker now covers every applicable gap in
the final React Native + Flutter closure audit: exact ticket tiers, additive
venue-3D state, authored same-row stepping, target/overview/map depth,
panorama ownership, inventory-backed access filters, optional load telemetry,
true transferable prewarm, native motion/haptics, and phone/wide composition.

The result is not a claim that the current hosted event contains every state.
The pinned hosted runtime and real test inventory prove the production bridge,
2D venue, venue-3D overview, best-available hold, host-owned handoff, and
checkout callback. A deterministic protocol-2 page proves Adult/Child,
authored target/neighbour boundaries, panorama return, and multiple access
groups that the hosted event does not supply. Both paths run through the real
`SeatLayerView`, bridge client, controller, presentation model, and native
SwiftUI/UIKit component tree.

Performance Groups and Seasons are not single-event picker features. They
remain separate native products requiring multi-performance snapshots, atomic
group/season holds, recovery, and checkout contracts; this SDK does not invent
wrappers around contracts that do not exist.

## Audited closure matrix

| Audited behavior | iOS implementation | Validation | Status |
| --- | --- | --- | --- |
| 2D overview, section, venue | Typed `focusSection`, `overview`, `setRung`, and one-step Back use runtime snapshots without remounting the renderer. | Hosted venue journey and presentation tests. | Covered |
| Adult/Child ticket tier | Native compact and wide confirmation render authored tiers and immediate quotes. Confirmation sends `picker.setSeatTier` before local acknowledgement; failure leaves the card open. | Fixture visibly changed Gold Adult €100 → Child €60, then cart and checkout stayed €60; ordering is asserted in `PickerPresentationTests`. | Covered; hosted event is single-price |
| First venue-3D activation | Native chrome overlays renderer-owned pixels and is exact-capability gated. Overview exposes only supported navigation/camera actions. | Real hosted venue-3D overview plus deterministic fixture. | Covered |
| Independent 3D section depth | Snapshot decodes `view3DFocusedSectionId`; focused target/section returns to 3D overview before Map. | Snapshot, immersive, and presentation tests. | Covered; hosted `0.71.5` does not yet emit every additive field |
| Explicit 3D seat target | Snapshot decodes target seat plus authored previous/next IDs. Target may be unselected. Old runtimes get only a bounded selection-order fallback. | Fixture A-12 → A-11 disabled Previous and A-12 → A-13 disabled Next; pure immersive tests include an unselected target. | Covered |
| Target controls and camera | Target: Back to venue, previous, View from here, next, recenter. Overview: Seat map, rotate/move, zoom out, fit, zoom in. | Phone simulator pixels and accessibility tree; command-gate tests. | Covered |
| Inspection is not confirmation | Entering 3D or panorama never acknowledges the pending seat or accepts its default tier. The decision returns unchanged after immersive exit. | Simulator returned from panorama → target → overview → map to the original Adult/Child decision; back-order regression test. | Covered |
| Immersive chrome ownership | 2D dock/floors/access/map controls yield to 3D or panorama; cart and required commercial truth remain. Panorama keeps its renderer-owned close/gesture surface. | Fixture and hosted 3D; `PickerImmersiveTests`. | Covered |
| Panorama / 360 | `picker.openSeatView` uses the explicit target ID. Native shows runtime wording while web owns pixels, close, and gestures. Native Escape/Command-[ are unclaimed while panorama is active. | Fixture opened and closed A-12 panorama, restoring the same target and pending tier decision. | Covered; hosted real panorama state unavailable |
| Dynamic access/filter truth | Sheet derives ordered groups and counts from `map.accessNeeds`; each filter family requires its exact capability/command and mutates independently. | Fixture showed Wheelchair 12, Companion 8, step_free 25; applying Wheelchair returned with badge 1. Hosted event also passed its smaller truthful taxonomy. | Covered |
| Floors | Exact `floor-stack-v1` gate, All Floors sentinel, phone strip, and wide selector. | Two-floor fixture and iPad render; controller tests. | Covered |
| Motion, haptics, accessibility | Generated motion is ≤420 ms and Reduce Motion aware; selection flight targets the cart; haptics deduplicate selection/hold events; Reduce Transparency becomes opaque; system status-bar contrast follows theme/immersive state. | Motion/haptic, flight, transparency, and system-appearance tests; phone visual review. | Covered |
| Loading telemetry | Additive chart trace preserves unknown fields, merges native tap-to-ready, buffers the runtime's pre-ready success edge, and never logs identifiers by default. | Six focused tests plus six hosted samples. | Covered when advertised |
| Transferable prewarm | A page-only, credential-free, nonpersistent `WKWebView` is transferred once into the real picker; TTL, mismatch, cancellation, memory pressure, and expiry release it. | Four ledger tests and three hosted prewarm launches. | Covered |
| Ready/custom/headless composition | Ready SwiftUI, ready UIKit, scoped custom SwiftUI, and headless UIKit use one controller/session/renderer. Canonical 25 whole-part builders include `venue3D` and `seatViewChrome`. | 25-part contract test, external consumer typecheck, phone and iPad builds. | Covered |
| Performance Groups / Seasons | Separate multi-performance products; not additive tiers. | No portable native contract exists to implement or validate. | Separate product backlog |

## End-to-end evidence

### Pinned hosted inventory

On the final rebuilt phone binary, the immutable CDN runtime `0.71.5`
negotiated protocol 2 in test mode over iOS transport. Best Available created a
real hosted test hold for Stalls SA seats 13–14, quantity 2, total €190, with a
visible countdown. Continue transferred ownership to the app and invoked the
typed checkout callback exactly once with the same two lines and €190 total.
The receipt exposes no opaque identifier.

The same hosted runtime also rendered the venue-3D overview and returned to
the map without creating another session. The current event does not contain a
multi-tier seat or expose the new target/neighbour/panorama state, so it cannot
honestly prove those combinations.

### Deterministic protocol closure

The bundled validation-only page advertises the complete required protocol-2
surface plus optional native-seat-view, viewport-insets, floor-stack,
chart-load, availability-refresh, access-needs, hold-selection, and
colorblind-safe capabilities. One uninterrupted journey visibly proved:

1. Gold / Adult €100 and Child €60 native tier choices;
2. targeted A-12 3D inspection without confirming the seat;
3. A-11 left boundary and A-13 right boundary from authored row neighbours;
4. runtime-owned panorama open/close with native wording;
5. target → venue-3D overview → Seat map → original tier decision;
6. Child €60 applied before confirmation and retained by cart;
7. host-owned checkout transfer with one callback and €60 line item; and
8. runtime-authored access groups, Wheelchair application, and active badge 1.

### Phone and wide UX

- 390×844: compact confirmation, 3D/panorama, access sheet, compact cart, real
  hosted hold, and both €60/€190 receipts were visually reviewed.
- 1024×1366: the map owns the renderer column; the 320-point rail owns section
  navigation, cart line/removal, attribution, and full-width Continue. The
  wide tier decision remains centered inside the renderer column and does not
  overlap the rail.

## Hosted timing

All samples used the same final debug binary, simulator, hosted event, CDN
runtime, and cache-hit trace. Values are tap-to-ready milliseconds.

| Mode | Samples | Median | Median host remainder |
| --- | --- | ---: | ---: |
| Cold app/picker | 2195, 3461, 1395 | **2195 ms** | **1308 ms** |
| Transferable prewarm | 930, 596, 543 | **596 ms** | **0 ms** |

The measured median tap-to-ready reduction is **72.8%**. A prewarmed runtime
can report `bootMs` greater than post-tap time because document boot began
before picker installation; native `hostMs` is therefore clamped to zero.
These are simulator debug measurements, not a physical-device production SLA.

## Remaining external or product gates

- Roll the additive 3D target/neighbour/focused-section fields into a hosted
  runtime/event and repeat the target/panorama journey on real geometry.
- Validate real Adult/Child inventory when a controlled multi-tier event is
  available.
- Run release-mode measurements on supported physical phones if a performance
  SLA is required.
- Obtain owner visual/API approval and explicit publication authorization.
- Define Performance Group and Season native contracts before implementing
  those separate products.

No public tag, push, or pull request was created.

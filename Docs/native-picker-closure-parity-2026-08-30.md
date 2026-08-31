# iOS picker independent closure matrix — audited 2026-08-31

## Verdict

SeatLayer iOS `0.3.0` now has the complete applicable single-event picker
surface. The independent pass found and fixed source-compatibility, lifecycle,
cart undo, tier persistence, mixed-currency, truthful empty-state,
accessibility-label, compact-layout, and large-Dynamic-Type defects. Raw
`SeatLayerView` remains the protocol-1 API; the native picker is additive and
negotiates protocol 2.

Hosted inventory and deterministic fixture evidence are intentionally separate.
The hosted lane proves the pinned CDN, real controlled inventory, a real test
hold, and one typed host-owned checkout transfer. The fixture proves exact
multi-tier, authored 3D-neighbour, panorama, access-group, floor, and edge-state
combinations that the available hosted event does not publish. Fixture evidence
is never described as live inventory.

`Covered` means the final source plus a direct automated, build, or interactive
check proves the row. `Gap fixed` means this audit changed the implementation
and then repeated a direct check. `External proof required` identifies a
working capability whose remaining proof needs inventory or hardware outside
the repository. `Separate product` is not part of the single-event picker.

## Complete buyer-feature matrix

| Acceptance row | Implementation and direct evidence | Status |
| --- | --- | --- |
| Protocol-2 negotiation, capabilities, schema, revision/session ordering, unknown-field tolerance, typed errors | Separate raw/picker bridge profiles; exact protocol/schema JSON; stale/foreign snapshots drop; unknown values remain additive; retryability is typed. `BridgeProfileTests`, `NegotiationTests`, `PickerSnapshotTests`, and `UnknownToleranceTests` pass. | Covered |
| Loading, retryable/fatal error, empty, sold-out, sales-closed truth | Native states distinguish retryable and fatal errors. Empty cart remains usable when inventory is available; no-inventory requires positive availability evidence; sales-closed and sold-out remain distinct. The closure fixture has `loading`, `retryable-error`, `fatal-error`, `empty`, `sold-out`, and `sales-closed` launch states. | Gap fixed |
| 2D overview, section focus, venue return, zoom/fit/rung, map controls | Typed controller commands and one mounted renderer preserve camera/session state. Hosted and fixture map journeys plus controller/presentation tests cover focus, overview, rung, fit, and zoom. | Covered |
| Header, price/category legend, category filters, test mode, attribution | Public native components use snapshot truth. Required test-mode and attribution components are outside the builder matrix and remain visible even when host builders throw. | Covered |
| Floor selector, phone strip, All Floors gate, wide floor UI | `floor-stack-v1` gates All Floors; exact floor selection remains available without it. Phone strip and wide selector were inspected with the two-floor fixture; controller gates are tested. | Covered |
| Best Available | Ready native form sends quantity plus optional category and zone through the runtime before reflecting cart/hold state. Hosted controlled inventory produced the real test hold. | Covered |
| Seat confirmation and pending-versus-confirmed cart projection | Newest unanswered seat is excluded structurally from confirmed lines and totals; cancellation removes the exact runtime label. Direct projection and presentation tests pass. | Covered |
| Multi-price Adult/Child or equivalent tiers | Compact and wide confirmation show runtime-authored tier order and localized money. Fixture shows Adult €100 then Child €60. | Covered |
| `setSeatTier` accepted before local confirmation | `confirmPending(tierId:)` awaits `picker.setSeatTier`; failure keeps the decision open. Fixture visibly reports runtime acceptance before confirmation; controller/presentation tests assert command ordering. | Covered |
| Chosen tier ID, name, and price survive cart, hold, Continue, checkout | Authoritative cart/handoff decoding preserves `tierId`, `tierName`, unit price, currency, and quantity. The fixture retains Child/€60 through every boundary and the receipt line. | Gap fixed |
| General admission and variable-table prompts with exclusive ownership | One presentation owner grants one GA/table lease; checkout and competing decisions remain blocked until resolution. Behavior fixture and presentation tests pass. | Covered |
| Cart quantity, totals, mixed currency, dense runs, per-line removal, retry, undo | Structural line keys, exact quantities, no invented mixed-currency aggregate, expandable dense runs, guarded mutations, recoverable errors, and four-second exact undo are public. Audit fixed last-line undo and exact tier/table/GA restoration. | Gap fixed |
| Hold countdown, lapse, foreground reconciliation, picker/host ownership, process recovery | Snapshot-derived countdown/lapse, lifecycle outcome then optional refresh/synchronize, explicit picker/host owner, and caller-supplied resume identifier are implemented. No credential or hold recovery is persisted by the SDK. | Covered |
| Single-flight checkout, exactly one callback, exact rejection, opaque ID, host ownership | Repeated Continue joins one task. The runtime handoff precedes one observation/host handler; a throwing handler rejects that exact ID. Ordinary snapshots omit it and demo evidence redacts it. | Gap fixed |
| Runtime-authored access groups/counts, independent filters, colorblind mode | Exact capability/command gates; zero-count truth remains visible; stale active values drop; access, limited-view, and colorblind mutations remain independent. Fixture shows Wheelchair 12, Companion 8, Step-free 25. | Gap fixed |
| Dynamic Type, VoiceOver order, focus restoration, contrast, 44pt targets | Scaled fonts, flexible action rows, blocking modal ownership, explicit focus return, semantic traits/order, contrast-aware palettes, and 44pt minimums are implemented. Audit refactored the compact confirmation for accessibility sizes and removed required-truth overlap. | Gap fixed |
| Venue 3D overview, explicit target, authored neighbours and disabled boundaries | Runtime fields decode explicit target/focused section/previous/next. Fixture proves A12, A11 disabled-Previous, and A13 disabled-Next; older runtimes get a bounded non-authored fallback. | Covered |
| Panorama/360 ownership, runtime close and gestures | Runtime owns pixels, close, and gestures; native owns capability-gated caption/actions and does not intercept Escape while panorama is active. Fixture open/close returns to the same target. | Covered |
| Inspection is not selection | Opening venue 3D or panorama never acknowledges the pending seat or accepts a default tier. The audit fixed pending-tier ownership so renderer transitions cannot reset Child to Adult. | Gap fixed |
| Back: panorama → target → 3D overview → map → pending decision | Renderer immersive depth and native presentation ladder each consume one layer. The uninterrupted fixture journey returns to the original unanswered Child decision. | Covered |
| Light/dark/auto continuity without renderer remount, camera loss, selection loss | Theme changes mutate semantic native/map roles on the same controller, WebView, session, and selection. The final in-place fixture run retained A-12 with one chart-load and one ready event while native chrome and status-bar contrast changed. | Covered |
| Status-bar contrast and system appearance | Ready UIKit owns and invalidates status-bar style while visible; immersive surfaces force legible light foreground and restore normal resolved appearance. Direct system-appearance tests pass. | Covered |
| All 37 locales, host overrides, fallback, currency, Dynamic Type, RTL | Exact BCP-47 → base language → English; 37 locked dictionaries; configuration and explicit overrides merge deterministically; injected formatting falls back safely to locale-aware `NumberFormatter`. Arabic RTL/long-copy/large-type fixture and money tests cover the added boundaries. | Gap fixed |
| Compact phone and wide/iPad without clipping, overlap, hidden checkout, duplicate AX ownership | Adaptive layout shares one renderer. Audit measures the compact cart instead of reserving a stale constant and makes decision details scroll while actions remain reachable. Phone and 1024×1366 wide journeys inspect pixels and accessibility trees. | Gap fixed |
| Motion, selection flight, haptics, Reduce Motion, Reduce Transparency | Generated motion stays within the 420ms lock; flight targets compact cart or wide rail; haptics deduplicate state transitions; Reduce Motion removes generated flight; Reduce Transparency uses opaque surfaces. Direct tests pass. | Covered |
| Transferable page-only WebView prewarm, TTL, one-time transfer, cleanup, no event/credential | Nonpersistent page-only host, exact URL match, bounded finite TTL, generation ownership, one-time consume, cancellation, memory warning, termination, navigation/process failure cleanup. Audit fixed mismatch and detached-host cleanup. | Gap fixed |
| Chart-load trace, pre-ready buffering, privacy, tap-to-ready | Capability plus event gate; successful pre-ready trace buffers until native ready timing exists; unknown fields stay in `raw`; no automatic log/transmit. Six direct tests and hosted timing samples cover it. | Covered |
| Background/foreground, memory pressure, cancellation, close, teardown | Direct SwiftUI observes scene phase; the ready UIKit host observes application notifications because embedded hosting controllers do not reliably receive scene-phase changes. Both use one reconciliation policy. The final simulator background/foreground run produced the lapse notice and exact A-12 recovery. Pending bridge commands/waiters, load generations, prewarm, WebView scripts/navigation, and controller tasks cancel deterministically. | Gap fixed |

## Public flexibility and compatibility matrix

| Acceptance row | Evidence | Status |
| --- | --- | --- |
| Ready SwiftUI picker | `SeatLayerPicker` composes the public components and required truth around one renderer. Demo and clean external executable compile it. | Covered |
| Ready UIKit host | `SeatLayerPickerViewController` hosts the same SwiftUI tree and exposes controller, presentation, appearance update, and back APIs. | Covered |
| Theme, strings, options, styles, callbacks, layout | All are public initializer inputs; callbacks cover ready/load/selection/validity/hold/access/error/theme/navigation/Continue. Phone-specific map-control placement is additive to legacy Boolean gates. | Gap fixed |
| Whole-component replacements/builders | Exactly 25 part IDs; missing or throwing builder renders safe `defaultContent`. Required attribution/test truth is not replaceable. | Gap fixed |
| Custom SwiftUI in one public scope | `SeatLayerPickerScope` provides one controller and presentation owner; standalone components and scoped default map share them. External executable compiles the path. | Covered |
| Headless/custom UIKit seam | Public controller/snapshot/presentation plus `SeatLayerPickerMapView` and `SeatLayerPickerMapViewController`; no raw envelope or private SDK type is required. | Covered |
| Exact 25 ownership points and ten context fields | `SeatLayerPickerPart.allCases`, builders, code, and `picker-public-concepts.v1.json` agree on 25. Context is exactly part, snapshot, controller, presentation, themeMode, theme, strings, options, style, defaultContent. | Covered |
| One controller, presentation owner, runtime session, renderer | Scope owns stable controller/presentation objects; ready/custom UIKit and SwiftUI reuse the same map host rather than mounting a second renderer. | Covered |
| Clean external application | Separate iOS 15 Swift package executable compiles ready/custom SwiftUI, ready/headless UIKit, styles, normal and throwing builders, legacy and additive callbacks, and legacy/new back APIs using only `import SeatLayer`. | Covered |
| Raw `SeatLayerView` compatibility | Raw profile remains protocol 1. No public raw member was removed; original hold callback arity, Boolean chrome properties, and close/back overloads are retained. Full raw/bridge tests and the external compatibility target pass. | Gap fixed |

## Direct Web, Flutter, and React Native source comparison

This audit read the referenced implementations rather than treating compilation
as parity. No source in those repositories was changed.

| Reference read | Verified flexibility boundary | iOS disposition |
| --- | --- | --- |
| Web/runtime `4628345457409976a7fd477a3bdb41e2077c4b49` (`seatlayer-js@0.71.5`) | Protocol-2 snapshots and commands remain the authority for inventory, selection, pricing, floors, access filters, holds, checkout, 3D state, and panorama pixels/gestures. Native code may compose chrome but may not invent or fork that truth. | The picker controller serializes those commands and accepts only session/revision-valid snapshots. One `SeatLayerPickerMap` owns the renderer; native 3D/panorama controls are capability-gated and never acknowledge selection. |
| Flutter `848be0c3dfadaba5efcda04d951a436cbd983e6f` | Ready picker/page/dialog, theme, strings, options, styles, callbacks, a public scope, standalone widgets, and whole-part builders are public. Its current `SeatLayerPickerBuilders` declares 24 properties, with `priceRail` and `legend` aliasing one part: 23 distinct slots. Floor selector and hold-lapse are public default widgets but are not builder slots at that commit. | iOS covers every equivalent layer and does not inherit the smaller slot set. `floorSelector` and `holdLapse` are replaceable, producing the canonical 25 ownership points, while required truth remains outside the builder set. |
| React Native `9046330090d86b8c7e88f8967a763c9af05a8261` | Ready picker/modal, theme/options/locale/strings, typed aesthetic styles, callbacks, public scope/hooks, standalone parts, safe builder fallback, and the exact 25-part union are public. Aliases do not create extra ownership points. | iOS matches all 25 canonical points and makes the equivalent live values explicit in the exact ten-field Swift builder context. It additionally exposes ready UIKit plus controller/state/map seams for UIKit-only composition. |
| Clean external iOS 15 executable | A consumer must import ready/custom SwiftUI, ready/headless UIKit, styles, normal and throwing builders, retained callbacks/options, and old/new close/back overloads without SDK-private types. | The separate executable builds successfully using only `import SeatLayer`; SwiftPM's breakage diagnostic against `origin/main` reports no removed public API. |

## Evidence lanes

### Hosted production-runtime lane

The pinned `seatlayer-js@0.71.5/mobile.html` lane uses controlled hosted test
inventory. It proves protocol 2, runtime-authored inventory, Best Available,
native confirmation/cart, a real test hold, exactly one typed checkout handoff,
and a host-owned receipt. The final evidence record contains the exact line,
quantity, currency, total, callback count, and tap-to-ready samples while
excluding credentials and the opaque hold identifier.

The available hosted event is single-price and does not emit every additive
target/neighbour/panorama field. A controlled hosted multi-tier event and a
hosted target with panorama content are still needed to repeat those exact
combinations against live inventory.

| Hosted-only proof | Status |
| --- | --- |
| Real Adult/Child inventory and tier mutation | External proof required |
| Real authored target/neighbour/panorama content | External proof required |
| Release-mode performance on a connected physical device | External proof required — paired iPhone 16 Pro Max/iOS 26.6.1 has Developer Mode and DDI available, and Release compilation passes, but no Xcode account/profile exists for the demo bundle ID; unsigned installation is rejected with `0xe800801c`. |

### Deterministic closure lane

`Example/SeatLayerDemo/Resources/picker-closure-fixture.html` is credential-free
and never live inventory. It proves Adult €100 / Child €60 ordering; Child tier
acceptance and persistence; A11/A12/A13 authored boundaries; panorama
open/close; pending-decision restoration; runtime-authored accessibility groups
and independent mutations; two floors; wide layout; explicit picker-owned hold,
cart, Continue, and one typed €60 checkout callback. Dedicated
`hold-countdown` and foreground-reconciled `hold-lapsed` launch states expose
the real native countdown, lapse notice, and recovery action.

## Performance Groups and Seasons

The pinned web runtime exports both a fixed-inclusion Performance Group picker
and a fixed Renewable Season private-beta surface. They are browser products,
not single-event ticket tiers, and neither publishes a versioned protocol-2
native profile that the mobile SDKs can implement consistently.

| Separate product | Required portable contract before native wrappers | Status |
| --- | --- | --- |
| Performance Groups | Native buyer-session audience/origin and renewal/adoption; versioned group descriptor and aggregate/per-performance snapshots with revisions; selection-mode and allocation commands; atomic caller-stable hold operation, recovery, adoption, release, extend, and process recovery; exact checkout handoff plus server inspect/book/cancel; native locale/accessibility/UX evidence. | Separate product |
| Seasons | Native buyer-session audience; immutable plan/occurrence and availability snapshots with revisions; same-seat inventory rights; caller-stable operation and partial-terminal recovery; hold/release; Season-only checkout; renewal-intent, renewal, and cancellation semantics; native locale/accessibility/UX evidence. | Separate product |

No public tag, push, or pull request is part of this audit.

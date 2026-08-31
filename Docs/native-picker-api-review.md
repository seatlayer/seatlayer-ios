# Native picker API review

This note separates SeatLayer product semantics, which Android should mirror,
from SwiftUI/UIKit mechanics, which Android should translate rather than copy.

## Shared product semantics

- A **picker** is the complete buyer flow; a **map** is the renderer-owned venue
  surface. “Headless” describes the product architecture and is not a public
  type prefix.
- One scope owns one runtime session, one authoritative controller, one local
  presentation state owner, and one mounted renderer.
- Snapshots are immutable, session-scoped, additive, and revision ordered.
- Selection, prices, quantities, availability, validity, and hold ownership
  come only from runtime snapshots.
- Confirmation is a local acknowledgement of an already-selected seat.
  Cancellation removes the exact inventory label. The pending item is excluded
  from confirmed cart totals.
- A ticket-tier choice is an authoritative runtime mutation before local
  acknowledgement. Immediate native quotes are presentation only; cart and
  checkout truth comes back from the snapshot/handoff.
- 3D and panorama are inspection surfaces. Entering either never confirms a
  pending seat. Target, row neighbours, focused 3D section, and null boundaries
  are runtime-authored additive state; selection order is only a bounded
  compatibility fallback for an older runtime.
- Immersive pixels, gestures, and panorama close belong to the renderer.
  Native owns capability-gated chrome. Ordinary 2D navigation yields while the
  immersive owner is active, but cart and required commercial truth remain.
- GA and variable-table decisions are exclusive prompts. Checkout is disabled
  while either a prompt or confirmation is unanswered.
- Checkout is single-flight and yields one typed transfer. A throwing host
  callback rejects that exact transfer. Close releases picker-owned inventory
  and preserves host-owned inventory.
- Back consumes one native layer: prompt → cart → confirmation → section →
  venue → close. Renderer-owned immersive depth resolves panorama → target →
  3D overview → map before the unchanged pending decision is shown again.
- Empty state requires explicit sales-closed/all-unavailable evidence; absence
  of catalog evidence is still loading/map, never invented sold-out state.
- Required attribution and test-mode indication cannot be disabled or replaced.
- The public customization contract is the canonical 25 whole parts, the ten
  builder-context fields, and the default-content fallback rule recorded in
  `Contracts/picker-public-concepts.v1.json`. Missing and throwing builders
  both fall back to the safe canonical content.
- Theme changes update native chrome and renderer semantic roles without a new
  runtime session. Locale lookup is exact BCP-47 → language → English.
- Foreground availability reconciliation blocks stale action assumptions and
  never restores credentials from persistent storage.
- Prewarm is a one-time transfer of a page-only renderer host. It may retain a
  URL and expiry metadata, never event configuration, credentials, selection,
  or hold state. Mismatch, expiry, cancellation, memory pressure, and process
  termination release it.
- Chart-load telemetry is optional, capability/event gated, additive, and
  privacy neutral. Platform SDKs merge their own tap-to-ready boundary without
  logging or forwarding the trace automatically.

## SwiftUI/UIKit mechanics

- `SeatLayerPicker` is the SwiftUI ready tree; Android should use its own
  declarative ready container.
- `SeatLayerPickerScope` uses SwiftUI environment objects; Android should use
  platform lifecycle/state holders with equivalent one-scope ownership.
- `SeatLayerPickerPartBuilder` returns `AnyView` synchronously and receives
  `defaultContent`; Android should use its native composable/view replacement
  type while preserving the same part IDs, context semantics, and fallback.
- `SeatLayerPickerStyles` stores Swift-native hex-backed visual modifiers;
  Android should translate sizes to dp/sp and enforce 48dp touch targets rather
  than copy iOS's 44pt rule.
- `SeatLayerPickerViewController` hosts SwiftUI inside UIKit. Android should
  provide a ready Fragment/View/Compose host appropriate to its UI stack.
- `SeatLayerPickerMapView` wraps `WKWebView`; Android should use its secure
  WebView bridge with the same origin, session, destruction, and nonpersistent
  credential invariants.
- `SeatLayerPickerPrewarming` pools the exact UIKit `WKWebView` and transfers it
  into the later picker. Android should use a lifecycle-safe WebView holder or
  equivalent transfer mechanism; it should not copy UIKit ownership or pretend
  that an HTTP cache warmup is the same feature.
- `UIKeyCommand`, `accessibilityPerformEscape`, status-bar style, Reduce
  Transparency materials, SwiftUI transitions, and UIKit haptic generators
  are iOS mechanics. Android should map the shared outcomes to predictive Back,
  TalkBack escape/close semantics, system-bar contrast, reduced animation,
  opaque high-contrast surfaces, and platform haptics.
- `@MainActor`, `ObservableObject`, `@Published`, `scenePhase`, UIKit
  containment, and VoiceOver identifiers are implementation details. Android
  should map them to main-thread state flow, lifecycle callbacks, view/Compose
  ownership, and TalkBack semantics.

## API disposition

The iOS `0.3.0` surface is additive to protocol-1 `SeatLayerView`. In
particular, the existing one-argument `onHoldChanged`, Boolean
overview/zoom/colorblind properties, and one-handler close/back overloads are
retained; richer transition/reason and compact-phone controls are additions.
SwiftPM's API-breakage diagnostic against `origin/main` reports no breaking
changes, and a separate iOS 15 executable imports both the retained and new
signatures without `@testable` or SDK-private types.
The concept names and 25 part identifiers are frozen for Android Gate 0
review. Platform type names remain candidates until Android API review
confirms Kotlin idioms, binary compatibility, Java usability, and
Compose/View parity. The protocol/schema/behavior/helper JSON files are the
executable shared contract; Swift source is an implementation and evidence
source, not the Android API template.

## Performance Groups and Seasons

These are separate multi-performance products, not ticket tiers. The pinned
web runtime includes a browser Performance Group picker, but its access and
recovery model is tied to browser-origin/session behavior and it does not
publish a versioned protocol-2 native profile. A portable native contract must
define buyer-session audience/origin, multi-performance descriptor and
revisioned aggregate snapshot, per-performance allocation commands, atomic
hold adoption/recovery/release/extend, and exact checkout/inspect/book/cancel
handoff semantics before any mobile SDK can expose it honestly.

The pinned `0.71.5` runtime also exports a fixed Renewable Season private-beta
browser surface with an immutable plan, same-seat inclusion, operation
recovery, renewal intent, and a Season-only checkout handoff. It still has no
versioned protocol-2 native profile. A mobile contract must separately define
the native buyer-session audience, plan/occurrence snapshot and revisions,
same-seat availability and inventory rights, caller-stable operations,
partial-terminal recovery, hold/release, Season checkout, renewal, and
cancellation semantics. Neither product is covered by single-event tier
support, and this SDK does not publish thin native wrappers around browser-only
contracts.

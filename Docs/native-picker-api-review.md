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
- GA and variable-table decisions are exclusive prompts. Checkout is disabled
  while either a prompt or confirmation is unanswered.
- Checkout is single-flight and yields one typed transfer. A throwing host
  callback rejects that exact transfer. Close releases picker-owned inventory
  and preserves host-owned inventory.
- Back consumes one layer: prompt → cart → confirmation → section → venue →
  close.
- Empty state requires explicit sales-closed/all-unavailable evidence; absence
  of catalog evidence is still loading/map, never invented sold-out state.
- Required attribution and test-mode indication cannot be disabled or replaced.
- The public customization contract is the canonical 25 whole parts, the ten
  builder-context fields, and the default-content fallback rule recorded in
  `Contracts/picker-public-concepts.v1.json`.
- Theme changes update native chrome and renderer semantic roles without a new
  runtime session. Locale lookup is exact BCP-47 → language → English.
- Foreground availability reconciliation blocks stale action assumptions and
  never restores credentials from persistent storage.

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
- `@MainActor`, `ObservableObject`, `@Published`, `scenePhase`, UIKit
  containment, and VoiceOver identifiers are implementation details. Android
  should map them to main-thread state flow, lifecycle callbacks, view/Compose
  ownership, and TalkBack semantics.

## API disposition

The concept names and 25 part identifiers are frozen for Android Gate 0 review.
Platform type names remain candidates until Android API review confirms Kotlin
idioms, binary compatibility, Java usability, and Compose/View parity. The
protocol/schema/behavior/helper JSON files are the executable shared contract;
Swift source is an implementation and evidence source, not the Android API
template.

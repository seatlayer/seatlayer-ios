# Native picker integration

SeatLayer iOS 0.3.0 exposes three integration levels. All three use the same
protocol-2 runtime state and typed commands; choose based on how much native
layout the host wants to own.

## 1. Ready-made SwiftUI picker

```swift
import SeatLayer
import SwiftUI

struct TicketPicker: View {
    private let configuration = SeatLayerConfiguration(
        event: "ev_xxx",
        locale: "en-GB",
        currency: "GBP"
    )

    var body: some View {
        SeatLayerPicker(
            configuration: configuration,
            options: SeatLayerPickerOptions(
                layout: .adaptive,
                confirmSelection: true,
                enableBestAvailable: true,
                enable3D: true,
                enableSeatView: true,
                holdTtlMs: 15 * 60 * 1_000
            ),
            onCheckout: { handoff in
                try await checkoutBackend.begin(with: handoff)
            },
            onClose: { dismiss() }
        )
    }
}
```

The ready picker owns the native header, legend, map controls, floor and
section navigation, confirmation, exclusive GA/table prompts, cart, hold
status, availability recovery, checkout, loading/error/empty states, and the
required test-mode truth. It renders attribution only when the runtime snapshot
requires it. Phone and wide layouts reuse one mounted renderer.

## 2. Ready-made UIKit host

```swift
let picker = SeatLayerPickerViewController(
    configuration: SeatLayerConfiguration(event: "ev_xxx"),
    options: SeatLayerPickerOptions(layout: .phone),
    onCheckout: { handoff in
        try await checkoutBackend.begin(with: handoff)
    },
    onClose: { [weak self] in
        self?.navigationController?.popViewController(animated: true)
    }
)

addChild(picker)
view.addSubview(picker.view)
picker.didMove(toParent: self)
```

`picker.pickerController` exposes authoritative runtime state and typed
actions. `picker.presentationModel` exposes native-only prompt/cart/error
state. Connect UIKit navigation to `await picker.handleBack()` and inspect
`picker.nextBackStep` for a non-mutating preview.

Pass `SeatLayerPickerCallbacks` for observations that do not own checkout.
The callback surface covers ready/chart-load, selection and validity,
hold/expiry, access expiry/unavailability, unavailable selected objects,
close/error, resolved theme, focused section, confirmed selection/removal,
seat-view opening, and Continue. `onHoldChanged` retains its original
one-hold closure type; use additive `onHoldTransition` when the host also needs
the optional checkout-handoff transition.

Use `picker.updateAppearance(...)` for in-place theme, locale, or style
changes. It keeps the controller, renderer, session, camera, selection, prompt,
and cart mounted.

## 3. Custom native composition

SwiftUI custom layouts must use one `SeatLayerPickerScope` and retain its
scoped default map:

```swift
let options = SeatLayerPickerOptions(confirmSelection: true)

SeatLayerPickerScope(
    options: options,
    themeMode: .auto,
    strings: SeatLayerPickerStrings(localeIdentifier: "de-DE")
) { controller in
    ZStack {
        SeatLayerPickerMap(
            configuration: SeatLayerConfiguration(event: "ev_xxx"),
            options: options,
            controller: controller
        )

        VStack(spacing: 0) {
            SeatLayerPickerHeader()
            SeatLayerPickerPriceLegend()
            HStack {
                SeatLayerPickerTestModeIndicator()
                Spacer()
            }
            Spacer()
            HStack {
                Spacer()
                SeatLayerPickerAttribution()
            }
            SeatLayerPickerDockBar()
            SeatLayerPickerCartSheet(onCheckout: checkout)
        }
    }
}
```

UIKit custom hosts create exactly one `SeatLayerPickerMapView` (or
`SeatLayerPickerMapViewController`), observe `pickerController.snapshot`, and
compose native UIKit controls around it. UI events call semantic controller
methods such as `focusSection`, `overview`, `setFloor`, `setCategoryFilter`,
`deselectObjects`, and `checkout`; they never send bridge envelopes directly.
The host also presents Test Mode truth and renders bottom-right attribution
exactly when `pickerController.snapshot?.branding.attributionRequired == true`.

## Ticket tiers and immersive inspection

When a selected seat contains authored tiers, both native confirmation forms
show the choices and update the displayed amount immediately. Select calls
`picker.setSeatTier` first and acknowledges the already-selected seat only
after the runtime returns an authoritative snapshot. A failure leaves the
decision open. The chosen `tierId`, unit price, and currency then come from the
runtime cart and typed checkout handoff.

`View from here` and `3D` are inspection actions, not confirmation actions.
They preserve the pending decision. Venue 3D uses runtime-authored target,
previous/next, and focused-section fields when available; the bounded fallback
for an older runtime never claims authored row boundaries. At a target, native
chrome exposes Back to venue, previous, panorama, next, and recenter. At the
overview, it exposes Seat map, rotate/move, and supported camera controls.

The renderer owns 3D/panorama pixels and gestures. Native owns only the
capability-gated wording and controls. Ordinary floors, dock, access, and map
controls stand down while an immersive surface owns navigation; the cart and
required test truth remain, along with attribution when runtime branding
requires it. While panorama is open, hardware
Escape and Command-[ are left to the renderer's close surface.

## Whole-part builders

Builders replace or wrap one complete ownership point in the ready tree:

```swift
var builders = SeatLayerPickerBuilders()
builders.header = { context in
    AnyView(
        context.defaultContent
            .background(.ultraThinMaterial)
    )
}

var styles = SeatLayerPickerStyles()
styles[.checkoutBar] = SeatLayerPickerPartStyle(
    background: "#111827",
    cornerRadius: 16,
    horizontalPadding: 12
)

SeatLayerPicker(
    configuration: configuration,
    styles: styles,
    builders: builders,
    onCheckout: checkout
)
```

Every `SeatLayerPickerPartContext` contains `part`, `snapshot`, `controller`,
`presentation`, `themeMode`, `theme`, `strings`, `options`, `style`, and
`defaultContent`. An absent builder renders the default. Wrapping
`defaultContent` preserves component behavior. A replacement for `.map` must
retain the scoped default map unless the host deliberately takes ownership of
the single renderer instance. Builder execution is fail-safe: an absent or
throwing builder renders `defaultContent` rather than a blank or partially
owned buyer surface.

The canonical 25 parts are:

| Part | Default component |
| --- | --- |
| `header` | `SeatLayerPickerHeader` |
| `legend` | `SeatLayerPickerPriceLegend` |
| `floorSelector` | `SeatLayerPickerFloorSelector` |
| `floorStrip` | `SeatLayerPickerFloorStrip` |
| `sectionNavigator` | `SeatLayerPickerSectionNavigator` |
| `dockBar` | `SeatLayerPickerDockBar` |
| `accessibilityFilters` | `SeatLayerPickerAccessibilityFilters` |
| `map` | `SeatLayerPickerMap` |
| `mapControls` | `SeatLayerPickerMapControls` |
| `bestAvailable` | `SeatLayerBestSeatsForm` |
| `seatConfirmation` | `SeatLayerPickerSeatConfirmation` |
| `confirmCard` | `SeatLayerConfirmCard` |
| `generalAdmissionPrompt` | `SeatLayerPickerGeneralAdmissionPrompt` |
| `tablePrompt` | `SeatLayerPickerTablePrompt` |
| `cartList` | `SeatLayerPickerCartList` |
| `cartSheet` | `SeatLayerPickerCartSheet` |
| `venue3D` | `SeatLayerVenue3D` |
| `seatViewChrome` | `SeatLayerSeatViewChrome` |
| `holdCountdown` | `SeatLayerPickerHoldCountdown` |
| `holdLapse` | `SeatLayerHoldLapseNotice` |
| `actionError` | `SeatLayerPickerActionError` |
| `checkoutBar` | `SeatLayerPickerCheckoutBar` |
| `loading` | `SeatLayerPickerLoadingView` |
| `error` | `SeatLayerPickerErrorView` |
| `empty` | `SeatLayerPickerEmptyView` |

`SeatLayerPickerAttribution` and `SeatLayerPickerTestModeIndicator` are truth
components and intentionally are not builder points. The ready picker always
owns their placement. A custom composition must include the test indicator and
the attribution component in its own chrome; the attribution component itself
renders nothing when runtime branding says it is not required.

## Strings and themes

`SeatLayerPickerStrings` resolves an exact BCP-47 locale, then its base
language, then English. It ships the same 37 canonical locale dictionaries as
Flutter and React Native. Host overrides use stable key names:

```swift
let strings = SeatLayerPickerStrings(
    overrides: [
        SeatLayerPickerStringKey.continueWord.rawValue: "Review order"
    ],
    localeIdentifier: "fr-FR"
)
```

The small set of iOS-only accessibility and disclosure keys currently uses
host-overridable English fallback text when the canonical shared catalog has
no translation. This exception is explicit and does not alter the 37-locale
source lock.

`SeatLayerPickerTheme` controls semantic native roles. Its nested
`SeatLayerPickerMapTheme` exposes only the approved renderer background, row
label, text, and selection roles. `auto`, `light`, and `dark` are supported.

`SeatLayerPickerChromeOptions` contains the default-part visibility gates.
`overview`, `zoom`, and `colorblind` remain Boolean master gates for source
compatibility. Compact layouts place these actions in their native sheets by
default; `phoneOverview`, `phoneZoom`, and `phoneColorblind` opt an enabled
master action into direct map chrome. Layout remains `adaptive`, `phone`, or
`wide` through `SeatLayerPickerLayoutMode`. The legacy `attribution` Boolean is
also retained for source compatibility, but it is deliberately
non-authoritative; setting it cannot force or suppress API-owned branding.

## Branding truth and attribution

The runtime/API snapshot is the single authority:

```swift
snapshot.branding.attributionRequired == true
```

- `true` renders the compact three-bar “Powered by SeatLayer” component.
- `false` renders no attribution and releases the reserved control inset.
- A valid older snapshot that omits the field decodes to required for backward
  compatibility.
- Before the first valid snapshot there is no branding decision to display.

The ready compact picker anchors attribution at the safe bottom-right above the
current dock/cart. Map, immersive, and accessibility controls are inset only
while the component exists. A wide overview places it at the bottom-right of
the native side rail; a wide decision uses the safe bottom-right overlay while
the rail yields to the decision surface. Test Mode remains independent at the
top (or bottom-left in panorama), so changing white-label entitlement never
hides test-event truth.

White-label policy is configured server-side and reaches every SDK through
`branding.attributionRequired`. Hosts do not infer entitlement from local
theme, builder, strings, or chrome values. See the
[final visual correction](native-picker-visual-correction-2026-08-31.md) for
paired API-required/disabled pixels and hosted compact/3D/cart evidence.

## State ownership

- `SeatLayerPickerSnapshot` is immutable runtime truth. Only strictly higher
  revisions from the active session are accepted.
- `snapshot.branding.attributionRequired` alone owns attribution visibility;
  local presentation state and host chrome options do not participate.
- `SeatLayerPickerController` owns the runtime session and serialized typed
  commands.
- `SeatLayerPickerPresentationModel` owns local unanswered confirmation,
  exclusive prompt, expanded-cart, action-error, back, and checkout-flight
  state.
- The newest unanswered seat is excluded from the confirmed cart. Confirming
  it is local because runtime selection already contains it; cancelling sends
  one exact-label deselection.
- Back consumes exactly one native layer at a time: exclusive prompt, expanded
  cart, pending confirmation, focused section, immersive venue, then host
  close. Inside the runtime-owned immersive venue it resolves panorama →
  target → 3D overview → map; the original pending decision remains unanswered
  and returns after the map step.

## Layout and accessibility

Give the map a fixed-height or full-screen container and do not wrap it in a
scroll view. The map owns pan and pinch. Native chrome reports its visible
insets to capable runtimes so seats are not framed below controls. Controls
have independent accessibility elements, at least 44-point iOS hit targets,
localized labels, Dynamic Type, and native focus/VoiceOver behavior.

Runtime-authored access groups and counts are shown only when the complete
`access-needs-v1` capability and command legs exist. Accessibility, limited
view, and colorblind-safe mutations remain independent; applying one family
never clears another. Reduce Motion removes generated motion and selection
flight, Reduce Transparency makes material surfaces opaque, and immersive
status-bar foreground remains legible.

The attribution's 18-point paint remains noninteractive and does not pretend
to be a 44-point control. Its surrounding placement never reduces the hit
target of adjacent map, panorama, dock, or cart actions.

## Transferable prewarm and load traces

Prewarm the immutable page before navigation, then create the picker normally:

```swift
Task { try await SeatLayerPicker.prewarm() }

// Later: consumes the matching host once.
let picker = SeatLayerPickerViewController(
    configuration: configuration,
    callbacks: SeatLayerPickerCallbacks(
        onChartLoad: { load in
            metrics.record(tapToReadyMs: load.tapToReadyMs, trace: load.trace)
        }
    ),
    onCheckout: checkout
)
```

UIKit-only hosts can call `SeatLayerPickerPrewarming.prewarm()` and inspect
`SeatLayerPickerPrewarming.status`. The default TTL is 30 seconds; call
`cancelPrewarm()` when an anticipated journey is abandoned.

Prewarm loads only the pinned page in a nonpersistent `WKWebView`. It stores no
event configuration, bearer, token provider, controller, selection, or hold.
Only a matching page URL can consume it, consumption happens once, and expiry,
cancellation, memory pressure, or termination releases it. Event configuration
and any credentials are supplied in memory only after the host belongs to the
real picker.

`onChartLoad` fires only when the runtime advertises both
`chart-load-trace-v1` and `telemetry.chartLoad`. The typed trace keeps unknown
additive fields in `raw`, merges native tap-to-ready timing, and is not logged
or transmitted by the SDK.

Continue with [security and hold ownership](native-picker-security.md) before
connecting checkout.

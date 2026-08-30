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
required test-mode and attribution truth. Phone and wide layouts reuse one
mounted renderer.

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
            Spacer()
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
the single renderer instance.

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

`SeatLayerPickerAttribution` and `SeatLayerPickerTestModeIndicator` are required
truth components and intentionally are not builder points.

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

## State ownership

- `SeatLayerPickerSnapshot` is immutable runtime truth. Only strictly higher
  revisions from the active session are accepted.
- `SeatLayerPickerController` owns the runtime session and serialized typed
  commands.
- `SeatLayerPickerPresentationModel` owns local unanswered confirmation,
  exclusive prompt, expanded-cart, action-error, back, and checkout-flight
  state.
- The newest unanswered seat is excluded from the confirmed cart. Confirming
  it is local because runtime selection already contains it; cancelling sends
  one exact-label deselection.
- Back consumes exactly one layer in this order: prompt, cart, confirmation,
  focused section, immersive venue, host close.

## Layout and accessibility

Give the map a fixed-height or full-screen container and do not wrap it in a
scroll view. The map owns pan and pinch. Native chrome reports its visible
insets to capable runtimes so seats are not framed below controls. Controls
have independent accessibility elements, at least 44-point iOS hit targets,
localized labels, Dynamic Type, and native focus/VoiceOver behavior.

Continue with [security and hold ownership](native-picker-security.md) before
connecting checkout.

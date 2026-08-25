# SeatLayer iOS Seat Map SDK for Reserved Seating

[![CI](https://github.com/seatlayer/seatlayer-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/seatlayer/seatlayer-ios/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/seatlayer/seatlayer-ios)](https://github.com/seatlayer/seatlayer-ios/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-%E2%89%A55.9-F05138.svg)](https://swift.org/)
[![iOS](https://img.shields.io/badge/iOS-%E2%89%A515-000000.svg)](https://developer.apple.com/ios/)
[![License: MIT](https://img.shields.io/badge/license-MIT-111827.svg)](LICENSE)

The official SeatLayer iOS SDK for adding an interactive seating chart and
seat picker to ticketing apps. It hosts the SeatLayer buyer experience in
`WKWebView` and exposes seat selection, temporary holds, best available,
general admission, floors, and live events through a typed Swift API.

[iOS seat-map documentation](https://docs.seatlayer.io/buyer-sdk/mobile/) ·
[Buyer seat-map demo (web)](https://app.seatlayer.io/demo/play) ·
[SeatLayer reserved-seating platform](https://seatlayer.io/) ·
[SeatLayer Flutter seat map SDK](https://github.com/seatlayer/seatlayer-flutter) ·
[SeatLayer Android seat map SDK](https://github.com/seatlayer/seatlayer-android) ·
[SeatLayer React Native SDK](https://github.com/seatlayer/seatlayer-react-native) ·
[SeatLayer AI Toolkit](https://github.com/seatlayer/seatlayer-ai-toolkit)

Production views load the immutable, version-pinned mobile document and its lazy
assets from `https://cdn.seatlayer.io`. This canonical HTTPS origin is required
for origin-bound private buyer sessions; no event key or bearer is put in the
page URL.

- Swift package (SPM), iOS 15+
- Hosted runtime: `seatlayer-js@0.66.0/mobile.html`
- Explicit offline demo/test fixture: `seatlayer-js@0.59.0`
- Protocol revision: 1

## Install

In Xcode, choose **File → Add Package Dependencies** and enter:

```text
https://github.com/seatlayer/seatlayer-ios.git
```

Or declare it explicitly in a manifest:

```swift
dependencies: [
    .package(url: "https://github.com/seatlayer/seatlayer-ios.git", from: "0.2.0")
]
```

Add the `SeatLayer` product to your iOS target, then import it:

```swift
import SeatLayer
```

## Quick start

```swift
let map = SeatLayerView()
map.delegate = self

var config = SeatLayerConfiguration(event: "ev_xxx", currency: "USD")
config.apiBase = "https://api.seatlayer.io"

let info = try await map.load(config)
if case .test = info.mode { showTestBadge() }   // books no real inventory

let hold = try await map.hold()
```

For private channel inventory, mint short-lived sessions on your backend for
the exact allowed origin `https://cdn.seatlayer.io` and provide renewals in
memory:

```swift
config.buyerAccessTokenProvider = { context in
    try await buyerBackend.mintSeatLayerAccess(reason: context.reason)
}
```

Give `SeatLayerView` an explicit height or make it full-screen.

## Security boundary

The iOS app **selects and holds** inventory. Your trusted backend **inspects and
books** the hold after payment or order validation.

- Never ship a SeatLayer secret key in the app binary or WebView.
- Send only the `holdId` and your normal checkout context to your backend.
- Calculate the charge from server-inspected hold items, not app input.
- Reuse your stable order id as `bookingRef` for safe booking retries.

Continue with
[seat holds and secure server-side checkout](https://docs.seatlayer.io/buyer-sdk/holds-and-checkout/)
before connecting payment and booking.

## Layout requirement

**The map must be a fixed-height or full-screen box.** Do not put it inside a
`UIScrollView`, `List`, or SwiftUI `ScrollView`. The canvas consumes pan and
pinch to drive its own zoom, so an enclosing scroll view and the map fight over
every gesture and neither behaves. Give it a definite frame.

The SDK already disables the WebView affordances that fight the canvas: scroll,
bounce, double-tap zoom, long-press callout, and text selection.

## API

`hold` · `resumeHold` · `extendHold` · `release` · `releaseLabels` ·
`bestAvailable` · `holdGA` · `setSeatTier` · `getSelection` · `getCurrentHold` ·
`selectObjects` · `deselectObjects` · `clearSelection` · `selectCategories` ·
`deselectCategories` · `setSelectableObjects` · `setMaxSelection` ·
`getSelectionValidity` · `refreshAccess` · `getGAAreas` · `getFloors` ·
`setFloor` · `setColorblindSafe` · `setViewMode` · `getViewMode` · `zoomIn` ·
`zoomOut` · `zoomToFit` · `destroy` — all
`async throws`, all named to match the web `SeatingChart` so the two SDKs read
as one product.

Events reach `SeatLayerViewDelegate`, which has a no-op default for every
method: `ready`, `selectionChanged`, selection validity/valid/invalid/limit,
buyer-access expired/unavailable, selected-object unavailable, `holdChanged`,
`holdRestored`, `holdExpired`, `gaClick`, `hint`, `seatHover`, `deckTap`, `error`, plus
`didReceiveUnknownEvent` for anything a newer bundle introduces.

## Forward compatibility

The bundle ships new enum values to apps compiled a year earlier, so **every
bridged enum has an `unknown(String)` case** and no decoder throws on an
unfamiliar value:

- `EventMode`, `TransportName`, `ObjectType`, `SeatStatus`,
  `SeatLayerViewMode`, `EnvelopeKind`
- unknown payload fields survive on `JSONValue` and are ignored by the typed structs
- error `code` is an **open** string set — API codes like `sold_out` pass through untouched
- an unknown command name comes back as `unsupported_command`, never a crash

`BundleInfo.supports(command:)` lets an app hide UI an older bundle lacks rather
than discovering `unsupported_command` at tap time.

## Where the Swift side differs from the web contract

Five deliberate divergences, each forced by the platform rather than chosen:

1. **`EnvelopeKind.unknown` is tolerated, not rejected.** The web `decode()`
   returns `null` for an unrecognised `k`, because a page receives unrelated
   `postMessage` traffic it must filter out. On iOS the only writer to our
   `WKScriptMessageHandler` is our own bundle, so an unknown `k` means a *newer
   bundle*, not foreign traffic. It decodes as `.unknown` and the router drops
   it, which keeps an old app forward-compatible.
2. **`sl_timeout` has no web-side counterpart.** The web bridge answers every
   `cmd`, so a missing reply means the WebView stalled or was torn down. The
   native client enforces its own 15s deadline; a late reply for a timed-out id
   is dropped rather than delivered.
3. **`init.protocol` is sent as a `{min,max}` range**, not a bare number. The
   web accepts both; a range is what makes the intersection meaningful in both
   upgrade directions.
4. **Negotiation runs natively before replying.** The web side also checks, but
   failing first means the app never asks for a chart it could not drive, and
   the caller gets a typed `.incompatible` error instead of a blank view.
5. **`chrome.seatTooltip` defaults to `false`.** A hover tooltip is a pointer
   affordance; on touch the host should draw its own seat sheet from
   `seatHoverDidChange`.

Event coalescing is *not* mirrored — the web side already coalesces
`seat.hover` and `selection.changed` to one envelope per frame, so the native
side receives pre-coalesced traffic and only needs the stale-`n` filter.

## Verification

```
xcodebuild -scheme SeatLayer -destination 'generic/platform=iOS'        # library
xcodebuild -project Example/SeatLayerDemo.xcodeproj \
  -scheme SeatLayerDemo -destination 'generic/platform=iOS Simulator'   # example
swift test                                                               # contract suite
```

Tests cover envelope encode/decode, correlation, concurrent commands, timeout
and late-reply dropping, version negotiation in both directions, stale-event
filtering, and unknown-enum tolerance. **None of them requires a WebView** —
`BridgeChannel` is a protocol and the tests substitute a double.

### Simulator

`Example/SeatLayerDemo.xcodeproj` runs on a simulator against a real SeatLayer
API. Its explicit local fixture override is retained for development; production
uses the pinned hosted page. The example fetches chart and object data, upgrades
to the event WebSocket, and exercises hold, extend and release. By default it expects
the locally seeded `ios-e2e-show` event at `http://localhost:8787`; replace
those two constants with a production HTTPS API and event key for a hosted
smoke test.

`Docs/simulator-handshake.png` is the historical first successful bridge
capture, taken against bundle 0.29.0. It is a record of that run, not a
current-state screenshot — re-capture it when the simulator evidence is next
refreshed.

### One bug the simulator run caught

The first run rendered the chart correctly but timed out at
`sl_handshake_timeout` (`Docs/simulator-before-evt-fix.png`). JavaScript has a
single number type, so `n: 1` reaches `WKScriptMessage` as an `NSNumber` holding
a **double**; the decoder demanded a strict integer and rejected every `evt` —
including `sys.ready`. `hello`, `init`, `res` and `err` carry no `n`, which is
exactly why the handshake got as far as a fully drawn map and no further. The
decoder now matches the web's `isFiniteInt` (any finite, integral number), with
a regression test.

## Frequently asked questions

### How do I add a seat map to an iOS app?

Add the Swift package, create a `SeatLayerView` with your event key, and set a
delegate. The quick start above renders a complete interactive seating chart
with live availability; every buyer action — selection, holds, best available —
is an `async throws` Swift call.

### Is this a native Swift seat map or a WebView?

Rendering runs in `WKWebView` on SeatLayer's immutable, version-pinned buyer
runtime, and application code never touches the web layer: commands, payloads,
errors, and events are all typed Swift. The API matches the web `SeatingChart`
one-to-one, so iOS and web read as one product.

### Does it work with SwiftUI?

Yes — wrap `SeatLayerView` in `UIViewRepresentable` and give it a definite
frame. Do not place it inside a SwiftUI `ScrollView`; the canvas owns pan and
pinch gestures.

### How do temporary seat holds work?

When a buyer selects seats, the SDK creates a temporary hold that reserves the
inventory against concurrent buyers for a limited window. The hold expires
automatically if checkout does not complete — `holdExpired` tells the app to
return the buyer to the map — and `extendHold` and `resumeHold` cover longer
checkouts and app restarts. This prevents double-selling without locking seats
forever.

### Can I use my own payment provider?

Yes. SeatLayer never processes payment inside the seat map. The app hands the
`holdId` to your backend, and your backend charges through any payment
provider you already use — Stripe, Adyen, Razorpay, or your own — before
booking the hold through the
[server-side checkout flow](https://docs.seatlayer.io/buyer-sdk/holds-and-checkout/).

### Can I evaluate the SDK without a SeatLayer account?

Yes. The repository's example app and test suite exercise the view, bridge,
and renderer against the bundled offline fixture. Create a free SeatLayer test
event when you are ready to validate live inventory, holds, expiry, and
checkout.

## Continue your iOS integration

- [Follow the mobile seat-map integration guide](https://docs.seatlayer.io/buyer-sdk/mobile/)
  for setup, lifecycle, commands, events, and runtime requirements.
- [Connect seat holds to secure server-side checkout](https://docs.seatlayer.io/buyer-sdk/holds-and-checkout/)
  without exposing booking credentials in the app.
- [Run the complete checkout example](https://docs.seatlayer.io/examples/complete-checkout/)
  to connect the buyer hold id to payment and idempotent booking.
- [Compare SeatLayer's mobile seat map SDKs](https://docs.seatlayer.io/buyer-sdk/mobile/)
  when choosing between native iOS, Flutter, React Native, and Android.
- [Explore the 3D seating chart for web buyers](https://seatlayer.io/3d-seat-map/)
  as a separate browser capability when comparing the wider buyer experience.
- [Point AI coding agents at the SeatLayer docs index](https://docs.seatlayer.io/llms.txt)
  (`llms.txt`) for an agent-readable map of the documentation.

## SeatLayer SDK ecosystem

| Surface | Package or source |
| --- | --- |
| JavaScript | [`@seatlayer/js`](https://www.npmjs.com/package/@seatlayer/js) |
| React | [`@seatlayer/react`](https://www.npmjs.com/package/@seatlayer/react) |
| React Native | [`@seatlayer/react-native`](https://www.npmjs.com/package/@seatlayer/react-native) |
| iOS | [`seatlayer-ios`](https://github.com/seatlayer/seatlayer-ios) (this package) |
| Flutter | [`seatlayer`](https://pub.dev/packages/seatlayer) |
| Android | [`seatlayer-android`](https://github.com/seatlayer/seatlayer-android) |
| Server SDKs | [Node.js, Python, PHP, Ruby, .NET, Java, and Go](https://docs.seatlayer.io/server-sdk/install/) |

## License

MIT © SeatLayer

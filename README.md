# SeatLayer iOS SDK

A `WKWebView` wrapper that drives the SeatLayer web seat-map widget over the
versioned bridge protocol. The web bundle is vendored into the package, so a
seat map opens with **zero network dependency at startup**.

- Swift package (SPM), iOS 15+
- Vendored bundle: `seatlayer-js@0.25.0` (sha256 verified against `release.json`)
- Protocol revision: 1

```swift
let map = SeatLayerView()
map.delegate = self

var config = SeatLayerConfiguration(event: "ev_xxx", currency: "USD")
config.apiBase = "https://api.seatlayer.io"

let info = try await map.load(config)
if case .test = info.mode { showTestBadge() }   // books no real inventory

let hold = try await map.hold()
```

## Known constraint (v0.1)

**The map must be a fixed-height or full-screen box.** Do not put it inside a
`UIScrollView`, `List`, or SwiftUI `ScrollView`. The canvas consumes pan and
pinch to drive its own zoom, so an enclosing scroll view and the map fight over
every gesture and neither behaves. Give it a definite frame.

The SDK already disables the WebView affordances that fight the canvas: scroll,
bounce, double-tap zoom, long-press callout, and text selection.

## API

`hold` · `resumeHold` · `extendHold` · `release` · `releaseLabels` ·
`bestAvailable` · `holdGA` · `setSeatTier` · `getSelection` · `getCurrentHold` ·
`getGAAreas` · `getFloors` · `setFloor` · `setColorblindSafe` · `zoomIn` ·
`zoomOut` · `zoomToFit` · `destroy` — all `async throws`, all named to match the
web `SeatingChart` so the two SDKs read as one product.

Events reach `SeatLayerViewDelegate`, which has a no-op default for every
method: `ready`, `selectionChanged`, `holdChanged`, `holdRestored`,
`holdExpired`, `gaClick`, `hint`, `seatHover`, `deckTap`, `error`, plus
`didReceiveUnknownEvent` for anything a newer bundle introduces.

## Forward compatibility

The bundle ships new enum values to apps compiled a year earlier, so **every
bridged enum has an `unknown(String)` case** and no decoder throws on an
unfamiliar value:

- `EventMode`, `TransportName`, `ObjectType`, `SeatStatus`, `EnvelopeKind`
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
xcodebuild -scheme SeatLayer -destination 'generic/platform=iOS'   # BUILD SUCCEEDED
swift test                                                          # 55 tests, 0 failures
```

Tests cover envelope encode/decode, correlation, concurrent commands, timeout
and late-reply dropping, version negotiation in both directions, stale-event
filtering, and unknown-enum tolerance. **None of them requires a WebView** —
`BridgeChannel` is a protocol and the tests substitute a double.

### Simulator

`Example/SeatLayerDemo.xcodeproj` runs on a simulator and completes the
handshake end to end. Because no public demo event key was found to exist
(`/pub/events/{key}/chart` returns `not_found` for every key in the repos), the
demo drives the **real** bridge runtime from the shipped bundle via its
documented `createChart` option, backed by a stub chart whose `render()` calls
the bundle's own `renderChartDocument`. The seats on screen are painted by the
real buyer renderer from a real `ChartDoc`; only the network-backed hold calls
are simulated in memory.

Captured on iPhone 17 Pro / iOS 26.5 — see `Docs/simulator-handshake.png`:

```
[SeatLayerDemo] sys.ready protocol=1 mode=test transport=ios event=ev_ios_demo
[SeatLayerDemo] bundle=0.25.0 protocol=1...1 commands=18 events=12
[SeatLayerDemo] getFloors -> ["Main floor"]
[SeatLayerDemo] selection.changed -> ["A-4", "A-5"]
[SeatLayerDemo] getSelection -> ["A-4", "A-5"]
```

### One bug the simulator run caught

The first run rendered the chart correctly but timed out at
`sl_handshake_timeout` (`Docs/simulator-before-evt-fix.png`). JavaScript has a
single number type, so `n: 1` reaches `WKScriptMessage` as an `NSNumber` holding
a **double**; the decoder demanded a strict integer and rejected every `evt` —
including `sys.ready`. `hello`, `init`, `res` and `err` carry no `n`, which is
exactly why the handshake got as far as a fully drawn map and no further. The
decoder now matches the web's `isFiniteInt` (any finite, integral number), with
a regression test.

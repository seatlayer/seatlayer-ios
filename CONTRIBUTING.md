# Contributing

## Verification

```
xcodebuild -scheme SeatLayer -destination 'generic/platform=iOS'        # library
xcodebuild -project Example/SeatLayerDemo.xcodeproj \
  -scheme SeatLayerDemo -destination 'generic/platform=iOS Simulator'   # example
swift test                                                               # contract suite
```

The package's tests cover commands and events, concurrent commands, timeouts, version negotiation and
unknown values. They run against a test double of
the map, so they need no device and no network.

To run the example app in the Simulator, see
[Run the example app](README.md#run-the-example-app) in the README.

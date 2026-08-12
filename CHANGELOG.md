# Changelog

## 0.1.1

- Updated the vendored buyer runtime to `seatlayer-js@0.48.1` (sha256
  `b459b0b6…`) so native buyers receive the current mobile sizing, picker chrome,
  access-token, checkout, and duplicate-title fixes.
- Corrected the SDK and bundled-Web version metadata; 0.1.0 embedded Web 0.35.0
  while reporting 0.29.0, which also left CI red.

## 0.1.0

- Initial Swift Package for iOS 15 and later.
- Vendored SeatLayer web renderer with no separate CDN startup dependency.
- Versioned native bridge with async commands, delegate events, typed errors,
  protocol negotiation and forward-compatible payload decoding.
- Holds, best available, general admission, ticket tiers, floors, view modes,
  colorblind-safe rendering and zoom controls.
- UIKit example application and bridge unit tests.

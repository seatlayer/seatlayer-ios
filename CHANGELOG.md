# Changelog

## 0.1.2

- Updated the vendored buyer runtime to `seatlayer-js@0.59.0` (sha256
  `89bc29fb…`), pulled from the production CDN and byte-verified against the
  published release. Native buyers get the mobile buyer round — an
  always-visible price rail, a section locator that survives a filling cart, a
  venue overview that no longer covers the seats, accessibility filters that
  cannot be missed, and a checkout button clear of the home indicator — plus
  the engine fixes that reach every surface: section focus frames the section
  rather than its whole zone, the price filter dims section blocks and not only
  seats, and map type is sized for the device.

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

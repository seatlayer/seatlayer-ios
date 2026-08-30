# Native picker security and hold ownership

The native picker is an inventory-selection client, not a trusted booking or
pricing authority. The application backend inspects the hold, validates the
order, charges through the chosen payment provider, and books idempotently.

## Credential boundary

- Never embed a SeatLayer secret key in the app or WebView.
- Mint a short-lived buyer access token on the backend for the exact allowed
  origin `https://cdn.seatlayer.io`.
- Prefer `buyerAccessTokenProvider`. Tokens remain in memory and are renewed
  only when the runtime requests them.
- Do not put an event key or bearer in the page URL, logs, analytics,
  `UserDefaults`, cookies, files, screenshots, or crash metadata.
- The SDK uses a nonpersistent `WKWebsiteDataStore`, accepts bridge messages
  only from the configured main-frame origin, rejects unrelated navigation,
  and blanks/destroys the WebView on teardown.
- HTTPS pages with no explicit port are normalized only to the scheme default
  (443 for HTTPS, 80 for HTTP); another port never passes origin validation.

```swift
var configuration = SeatLayerConfiguration(event: "ev_private")
configuration.buyerAccessTokenProvider = { context in
    try await backend.mintSeatLayerBuyerAccess(reason: context.reason)
}
```

## Prewarm boundary

Prewarm loads only the immutable page URL into a nonpersistent renderer host.
It never accepts an event, public key, buyer bearer, access-token provider,
selection policy, controller, or hold. The later picker may consume a matching
host once; only then does it arm bridge delivery and send the real init payload
in memory.

Page mismatch does not transfer the host. TTL expiry, explicit cancellation,
memory pressure, app termination, navigation failure, or content-process
termination releases it. A prewarm pool must never become credential or hold
recovery across journeys or process death.

## Selection and hold lifecycle

1. Runtime snapshots are authoritative for selection, availability, price,
   quantity, validity, and hold state.
2. A picker-owned hold reserves inventory while the buyer remains in the
   picker. Closing sends `picker.abort`; the runtime releases only picker-owned
   inventory.
3. Continue is single-flight. The runtime creates or reuses the authoritative
   hold and returns one typed `SeatLayerPickerCheckoutHandoff`.
4. That handoff is the only public native picker value containing the opaque
   hold identifier. Ordinary snapshots deliberately omit it.
5. When the checkout callback returns successfully, ownership is `host`. The
   host is then responsible for booking, explicit rejection/release, or expiry.
6. When the checkout callback throws, the SDK sends
   `picker.rejectHandoff` for that exact opaque identifier, does not retain the
   handoff, records a typed action error, and keeps the buyer in the picker.
7. `picker.abort` preserves a host-owned hold. A view close cannot silently
   release inventory already transferred to checkout.

Do not print, render, persist, or place `handoff.holdId` in analytics. Forward
it through the application's authenticated checkout channel and redact it from
all validation evidence.

## Foreground reconciliation

The ready picker reports background/foreground lifecycle state. On foreground
it consumes any runtime availability outcome, optionally requests the
`availability-refresh-v1` capability, and synchronizes a fresh snapshot before
new buyer actions. Lost inventory and hold lapse are shown as recoverable
native state; stale client state is never used to recreate a hold.

Custom UIKit hosts should mirror that sequence through
`SeatLayerPickerController.lifecycle`, optional `refreshAvailability`, and
`synchronize`. If a private credential has expired, request a fresh in-memory
token instead of restoring one from storage.

## Backend acceptance checks

- Authenticate the app/user request independently of the hold identifier.
- Inspect the hold server-side and calculate totals from trusted hold items.
- Verify event, currency, quantities, expiry, and business rules.
- Use a stable order identifier as `bookingRef` so payment/booking retries are
  idempotent.
- Release or reject abandoned host-owned holds, while retaining expiry as the
  final safety net.

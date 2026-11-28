# Changelog

## Unreleased

**The map: 1.0.8 to 1.0.9**

Views load `https://cdn.seatlayer.io/seatlayer-js@1.0.9/mobile.html`.

- On a phone held upright the level buttons show short codes, 2, 1, G and
  All, so they take less room. Screen readers keep the full names, and a phone
  held sideways keeps the long labels.
- A Season hold reopened for the buyer who placed it lists its seats in the
  cart, where it said "No seats selected".

**The example app**

- It needs `SEATLAYER_API_BASE` and shows setup guidance without it. It no
  longer falls back to the production API, so a test key never goes there.

## 0.5.0

0.4.0 was never released; the previous release is 0.3.4.

The native picker follows the SeatLayer buyer picker's current phone design
item by item, on hosted runtime `seatlayer-js@1.0.8`. Views load
`https://cdn.seatlayer.io/seatlayer-js@1.0.8/mobile.html`.

**A run of performances, new**

- `SeatLayerRunPicker` opens a run: a few performances sold to one buyer as
  one hold. The app's bar (brand mark, the run's name, the hold clock and
  close) stands over SeatLayer's run page, which draws the performances, the
  map, the seat card and the cart. `onContinue` hands over the hold
  (`SeatLayerRunHandoff`); your server books it by `operationId`, at your
  prices.
- `SeatLayerRunController` publishes the run, its status, the hold and the
  page's line, and sends `continueToCheckout`, `getHeldOrder`, `release`,
  `setSelectionMode`, `markBooked`, `setViewportInsets` and `setForeground`.
- `SeatLayerRunMapView` and `SeatLayerRunMap` host the page alone, for an app
  that draws its own bar.
- A page the system ends is opened again on the buyer's last hold, twice in a
  minute at most, as the event picker's page is. A page that did not load
  shows the event picker's panel, with its offline retries.
- The example app opens a run with `SEATLAYER_RUN_KEY`.

**A Season, new**

- `SeatLayerSeasonPicker` opens a Season: a package of dates sold as the same
  seat for every date. The app's bar (brand mark, the Season's name, the hold
  clock and close) stands over SeatLayer's Season page, which draws the
  package, the dates, the map and the cart. `onContinue` hands over the hold
  (`SeatLayerSeasonHandoff`); your server books it by `operationId`, at your
  prices.
- With seats held, close asks the buyer whether to release or keep them;
  `onClose` gets the outcome (`SeatLayerSeasonClose`). The question has no
  deadline: the buyer takes the time they take.
- `SeatLayerSeasonController` publishes the status (with the dates), the hold
  and the page's line, and sends `holdSameSeat`, `holdBestAvailable`,
  `restoreOperation`, `chooseSeats`, `choosePackage`, `markBooked`, `release`,
  `getHeldOrder`, `requestClose`, `setForeground`, `setThemeMode` and
  `setViewportInsets`. Holds wait up to 45 seconds, as the event picker's do.
- With `themeMode: .auto` the page follows the app between light and dark in
  place, without a reload.
- `SeatLayerSeasonMapView` and `SeatLayerSeasonMap` host the page alone. A
  page the system ends opens again on the buyer's last hold, as the run's does.
- The example app opens a Season with `SEATLAYER_SEASON_KEY` and
  `SEATLAYER_PUBLIC_KEY`.

**The map: 0.84.1 to 1.0.8**

Public names stay; these are the changes an app or a buyer can notice.

- 3D touch: one finger moves the view, a pinch zooms, a two-finger twist turns
  the venue and a two-finger drag tilts it. The Rotate / Move control is drawn
  only with `SeatLayerPickerOptions(touchNavigation3D: .classic)`, which also
  keeps the earlier gestures.
- The 3D venue draws a standing crowd. `enable3DCrowd: false` turns it off.
- In a seat's 3D view, a map 560 points or wider shows a small plan of where
  the seat is.
- A venue with several levels opens on its lowest level.
- On a phone, the level stack no longer narrows the whole map: the venue fits
  the full width above the stack, or beside it when it is too tall, and the
  stack never covers seats.
- When the accessibility filter takes the map to another level, the level
  stack marks that level.
- `selectObjects` with a seat on a level that is not drawn returns that seat
  and puts it in the cart at once. A closed section and the accessibility
  filter still refuse it.
- In the snapshot, a whole or party table's `screenPoint` is the middle of its
  chairs, so a spotlight sits on the table. Its `id` stays the first chair's.
- `setViewMode` with iso or perspective shows the flat map.
- A hold the server never answers ends after 40 seconds with "Check your
  connection and try again." A command that can place a hold now waits at
  least 45 seconds (`BridgeClient.holdCommandTimeout`), longer than the map
  waits for the server, so a hold that worked is not reported as failed. Other
  commands keep `commandTimeout`, 15 seconds by default.
- The map has 45 seconds to start (`handshakeTimeout`, was 30).
- A standing area's line in the cart reads the area's name, and keeps its
  "N left" count after a theme or language switch.
- The page names `connection-state-v1`, so the connection status, the offline
  panel and the button's messages below are on.
- A standing-area hold made while seats or tables were selected no longer
  says "Seat T3 was just taken by another buyer." for the buyer's own seats
  the moment the hold lands. A seat another buyer takes later is still
  reported.
- On a map 640 points wide or more, "+" stays on until the seat numbers show.
- VoiceOver names the map's ⓘ buttons and display disc in the page's
  language. What else changed on the map is in the
  [changelog](https://docs.seatlayer.io/changelog/).

**When iOS closes the map page**

iOS can end a web page's process to free memory, mostly while the app is in
the background. Until now the picker then showed "The seat map didn't load"
and the buyer lost the hold handed to checkout.

- The picker loads the page again by itself: at once when the app is in front,
  otherwise when the buyer comes back to the app.
- The new page takes up the hold handed to checkout (else the app's
  `initialHoldId`), so the cart and the hold timer come back as they were.
- A hold lost with the page is not read as a sale: "You're all set" is not
  shown and `onBooked` is not called.
- Two pages ended within a minute are replaced. A third ends in the error view,
  where Try again loads the page and takes up the hold.

**When the connection goes** (with a map page that names
`connection-state-v1`, map 1.0.7 or later; with an older page nothing new is
drawn)

- "You’re offline" on the map's top line three seconds after the page reports
  the line gone, so a blink of the network says nothing. "Updating…" while it
  comes back, and "Back online" for 2.5 seconds once the seats have been read
  again. A line that is only retrying says "Updating…" after 10 seconds.
- With seats held, a second line: "Your seats are still held.", until the
  clock reaches 0:00. While the line is down a clock at 0:00 waits in grey
  until the server has said what happened.
- The status stands after the test badge, short of the Map/3D control. When
  its words do not fit there it takes the map's whole width under that line.
  It takes no touches. "You’re offline" and "Back online" are read once by
  VoiceOver.
- A press without an answer says "Check your connection and try again." in
  the small message, not the red line; the red line stays for refusals. A
  server fault while securing seats says "Couldn’t reach checkout." with "Try
  again", which runs the app's checkout again. From 10 seconds into a hold or
  a best-seats search: "This is taking longer than usual. Please wait…".
- Opening: after 8 seconds, "The seat map is taking longer to load. Please
  wait…". A page that did not load because nothing answered shows "You’re
  offline" with "Try again", and while the app is in front opens itself again
  after 10 and 20 seconds, then every 30. A page whose server answered with an
  error now fails at once with its status, and a server fault says "The seat
  map didn’t load" without the line about the connection.
- `SeatLayerPickerController` publishes `connection` and `connectionShown`,
  and has `supportsConnectionState`.
- Seven new words in the 43 languages: `offline`, `backOnline`, `stillHeld`,
  `updating`, `takingLonger`, `loadingTakingLonger`, `couldNotReachCheckout`.
- iOS apps need nothing new for this.

**Checkout**

- The sale comes from the page. When the app's server has booked the order,
  the app calls `markBooked()` (or `markBooked(holdId:)`). Under
  `hold-mark-booked-v1` the page settles the hold and says whether it was
  booked. Only a booked answer for the hold handed to checkout shows "You're
  all set" and calls `onBooked`, once; `controller.bookings` publishes the
  same. A hold that ends any other way (it runs out, is released, or its page
  closes) is not a sale. `supportsMarkBooked` says whether the loaded page can
  be told; an older page gets nothing and `markBooked()` returns false.
- When sales close, seats already held still go to checkout. With none held,
  the row says "Sales are closed" with the event's date and has no button.
  The snapshot's event gains `startsAtLabel`.
- A refused action says why, in the web picker's sentences: the order limit
  with its number, "We couldn't find 3 seats together", the seats just taken
  by name, the maintenance notice or how long it lasts, access paused, expired
  or revoked, a lost connection. Some have a second line. The code and the
  server's message still go to `onError` only. An error the app's checkout
  throws that conforms to `SeatLayerPickerBuyerFacingError` shows its
  `buyerMessage` as it is; any other says "Check your connection and try
  again."
- `BridgeErrorPayload.meta` carries what the server said beyond the code
  (`max`, `retryAfterS`, `notice`, `status`).
- Standing places the page did not hold (`held: false`) are a refusal:
  `holdGeneralAdmission` throws `hold_unavailable` and the prompt stays open.

**Design system**

- Every colour, size, radius, duration, curve, haptic strength and buyer-facing
  string is now generated from the shared picker design sources
  (`Design/tokens.json`, `Design/locale_strings.json`) into
  `SeatLayerPickerTokens*.g.swift`, checked in and verified in CI; the Swift
  never carries a transcribed number. Strings are typed (`SeatLayerPickerStringKey`),
  every one overridable; English defaults come from the token table and a
  locale dictionary is used only when a host names a locale.
- Both themes are complete ground sets; the accent, its ink, the font and the
  host radius are the organizer's brand in both. `SeatLayerPickerTheme` gains
  `fontFamily`, `logo`, `radius`, `buttonRadius` and `layout` overrides.
- The strings are the ones React Native and Flutter ship: 43 languages (was
  37), with their newer wording.

**The seat card**

- The card is a fixed sheet at the foot of the map. The map is lifted so the
  tapped seat rests above it at unchanged zoom, behind a veil with a clear
  hole around the seat, and returns when the card leaves unless the buyer
  moved the map. The runtime paints the candidate seat (thick ring, halo,
  paled neighbours) while the card asks.
- Section, row and seat as three cells; the category as a full-bleed band with
  its ink chosen per colour; every seat attribute as a band under it
  (accommodation types, wheelchair provision, restricted and obstructed view,
  premium seat, the organizer's note), with the shared glyph set and tones
  that meet 4.5:1 in both themes; a photograph of the view from the seat with
  the distance to the stage, where the runtime offers one.
- `Add seat` invites once, breathes until touched, sweeps and ticks on the
  press; a second tap on a carted seat raises the card in its Remove state
  instead of dropping the seat in silence. Swipe down, tap outside, or the
  platform's back gesture give the seat back. The card answers with haptic
  cues and sizes itself to what it says.
- The card comes up inside the 3D venue too, with `View from this seat`.
- A table booked as one shows how many guests it takes and its name:
  "Gallery | Guests 4 | Table T2", or "Guests 2–6" where the buyer chooses
  how many. It read "Row T2 | Seat T2". The table's name shows with or
  without a section. The card's spoken sentence and the 3D view's caption name
  the table the same way, and its line in the cart reads "Table T2" with
  "Guests 4" under it (it read "T2 · T2").
- The table prompt names the table the same way: "Gallery | Guests 2 |
  Table T3", the guests following the buyer's choice. It read "Number of
  guests 2 | Seat 6 seats". A table with no section has no Section cell, as
  on the card. Its heading wraps instead of being cut.
- The general-admission and table prompts scroll when they are taller than
  the screen (a short phone, large text, many ticket types), and open at
  their foot with the buttons in sight. They ran off the screen.

**The ticket sheet**

- On a phone the cart is one row, as on the web: a circle with a chevron,
  the count and total with the seats' names under them, and the button.
  Tapping the circle or the words opens the list (at most 240 points); a new
  seat closes it. The disc
  handle over the sheet's edge is gone, and the SeatLayer credit is no longer
  drawn under the cart.
- The button is as wide as its words, up to 46% of the row, on two balanced
  lines; longer words step the letters down (14, 12.5, 11.5). When the
  picker's own words still don't fit, or the app gives its own `checkoutBar`,
  the button goes full width under the words.
- Count and total share a line when they fit; else the total goes under the
  count, never cut. The seats line names a shared section once
  ("Dress Circle · C-6, C-7") and a table, booth or standing area by its own
  name, once.
- The cart's text grows with the buyer's text size up to 1.6 times, as the
  design's sheet clamp says; past that the row keeps its size.
- While a seat card asks, the row is faded and takes no taps. A refusal or a
  lapsed hold stands over the row.
- The button says "Securing your seats…" until the seats are held, then
  "Seats secured. Opening checkout…". A sold-out event keeps the row with
  "Select seats" and offers no `Find best seats`; nor does a hold kept by the
  app or a selection the page calls invalid.
- When sales close with nothing held, the row says "Sales are closed" with
  the event's date and has no button.
- Amounts have their currency's decimals and a thousands mark in the picker's
  language (KWD 12.625, ₹125,000, 1.234,50 €), a whole amount none, and
  halves round up as on the map. An app's own price formatter still comes
  first.
- Open, the cart shows one card per ticket (capped at three and a sliver
  before it scrolls), each with its × and its eye; tapping a card takes the
  map to that seat and the sheet stays where the buyer put it; a card swipes
  to remove. Removal is silent and answers the press, not the server.
- An empty cart offers a full-width `Find best seats` that opens the
  best-seats form: `Find seats together` with its ⓘ, a stepper, the ticket
  type and, where the venue has zones, a zone.
- After `Add seat`, a chip flies from the seat to the footer; the count and
  total swell when it lands, and only then does the map pull back.

**The map's chrome**

- Prices sit in a row of their own above the venue, `All prices` pinned first
  and clearing the filter to the whole venue; the Map | 3D control and the
  `Test mode` chip keep their corners; the floor rail is a track on the map.
- One control column in the bottom-right corner: the accessibility control at
  its head, `+`, and `Show whole venue`. `+` retires at the seats or the zoom
  ceiling but keeps its slot; the whole-venue disc is always live.
- Every control drawn over the map tells the runtime where it stands, so a
  tap on native chrome never reaches the seat under it.
- The section dock is off by default on every width (`showDockBar`).

**Accessibility**

- The accessibility sheet applies as its switches are flipped, one line per
  provision with the shared glyph, a note behind ⓘ where the chart authors
  one, live free counts, a `View` group for the two map switches, and a
  count that jumps to the first section holding a matching space. A stepper
  beside the control walks the rest.
- VoiceOver reading order and live regions, Dynamic Type with the design's
  clamps, Reduce Motion (every duration collapses; motion with no reduced
  form is skipped) and Reduce Transparency are honoured on every surface.

**Buyer-facing states**

- Loading draws the venue's silhouette and holds until the runtime has framed
  the map once. A chart that fails to load says so and offers Retry.
- Access lost, sales closed, sold out, a seat taken by another buyer, an
  expired or lapsed hold, and "You're all set" each have their native
  surface; `onBooked` fires once when `markBooked()` books the handed-off
  hold, and
  `showBookedOverlay` lets a host with its own confirmation keep the overlay
  down.
- The hold countdown lives in the header pill only. A buyer back from checkout
  keeps their seats, sees "Your seats are already in checkout" with
  "Release and change seats", and any seat added afterwards joins the cart;
  `Continue` replaces the hold with every seat.

**Runtime contract**

- Protocol 2 with Flutter's required and optional capability sets: an
  optional capability the runtime does not advertise withholds its surface,
  never fails. New: `seat-view-thumbnail-v1`, `accessibility-focus-v1`,
  `section-access-counts-v1`; `seat.retap`; `picker.setSelectionFocus`,
  `picker.setBlockedRegions`, `picker.frameSeat`,
  `picker.focusAccessibilityFilter`, `picker.focusNextAccessibleSection`.
- Composition: three new parts (`accessPanel`, `bookedOverlay`, `toast`),
  each replaceable by name. The picker's own toast band carries the messages
  it has to volunteer.

**Fixed**

- Standing areas and boxes offer only amounts the page accepts. A box is
  sold as all its places, or as a party inside its range; with the wheelchair
  filter on, an area offers its wheelchair places. An area with nothing to
  offer cannot be confirmed. Any other amount the page answered with no hold
  and no reason. New on `GAArea`: `bookingMode`, `minOccupancy`,
  `maxOccupancy`, `wheelchairPlaces` and `wheelchairAvailable`.
- A general-admission hold the page refuses (the places were just taken)
  says why inside the prompt, which stays open. The sentence was drawn behind
  the prompt, where the buyer could not see it. The prompt's second button is
  Cancel, and the table prompt's is Remove, as on React Native and Flutter.
- A table whose guests were still being chosen counted in the cart's total
  and count. It counts once the buyer selects it, and selecting it now tells
  the app (`seatSelections`) as a seat's answer does.
- After a checkout handoff, "Continue to checkout" was off until the app
  called `resumeAfterCheckout()`, so a buyer back from the app's checkout
  without paying could not check out again while the hold ran (since 0.4.0).
  The button now stays on: each press asks the page again and calls the
  checkout handler with the same hold, as React Native does. Apps that call
  `resumeAfterCheckout()` keep working; it still lets the buyer change the
  cart.
- The accessibility sheet puts the map's two switches first and the needs
  under their own heading, "SHOW SEATS FOR". A need's long name wraps and its
  row grows; it was cut. Everything under the title scrolls, so a phone held
  sideways reaches every row; only the needs scrolled, in a strip a row or two
  tall. The title is 17 points, heavy, as on Flutter.
- A sold-out price chip still filters the map when pressed, and is drawn
  faded with a grey dot and its price struck through; it was greyed and did
  nothing. A price is sold out only on the page's live count of free seats
  (`SeatLayerPickerCategory.free`, from a page that names
  `category-availability-v1`): before counts arrived, a price could be struck
  through while seats were still free.
- A level chip on a phone answers a press on the 44 points across it, as the
  other small controls do; it answered on its 28-point chip only. The track
  looks as before. The level being drawn scrolls into view in a track with
  more levels than fit.
- A brand accent's ink is checked against it: white where white reads on it
  at 3:1, else a warm near-black (`#1A1200`, the web picker's). An
  organizer's own ink is kept where it reads; a host's `onAccent` is obeyed as
  given. A pale brand accent carried white text on its buttons and chips.
- The test badge stands on the map's top line, beside Map/3D, or one line
  under the level strip where that is drawn, as on Flutter. It stood a line
  lower, under the Map/3D control. VoiceOver reads it as "Test mode · books
  nothing" only; it added a hint that pressing it explains test mode, which it
  does not.
- The spotlight under a seat card stands on the seat. On a map at its edge,
  which could not move as far as asked, it stood up to 120 points above it.
  The veil is a flat 50 per cent (it was 38) and keeps its clear hole with
  Reduce Transparency on, where it went flat and lost the seat.

**Breaking**

- `onBooked` and "You're all set" no longer follow a hold that disappears.
  The app calls `markBooked()` after its server has booked the order.
- `SeatLayerPickerAccessNeed.count` and `SeatLayerPickerMapState.atVenueFit`
  are optional: "not reported" is no longer read as zero or false.
- Removed: the dense ticket-list helpers and tokens, `fromPrice`, the
  stringly string overrides, the older string-key spellings. Deprecated:
  `phoneZoom`, `phoneFit` (the controls are always drawn).

**Verification**

- 405 unit tests on macOS; 16 simulator golden tests (32 images, light and
  dark) in the example project; the example CI step runs them.

## 0.3.4

- Preserves the `0.2.x` one-argument `onHoldChanged` callback, Boolean
  overview/zoom/colorblind chrome properties, and presentation close/back
  overloads while adding richer hold-transition and close-reason APIs.
- Adds a complete native picker for SwiftUI and UIKit around one headless
  protocol-2 renderer session, while preserving the protocol-1 raw chart API.
- Refines the responsive native chrome with a bounded scrolling legend, fixed
  map/3D selector, compact required truth, measured renderer insets, and
  collision-free compact, large-phone, RTL, and wide decision layouts.
- Adds public native confirmation, GA/table, cart, checkout, accessibility,
  floor, section, 3D, seat-view, hold-lapse, loading/error/empty, attribution,
  and test-mode components.
- Adds native multi-price ticket-tier decisions whose exact tier and quoted
  price are applied to the runtime before confirmation and preserved through
  hold, cart, and the host-owned checkout handoff.
- Adds capability-gated targeted 3D navigation, focused-section previous/next
  state, panorama ownership, and deterministic immersive back navigation
  without confirming an inspected pending seat.
- Adds one-part builders and styles for the canonical 25-part matrix, plus
  scoped custom composition with a public controller and presentation model.
- Adds deterministic back handling, exact pending-seat projection, per-line
  cart removal with exact undo (including the last line), checkout
  single-flight, typed handoff rejection, hold ownership, foreground
  availability reconciliation, and in-place theme updates.
- Ships the canonical 37-locale catalog and design-token locks shared with the
  Flutter and React Native SDKs; supplemental iOS-only strings remain
  host-overridable English fallbacks until the shared catalog expands.
- Pins production to `seatlayer-js@0.71.5/mobile.html`, validates the complete
  protocol-2 handshake surface, and restricts WebKit messages to the configured
  main-frame HTTPS origin (including default-port normalization).
- Adds transferable WebKit prewarming, structured chart-load timing, native
  selection flight and haptics, and Reduce Motion/Reduce Transparency-aware
  presentation behavior.
- Adds portable protocol/schema/concept/behavior/helper fixtures, contract
  tests, and a generic UIKit example for the public picker APIs.
- Hardens command cancellation/timeouts, session-generation ownership,
  superseded loads, WebView teardown, prewarm mismatch/TTL cleanup, and
  retryable/fatal error recovery without adding production logging or
  persistent credential state.

## 0.2.0

- Loads the pinned hosted `seatlayer-js@0.66.0/mobile.html` document at the
  exact buyer-access allowed origin `https://cdn.seatlayer.io`.
- Separates `hostedWebVersion` (`0.66.0`) from the explicit legacy fixture
  version (`0.59.0`) and synchronizes the runnable demo to the verified fixture.
- Adds renewable private buyer access, origin-locked navigation, programmatic
  selection/category controls, exact-count validators, typed validity/access
  events, and fail-closed capability negotiation.
- Retains explicit local fixture loading for demo and contract-test pages.

## 0.1.2

- Updated the vendored buyer runtime to `seatlayer-js@0.59.0` (sha256
  `89bc29fb…`), pulled from the production CDN and byte-verified against the
  published release. Native buyers get the mobile buyer round (an
  always-visible price rail, a section locator that survives a filling cart, a
  venue overview that no longer covers the seats, accessibility filters that
  cannot be missed, and a checkout button clear of the home indicator), plus
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

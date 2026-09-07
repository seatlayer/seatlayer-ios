#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// What the card's two answers report back to a host composing it by hand.
public enum SeatLayerPickerConfirmationAction: Sendable, Equatable {
    case confirm
    case cancel
    case remove
    case seatView
    case venue3D
}

/// The phone's one-seat decision surface.
///
/// A buyer who has just tapped a seat is answering one question — this seat,
/// this price, yes or no — so the card is read top to bottom as that question:
/// where the seat is, what it costs, what it looks like from there, and then
/// the two answers.
///
/// Where it is comes first as a grid rather than a sentence. `Gallery · Row A ·
/// Seat 1` reads as one long label a buyer has to parse; three labelled cells
/// let the eye land on the number it came for. The category and the price share
/// the band under it, in the category's own colour — the same colour the seat
/// is painted on the map.
///
/// The same card asks the opposite question over a seat the buyer taps a second
/// time. Deliberately not a separate surface: a buyer taps a seat and expects
/// the thing that seat's tap always produces.
public struct SeatLayerPickerSeatConfirmation: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    private let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?

    public init(
        onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)? = nil
    ) {
        self.onAction = onAction
    }

    public var body: some View {
        if let question = seatLayerPickerCardQuestion(
            presentation: presentation,
            controller: controller,
            options: style.options
        ) {
            SeatLayerPickerConfirmationCard(
                seat: question.seat,
                question: question.question,
                onAction: onAction
            )
            // A card asking about a second seat is a second card: it points at
            // itself from the beginning again rather than inheriting the last
            // one's spent invitation.
            .id("\(question.seat.id):\(question.seat.label):\(question.question.rawValue)")
        }
    }
}

/// The seat a card is standing over, and which of its two questions it asks.
struct SeatLayerPickerCardSubject {
    let seat: SelectedSeat
    let question: SeatLayerPickerCardQuestion
}

/// Which question, if any, the picker is asking right now.
///
/// A seat waiting to be ADDED outranks a retap: the buyer's most recent tap is
/// the one they are waiting on an answer for. A seat nobody can take raises no
/// card at all, and neither does a read-only picker.
@MainActor
func seatLayerPickerCardQuestion(
    presentation: SeatLayerPickerPresentationModel,
    controller: SeatLayerPickerController,
    options: SeatLayerPickerOptions
) -> SeatLayerPickerCardSubject? {
    guard !options.readOnly else { return nil }
    // The panorama is the seat's own view: it answers the same question this
    // card asks, so the card stands down for it. The 3D venue does not — the
    // buyer is still looking at a seat from outside it.
    guard controller.seatView?.hasContent != true else { return nil }
    let candidate = presentation.candidateSeat
    let subject: SeatLayerPickerCardSubject?
    if let pending = presentation.pendingSeat {
        subject = SeatLayerPickerCardSubject(seat: pending, question: .add)
    } else if let candidate {
        subject = SeatLayerPickerCardSubject(
            seat: candidate,
            question: presentation.cardIntent == .remove ? .remove : .add
        )
    } else {
        subject = nil
    }
    guard let subject else { return nil }
    let snapshot = controller.snapshot
    guard seatLayerPickerMayAskAboutSeat(
        subject.seat,
        holdActive: snapshot?.hold.active ?? false
    ) else { return nil }
    guard seatLayerPickerCategoryIsSelectable(subject.seat, in: snapshot) else { return nil }
    return subject
}

/// How tall the card's body would be if nothing capped it.
private struct SeatLayerPickerCardBodyHeightKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}

struct SeatLayerPickerConfirmationCard: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.seatLayerPickerCardStyles) private var slots
    @Environment(\.seatLayerOnSeatConfidence) private var onSeatConfidence
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let seat: SelectedSeat
    let question: SeatLayerPickerCardQuestion
    let onAction: ((SeatLayerPickerConfirmationAction, SelectedSeat) -> Void)?

    /// Whether the buyer has found this card yet.
    ///
    /// The invitation exists to say where the answer is. A buyer whose finger
    /// is on the card, or whose focus is on the button, has found it.
    @State private var touched = false
    /// Whether the press has been committed and the button now says `Added`.
    @State private var added = false
    /// How far down the buyer has pushed the card, in points.
    @State private var drag: Double = 0
    /// Whether an answer is already on its way, so a second one is ignored.
    @State private var answering = false
    /// Whether this seat's photograph was named but never arrived.
    ///
    /// Held here rather than inside the strip because the card's DECISION ROW
    /// depends on it: a photograph that fails takes the strip with it and the
    /// 3D square has to appear in its place.
    @State private var photoMissed = false
    /// How tall the card's body wants to be, once it has been laid out.
    @State private var bodyHeight: Double?
    @AccessibilityFocusState private var focusOnPrimary: Bool

    var body: some View {
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: colorScheme,
            snapshot: controller.snapshot
        )
        SeatLayerPickerCardSurface(palette: palette, style: slots.confirmCard) {
            VStack(spacing: 0) {
                SeatLayerPickerIdentityGrid(
                    seat: seat,
                    palette: palette,
                    strings: style.strings,
                    sectionCode: seatLayerPickerSectionCode(
                        controller.snapshot,
                        sectionLabel: seat.sectionLabel
                    ),
                    immersive: immersive
                )
                // The band is the category speaking for itself: its colour, its
                // name and what it costs. Without a category there is nothing
                // for it to say, and a price with no name beside it belongs
                // nowhere on this card.
                if let category {
                    SeatLayerPickerCategoryBand(
                        label: category.label,
                        color: Color(uiColor: UIColor(slHex: category.color) ?? .clear),
                        price: priceText,
                        immersive: immersive
                    )
                }
                // The picture is what `View from here` opens, so the strip is
                // drawn full-bleed only where that action AND a real photograph
                // exist. With no photograph there is nothing for a strip to
                // stand in for, so the card spends no height on one and the 3D
                // way in moves into the decision row below.
                if !immersive, let reference = photographReference {
                    SeatLayerPickerPhotoStrip(
                        reference: reference,
                        palette: palette,
                        strings: style.strings,
                        sightlineMetres: sightlineMetres,
                        onMissed: { photoMissed = true },
                        onViewFromSeat: busy ? nil : { inspect(.seatView) },
                        onShow3D: venue3DAvailable && !busy ? { inspect(.venue3D) } : nil
                    )
                }
                // The notes are BANDS, and they sit directly under the category
                // band: below the tier chooser they read as a footnote to the
                // price list rather than as facts about the seat. So the body
                // owns no padding of its own — the bands reach both edges and
                // the tier chooser carries the card's gutter itself.
                if hasBody {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            SeatLayerPickerSeatNotes(rows: notes)
                            if tiers.count > 1 {
                                tierPicker(palette: palette)
                            } else if let guidance = loneTierNote {
                                SeatLayerPickerTierNote(note: guidance, palette: palette)
                                    .padding(.horizontal, 10)
                                    .padding(.top, notes.isEmpty ? 8 : 10)
                                    .padding(.bottom, 9)
                            }
                        }
                        // A scroll view takes every point it is offered, so a
                        // card with two notes on it would otherwise be as tall
                        // as a card with twelve, with the answers stranded at
                        // the foot of a field of empty ground. The body is
                        // measured and the card takes exactly that much.
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: SeatLayerPickerCardBodyHeightKey.self,
                                    value: geometry.size.height
                                )
                            }
                        }
                    }
                    // The body gives way before the answers do: a card that
                    // grows past the screen must never push its own decision
                    // row off the bottom of it.
                    .frame(maxHeight: min(bodyHeight ?? bodyCeiling, bodyCeiling))
                    .onPreferenceChange(SeatLayerPickerCardBodyHeightKey.self) { measured in
                        guard measured.isFinite, measured > 0 else { return }
                        bodyHeight = measured
                    }
                }
                // A disclosure with nowhere to open stays the teaser it has
                // always been: the headline and the detail ARE the information.
                if immersive, let confidence, onSeatConfidence == nil {
                    SeatLayerPickerConfidenceTeaser(
                        disclosure: confidence,
                        palette: palette,
                        strings: style.strings,
                        onOpen: nil
                    )
                    .padding(.horizontal, 10)
                }
                if inspectionRowVisible {
                    SeatLayerPickerInspectionRow(
                        palette: palette,
                        strings: style.strings,
                        onPassport: passportAction,
                        onViewFromSeat: seatViewInScene ? { inspect(.seatView) } : nil
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, hasBody
                        ? SeatLayerPickerSizeTokens.confirmImmersiveInspectGap
                        : SeatLayerPickerSizeTokens.confirmImmersiveBodyTop
                            + SeatLayerPickerSizeTokens.confirmImmersiveInspectGap)
                }
                decisionRow(palette: palette)
            }
        }
        .frame(maxWidth: immersive
            ? SeatLayerPickerSizeTokens.confirmCardImmersiveMaxWidth
            : SeatLayerPickerSizeTokens.confirmCardMaxWidth)
        .padding(.horizontal, SeatLayerPickerSizeTokens.confirmCardGutter)
        // Pushing the card down is the third answer, and the one a thumb
        // reaches first. It follows the finger exactly as far as the threshold
        // and then goes stiff, so the resistance itself says the card is
        // already far enough to let go of. The follow is direct manipulation
        // rather than decoration, so reduced motion leaves it alone.
        .offset(y: seatLayerPickerCardRubberBand(drag))
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard !busy else { return }
                    touched = true
                    drag = value.translation.height
                }
                .onEnded { value in
                    guard !busy else { return }
                    if seatLayerPickerCardDragDismisses(
                        drag: drag,
                        velocity: value.predictedEndTranslation.height
                            - value.translation.height
                    ) {
                        cancel()
                    } else {
                        withAnimation(seatLayerPickerAnimation(.pop, reduceMotion: reduceMotion)) {
                            drag = 0
                        }
                    }
                }
        )
        .simultaneousGesture(
            // The first press anywhere on the card ends the invitation for
            // good, whether or not it lands on a control.
            TapGesture().onEnded { touched = true }
        )
        .dynamicTypeSize(...seatLayerPickerCardTypeCeiling)
        // A dialog, in every sense the platform has one: it names itself, it
        // owns the focus while it is up, and the map behind it is hidden.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(spokenIdentity)
        .accessibilitySortPriority(100)
        // Both answers, reachable without hunting for the buttons: a rotor
        // action is how a screen-reader buyer says yes or no to a card they
        // have just been read.
        .accessibilityAction(named: Text(primaryLabel)) { answer() }
        .accessibilityAction(named: Text(style.strings.text(.cancel))) { cancel() }
        .accessibilityIdentifier("seatlayer-confirmation")
        .onAppear {
            controller.emitHaptic(.cardArrived)
            // The focus lands on the answer the card exists to collect, not on
            // the way out of it. Drawn order is the other way round.
            focusOnPrimary = true
        }
        .onDisappear {
            // The map is what the buyer came back to.
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    // MARK: - The decision row

    private func decisionRow(palette: SeatLayerPickerPalette) -> some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                // With no photograph to ride, the 3D way in is a square in
                // front of the two answers: still one tap away, and it costs
                // the card no row of its own.
                if show3DSquare {
                    SeatLayerPickerSee3DSquare(
                        palette: palette,
                        strings: style.strings,
                        side: actionHeight,
                        action: busy ? nil : { inspect(.venue3D) }
                    )
                }
                // Just over a third to leave, the rest to accept: the two
                // answers are not equally likely, and the card should not
                // pretend that they are.
                SeatLayerPickerCancelButton(
                    label: style.strings.text(.cancel),
                    palette: palette,
                    style: slots.secondaryButton,
                    action: busy ? nil : { cancel() }
                )
                .frame(width: max(
                    0,
                    (geometry.size.width - (show3DSquare ? actionHeight + 8 : 0) - 8)
                        * seatLayerPickerCardCancelShare
                ))
                SeatLayerPickerAddSeatButton(
                    label: added ? style.strings.text(.added) : primaryLabel,
                    palette: palette,
                    style: slots.primaryButton,
                    destructive: question == .remove,
                    added: added,
                    invite: !touched && !reduceMotion,
                    onInviteEnd: { touched = true },
                    action: busy ? nil : { answer() }
                )
                .accessibilityFocused($focusOnPrimary)
            }
        }
        // Forty-four points of answer at the platform's default, and
        // proportionally more once the buyer has scaled their text up: a fixed
        // box would clip the word the whole card exists to offer.
        .frame(height: actionHeight)
        .padding(.horizontal, 10)
        .padding(.top, topGap)
        .padding(.bottom, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveBodyBottom
            : 10)
    }

    private func tierPicker(palette: SeatLayerPickerPalette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(style.strings.text(.ticketType).uppercased())
                .kerning(1.2)
                .seatLayerPickerFont(size: 10, weight: .heavy)
                .foregroundColor(palette.mutedText)
            SeatLayerPickerTicketTierChoices(
                tiers: tiers,
                fallbackCurrency: seat.currency ?? controller.snapshot?.currency ?? "USD",
                selection: tierSelection,
                enabled: !busy,
                compact: true
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, notes.isEmpty ? 8 : 10)
        .padding(.bottom, 9)
    }

    // MARK: - What the card is about

    private var immersive: Bool {
        controller.snapshot?.map.buyerView == "venue3d"
    }

    private var busy: Bool {
        answering || presentation.actionInFlight
    }

    private var category: SeatLayerPickerCategory? {
        controller.snapshot?.categories.first { $0.key == seat.categoryKey }
    }

    private var tiers: [CategoryTier] { seat.tiers ?? [] }

    /// A lone tier is guidance, never a fieldset: an exclusive choice between
    /// one option is not a choice, and drawing it as one asks for a decision
    /// the buyer cannot make.
    private var loneTierNote: String? {
        guard tiers.count == 1 else { return nil }
        let note = tiers[0].buyerMessage?.trimmingCharacters(in: .whitespaces) ?? ""
        return note.isEmpty ? nil : note
    }

    private var notes: [SeatLayerSeatNote] {
        seatLayerSeatNotes(for: seat, strings: style.strings)
    }

    private var hasBody: Bool {
        !notes.isEmpty || tiers.count > 1 || loneTierNote != nil
    }

    private var quote: SeatLayerPickerTierQuote? {
        SeatLayerPickerTiering.quote(
            for: seat,
            preferred: presentation.pendingTierId,
            fallbackCurrency: controller.snapshot?.currency
        )
    }

    private var priceText: String? {
        guard let quote else { return nil }
        return seatLayerPickerMoney(
            quote.amount,
            currency: quote.currency ?? controller.snapshot?.currency ?? "USD",
            style: style
        )
    }

    private var tierSelection: Binding<String?> {
        Binding(
            get: { presentation.pendingTierId },
            set: { presentation.choosePendingTier($0) }
        )
    }

    /// The photograph is offered only where there IS one: an authored upload
    /// the runtime named on this seat, on a runtime that says it reports them.
    /// A stand-in it could draw for any seat is never offered, and an older
    /// runtime that reports nothing is a card with no strip, not a card with an
    /// empty frame.
    private var photographReference: String? {
        guard !photoMissed,
              seatViewAvailable,
              controller.supportsSeatViewThumbnails,
              let thumb = seat.usableSeatViewThumb else { return nil }
        return thumb.reference
    }

    /// The runtime's own figure, printed only where the photograph carries it.
    private var sightlineMetres: Double? {
        controller.supportsSeatViewThumbnails ? seat.sightlineMetres : nil
    }

    private var confidence: SeatConfidenceDisclosure? {
        guard controller.supportsSeatViewThumbnails,
              let disclosure = seat.seatViewConfidence,
              disclosure.isDisclosed else { return nil }
        return disclosure
    }

    private var seatViewAvailable: Bool {
        style.options.enableSeatView
            && controller.supportsSeatView
            && controller.snapshot?.capabilities.contains("seatView") == true
    }

    private var venue3DAvailable: Bool {
        style.options.enable3D
            && controller.supportsVenue3D
            && controller.snapshot?.capabilities.contains("venue3d") == true
    }

    /// In the scene the venue is already the picture, so the one place the
    /// buyer has not looked from is the seat itself.
    private var seatViewInScene: Bool { immersive && seatViewAvailable }

    private var passportAction: (() -> Void)? {
        guard immersive, let confidence, let onSeatConfidence else { return nil }
        return { onSeatConfidence(seat, confidence) }
    }

    private var inspectionRowVisible: Bool {
        seatViewInScene || passportAction != nil
    }

    /// No photograph, no strip — so the 3D action takes its place in the
    /// decision row. Inside the scene it is hidden: the venue is already on
    /// screen and the inspect row carries the view from the seat.
    private var show3DSquare: Bool {
        !immersive && venue3DAvailable && photographReference == nil
    }

    private var primaryLabel: String {
        style.strings.text(seatLayerPickerCardPrimaryKey(seat, question: question))
    }

    private var actionHeight: Double {
        SeatLayerPickerSizeTokens.confirmActionHeight
            * min(
                SeatLayerPickerTypeScaleTokens.card,
                seatLayerPickerTypeScale(dynamicTypeSize)
            )
    }

    private var topGap: Double {
        if immersive {
            return hasBody || inspectionRowVisible
                ? SeatLayerPickerSizeTokens.confirmImmersiveActionGap
                : SeatLayerPickerSizeTokens.confirmImmersiveBodyTop
        }
        return hasBody ? 10 : 8
    }

    /// The card sizes itself to its content and to the screen less one gutter
    /// on each side; whoever places it decides where on the map it sits.
    private var bodyCeiling: Double {
        UIScreen.main.bounds.height * 0.72
            - SeatLayerPickerSizeTokens.confirmIdentityHeight
            - SeatLayerPickerSizeTokens.confirmBandHeight
            - actionHeight
            - 40
    }

    /// Everything the card is about, as one sentence.
    ///
    /// A screen reader walking the drawn card would hear six unlabelled cells —
    /// a name, two numbers, a colour, a word and an amount — in the order they
    /// are painted. The card is a dialog, so it is NAMED, and the name is the
    /// question it is asking: this seat, this category, this price.
    private var spokenIdentity: String {
        var parts: [String] = []
        let section = seat.sectionLabel?.trimmingCharacters(in: .whitespaces) ?? ""
        if !section.isEmpty { parts.append(section) }
        let row = seatLayerPickerRowLabel(
            seat.rowLabel,
            section: seat.sectionLabel,
            sectionCode: seatLayerPickerSectionCode(
                controller.snapshot,
                sectionLabel: seat.sectionLabel
            )
        )
        if !row.isEmpty {
            parts.append("\(seatLayerPickerRowWord(seat, strings: style.strings)) \(row)")
        }
        parts.append(
            "\(seatLayerPickerSeatWord(seat, strings: style.strings)) \(seat.buyerFacingLabel)"
        )
        if let category { parts.append(category.label) }
        if let priceText { parts.append(priceText) }
        return style.strings.text(
            .seatIdentity,
            replacing: ["parts": parts.joined(separator: ", ")]
        )
    }

    // MARK: - Answering

    private func answer() {
        question == .remove ? remove() : confirm()
    }

    /// Take the seat.
    ///
    /// The facts never wait for the picture: the ticket is in the cart and the
    /// footer's total has already changed by the time the button admits it.
    private func confirm() {
        guard !answering else { return }
        answering = true
        // The tap that put the seat on the map earned the policy's light
        // click; this is a different moment and a heavier one, because it is
        // the press that decides what the buyer is going to pay for.
        controller.emitHaptic(.seatConfirmed)
        Task { @MainActor in
            let accepted = await presentation.confirmPending(tierId: presentation.pendingTierId)
            guard accepted else {
                // The card stays, so the answer must be offerable again.
                answering = false
                withAnimation(seatLayerPickerAnimation(.pop, reduceMotion: reduceMotion)) {
                    drag = 0
                }
                return
            }
            onAction?(.confirm, seat)
            if !reduceMotion {
                added = true
                try? await Task.sleep(
                    nanoseconds: UInt64(SeatLayerPickerMotionDurationTokens.pressSweep) * 1_000_000
                )
                // The chip is launched as the card leaves, and the chip's own
                // landing — never a clock here — releases the count's swell
                // and the map's pull-back. Under reduced motion there is no
                // chip to wait for, so nothing is held back at all.
                presentation.beginCartLanding()
            }
            presentation.dismissCandidate()
        }
    }

    /// Take back a seat the buyer had already added.
    ///
    /// The mirror of `confirm`, and deliberately plainer: there is no sweep to
    /// wait for and nothing to fly to the tray, so the state change and the
    /// card's departure happen on the same press. The removal itself is the
    /// SAME path the cart's own ✕ takes — this only puts a card in front of it.
    private func remove() {
        guard !answering else { return }
        answering = true
        controller.emitHaptic(.ticketRemoved)
        Task { @MainActor in
            do {
                try await presentation.removeCartLine(seat.label)
                onAction?(.remove, seat)
                presentation.dismissCandidate()
            } catch {
                answering = false
                withAnimation(seatLayerPickerAnimation(.pop, reduceMotion: reduceMotion)) {
                    drag = 0
                }
            }
        }
    }

    /// CANCEL MEANS "LEAVE IT AS IT WAS", and what that is depends on which
    /// question was asked. Cancelling an add gives the candidate back;
    /// cancelling a remove keeps the seat the buyer already has. The push down
    /// and the tap outside both land here, so every door out of this card
    /// agrees — a stray press must never empty someone's cart.
    private func cancel() {
        guard !answering else { return }
        answering = true
        // A tick, not an impact: giving a seat back is the buyer changing
        // their mind, and nothing about that is worth a thump.
        controller.emitHaptic(.cardCancelled)
        Task { @MainActor in
            if question == .remove {
                presentation.dismissCandidate()
                onAction?(.cancel, seat)
                return
            }
            let dropped = await presentation.cancelPending()
            guard dropped else {
                answering = false
                withAnimation(seatLayerPickerAnimation(.pop, reduceMotion: reduceMotion)) {
                    drag = 0
                }
                return
            }
            presentation.dismissCandidate()
            onAction?(.cancel, seat)
        }
    }

    private func inspect(_ action: SeatLayerPickerConfirmationAction) {
        Task { @MainActor in
            do {
                switch action {
                case .seatView:
                    _ = try await controller.openSeatView(seat.id)
                case .venue3D:
                    _ = try await controller.setBuyerView("venue3d", flyToSeatId: seat.id)
                default:
                    return
                }
                // The card stays put until the runtime has actually mounted
                // the immersive surface: removing it first lets the tail of the
                // same tap reach the web view and select a seat underneath.
                presentation.recordSeatViewOpened(seat)
                onAction?(action, seat)
            } catch let error as SeatLayerError {
                controller.record(error)
            } catch {
                controller.record(.transport(error.localizedDescription))
            }
        }
    }
}

/// The card's Dynamic Type ceiling, as `type.scaleClamp.card` names it.
///
/// The card is the one surface where a clipped word is a decision the buyer
/// cannot make, so it scales further than the rails above it — and still stops,
/// because a decision row that fills the screen has nowhere to put the map the
/// question is about.
var seatLayerPickerCardTypeCeiling: DynamicTypeSize {
    seatLayerPickerTypeCeiling(SeatLayerPickerTypeScaleTokens.card)
}

/// The largest Dynamic Type size whose growth stays inside `clamp`.
func seatLayerPickerTypeCeiling(_ clamp: Double) -> DynamicTypeSize {
    let ordered: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4,
        .accessibility5,
    ]
    var ceiling = DynamicTypeSize.large
    for size in ordered where seatLayerPickerTypeScale(size) <= clamp {
        ceiling = size
    }
    return ceiling
}

/// How much bigger than the design size `size` draws text.
///
/// The platform's own body ramp, named here so the card's clamp is the token's
/// number rather than a size the SDK happens to like.
func seatLayerPickerTypeScale(_ size: DynamicTypeSize) -> Double {
    switch size {
    case .xSmall: return 0.82
    case .small: return 0.88
    case .medium: return 0.94
    case .large: return 1.0
    case .xLarge: return 1.12
    case .xxLarge: return 1.24
    case .xxxLarge: return 1.35
    case .accessibility1: return 1.6
    case .accessibility2: return 1.9
    case .accessibility3: return 2.35
    case .accessibility4: return 2.76
    case .accessibility5: return 3.12
    @unknown default: return 1.0
    }
}
#endif

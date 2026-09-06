#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The seat card's own pieces: what the buyer reads before deciding.
///
/// Split out of the card itself so that file stays a legible top-to-bottom
/// description of the question it asks. These are the widgets that answer
/// "where is the seat, what does it cost, and what does it look like from
/// there" — the identity grid, the category band, the card's surface, the photo
/// strip and the pills that ride it, the ticket-tier picker and the confidence
/// teaser.

// MARK: - Where the seat is

/// Where the seat is, as labelled cells rather than one long sentence.
///
/// Section, row and seat each get their own cell with a small eyebrow over the
/// value, so a buyer checking a row letter reads one word instead of parsing
/// `Gallery · Row A · Seat 1`. The three cells are EQUAL and centred: a section
/// like `209` is as short as the row letter beside it, and giving it the widest
/// track and the smallest type made a line of three facts read as a misaligned
/// grid. Only a section longer than `confirmSectionShortMax` — a venue phrase
/// such as `Upper Grand Circle` — drops to the small wrapping type, because at
/// identity-confirmation time a clipped name is a name the buyer cannot check
/// the map against.
///
/// A screen reader still hears the sentence: the grid is one element carrying
/// the same identity the rest of the picker reads out.
struct SeatLayerPickerIdentityGrid: View {
    let seat: SelectedSeat
    let palette: SeatLayerPickerPalette
    let strings: SeatLayerPickerStrings
    let sectionCode: String?
    /// Whether the card is being read over the 3D venue, where the cells take a
    /// point more padding and a point less type: the scene is behind the card
    /// rather than beside it, so the grid can breathe and the names — read at a
    /// glance against a venue the buyer is already inside — need less weight.
    let immersive: Bool

    var body: some View {
        let cells = seatLayerPickerIdentityCells(
            seat,
            strings: strings,
            sectionCode: sectionCode
        )
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                if index > 0 {
                    Rectangle()
                        .fill(palette.divider)
                        .frame(width: 1)
                }
                cellView(cell)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: SeatLayerPickerSizeTokens.confirmIdentityHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strings.text(
            .seatIdentity,
            replacing: ["parts": cells.map { "\($0.eyebrow) \($0.value)" }.joined(separator: ", ")]
        ))
    }

    private func cellView(_ cell: SeatLayerPickerIdentityCell) -> some View {
        VStack(spacing: 2) {
            Text(cell.eyebrow.uppercased())
                // On the Text rather than on the view: letterspacing is a
                // property of the run, and the view modifier is newer than the
                // oldest iOS this package supports.
                .kerning(SeatLayerPickerSizeTokens.confirmIdentityKeyFontSize * 0.1)
                .seatLayerPickerFont(
                    size: SeatLayerPickerSizeTokens.confirmIdentityKeyFontSize,
                    weight: .heavy
                )
                .foregroundColor(palette.mutedText)
                .lineLimit(1)
                .multilineTextAlignment(.center)
            Text(cell.value)
                .seatLayerPickerFont(size: valueSize(cell), weight: .heavy)
                .foregroundColor(palette.text)
                // Only a LONG section name is worth a second line, and only it
                // gives up the big type to get one. `209` stays the same size
                // as the row letter and the seat number beside it.
                .lineLimit(cell.longSection ? 2 : 1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: cell.longSection)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveCellSide
            : 6)
        .padding(.top, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveCellTop
            : 8)
        .padding(.bottom, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveCellBottom
            : 7)
        // Three equal tracks. The section is not the odd one out: the cells are
        // the same width whether or not there is a section to show, so the eye
        // lands on the same three places every time.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func valueSize(_ cell: SeatLayerPickerIdentityCell) -> Double {
        if cell.longSection {
            return immersive
                ? SeatLayerPickerSizeTokens.confirmImmersiveSectionFontSize
                : SeatLayerPickerSizeTokens.confirmIdentityLongSectionFontSize
        }
        return immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveValueFontSize
            : SeatLayerPickerSizeTokens.confirmIdentityValueFontSize
    }
}

/// One labelled cell of the identity grid.
struct SeatLayerPickerIdentityCell: Equatable {
    let eyebrow: String
    let value: String
    let longSection: Bool
}

/// The cells a seat earns, in reading order.
///
/// A cell the runtime reported as present but empty prints an em dash rather
/// than disappearing: a grid that loses a column between two seats in the same
/// section is a grid the eye has to re-learn.
func seatLayerPickerIdentityCells(
    _ seat: SelectedSeat,
    strings: SeatLayerPickerStrings,
    sectionCode: String?
) -> [SeatLayerPickerIdentityCell] {
    let section = seat.sectionLabel?.trimmingCharacters(in: .whitespaces) ?? ""
    let row = seatLayerPickerRowLabel(
        seat.rowLabel,
        section: seat.sectionLabel,
        sectionCode: sectionCode
    )
    let seatNumber = seat.seatNumber?.trimmingCharacters(in: .whitespaces) ?? ""
    var cells: [SeatLayerPickerIdentityCell] = []
    if seat.sectionLabel != nil {
        cells.append(SeatLayerPickerIdentityCell(
            eyebrow: strings.text(.sectionWord),
            value: section.isEmpty ? "—" : section,
            longSection: section.count > seatLayerPickerConfirmSectionShortMax
        ))
    }
    if seat.rowLabel != nil {
        cells.append(SeatLayerPickerIdentityCell(
            eyebrow: seatLayerPickerRowWord(seat, strings: strings),
            value: row.isEmpty ? "—" : row,
            longSection: false
        ))
    }
    cells.append(SeatLayerPickerIdentityCell(
        eyebrow: seatLayerPickerSeatWord(seat, strings: strings),
        value: seatNumber.isEmpty ? seat.buyerFacingLabel : seatNumber,
        longSection: false
    ))
    return cells
}

// MARK: - What it costs

/// The category, in the category's own colour, and what it costs.
///
/// The map is already painted in these colours, so the band is the one place on
/// the card where naming the category earns its line: the buyer matches the
/// colour to the seat they just tapped. It is the colour ITSELF, full bleed — a
/// tint under a nine-point disc said the colour twice and loudly enough neither
/// time. The words take the ink measured for that colour, so a pale yellow
/// category keeps its name. The price lives here rather than on the button,
/// where it would be the same number the cart is about to say.
///
/// It prints the name and the price and NOTHING else. A remaining count beside
/// them said nothing a buyer choosing one seat could act on, and it pushed the
/// price into the card's edge. The legend still carries the count, where a buyer
/// comparing categories is actually looking.
struct SeatLayerPickerCategoryBand: View {
    let label: String
    let color: Color
    let price: String?
    let immersive: Bool

    var body: some View {
        let ink = seatLayerPickerBandInk(color)
        HStack(spacing: 8) {
            // The name takes the room and gives way first; the price is the
            // fact the buyer came for and never truncates.
            Text(label)
                .seatLayerPickerFont(
                    size: SeatLayerPickerSizeTokens.confirmBandNameFontSize,
                    weight: .heavy
                )
                .foregroundColor(ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let price {
                Text(price)
                    .seatLayerPickerFont(size: priceSize, weight: .heavy)
                    .monospacedDigit()
                    .foregroundColor(ink)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.leading, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveBandPadX
            : SeatLayerPickerSizeTokens.confirmBandPadLeading)
        .padding(.trailing, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveBandPadX
            : SeatLayerPickerSizeTokens.confirmBandPadTrailing)
        .padding(.top, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveBandPadY
            : SeatLayerPickerSizeTokens.confirmBandPadTop)
        .padding(.bottom, immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveBandPadY
            : SeatLayerPickerSizeTokens.confirmBandPadBottom)
        .frame(maxWidth: .infinity, minHeight: SeatLayerPickerSizeTokens.confirmBandHeight)
        // The colour the legend and the map speak, undiluted.
        .background(color)
        .accessibilityElement(children: .combine)
    }

    private var priceSize: Double {
        immersive
            ? SeatLayerPickerSizeTokens.confirmImmersiveBandPriceFontSize
            : SeatLayerPickerSizeTokens.confirmBandPriceFontSize
    }
}

// MARK: - The card's own box

/// The card's surface, its hairline, and the shadow under it.
struct SeatLayerPickerCardSurface<Content: View>: View {
    let palette: SeatLayerPickerPalette
    let style: SeatLayerPickerPartStyle?
    @ViewBuilder let content: () -> Content

    var body: some View {
        let radius = style?.cornerRadius ?? SeatLayerPickerRadiusTokens.confirmCard
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content()
            .background(
                (style?.background.flatMap { UIColor(slHex: $0) }.map(Color.init(uiColor:)))
                    ?? palette.surface
            )
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    (style?.border.flatMap { UIColor(slHex: $0) }.map(Color.init(uiColor:)))
                        // The card's edge is the divider pulled towards the ink,
                        // so it holds against a map of any colour behind it.
                        ?? seatLayerPickerLerp(palette.divider, palette.text, 0.3),
                    lineWidth: max(1, style?.borderWidth ?? 0)
                )
            }
            // Long, offset downward and drawn tighter than it is blurred: the
            // card has to read as standing over the map rather than printed on
            // it.
            .shadow(
                color: .black.opacity(0.72),
                radius: SeatLayerPickerElevationTokens.confirmCard,
                y: SeatLayerPickerElevationTokens.confirmCard / 2
            )
    }
}

// MARK: - The seat's own photograph

/// The seat photograph, with both ways into it riding its bottom corners.
///
/// The photograph is authored: the runtime names it as an event-scoped API path
/// on the seat, and the bytes come back through `SeatLayerBuyerAssetLoader`
/// because a private event answers that path only for the buyer's own bearer.
/// Until they land the strip is a neutral gradient; if they never land the card
/// drops the strip entirely and the 3D way in moves into the decision row.
///
/// Full-bleed inside the card's own radius — a photograph inset from the card's
/// edge reads as an illustration in an article rather than as the view being
/// sold.
struct SeatLayerPickerPhotoStrip: View {
    @Environment(\.seatLayerBuyerAssetLoader) private var loader
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let reference: String
    let palette: SeatLayerPickerPalette
    let strings: SeatLayerPickerStrings
    let sightlineMetres: Double?
    let onMissed: () -> Void
    let onViewFromSeat: (() -> Void)?
    let onShow3D: (() -> Void)?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    seatLayerPickerBlend(palette.accent, 0.22, over: palette.surface),
                    seatLayerPickerBlend(palette.text, 0.12, over: palette.surface),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // The picture is what the pills open, and the pills say
                    // what they open: a second name would be read out twice.
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
            if let sightlineMetres {
                SeatLayerPickerSightlinePill(metres: sightlineMetres, strings: strings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(6)
            }
            HStack {
                SeatLayerPickerPhotoPill(
                    symbol: "eye",
                    label: strings.text(.viewFromHere),
                    spoken: strings.text(.viewFromHere),
                    action: onViewFromSeat
                )
                Spacer(minLength: 8)
                if let onShow3D {
                    SeatLayerPickerPhotoPill(
                        symbol: "cube",
                        label: strings.text(.venue3D),
                        // The pill says "3D"; a screen reader hears the
                        // sentence.
                        spoken: strings.text(.seeItIn3D),
                        action: onShow3D
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(6)
        }
        .frame(height: SeatLayerPickerSizeTokens.confirmPhotoHeight)
        .clipped()
        .task(id: reference) { await fetch() }
        .animation(
            reduceMotion ? nil : seatLayerPickerAnimation(.crossfade, reduceMotion: false),
            value: image != nil
        )
    }

    /// Ask for this seat's photograph, once per reference.
    ///
    /// Started when the card opens rather than when it settles: the runtime
    /// resolves the seat after the card is already mounted, and a buyer looking
    /// at a card should not wait for an animation to end before the picture
    /// starts arriving.
    private func fetch() async {
        image = nil
        let bytes = await loader.load(reference)
        guard let bytes, let decoded = UIImage(data: bytes) else {
            // A miss is evicted so the next open of the same seat tries again:
            // the usual reason for one is a bearer that had just expired.
            loader.evict(reference)
            onMissed()
            return
        }
        image = decoded
    }
}

/// The photo scrim, dark in both themes because a photograph can be anything.
let seatLayerPickerPhotoPlate = Color(
    red: 0x0A / 255, green: 0x0E / 255, blue: 0x16 / 255
).opacity(0xB8 / 255.0)

/// Its ink. Measured at 7.5:1 over a pure-white photograph.
let seatLayerPickerPhotoPlateInk = Color.white

/// One pill on the photo strip.
///
/// It takes a dark plate and white ink in both themes: a photograph can be any
/// colour, and the one pairing that survives all of them is white on near-black.
struct SeatLayerPickerPhotoPill: View {
    let symbol: String
    let label: String
    let spoken: String
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .seatLayerPickerFont(size: 11, weight: .heavy)
                    .lineLimit(1)
            }
            .foregroundColor(seatLayerPickerPhotoPlateInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(minHeight: SeatLayerPickerSizeTokens.confirmPillHeight)
            .background(
                Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
            )
            .background(Capsule().fill(seatLayerPickerPhotoPlate))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isButton)
    }
}

/// The distance to the stage, on the plate the photograph gives it.
struct SeatLayerPickerSightlinePill: View {
    let metres: Double
    let strings: SeatLayerPickerStrings

    var body: some View {
        Text(strings.text(.sightline, replacing: ["m": seatLayerPickerSightlineFigure(metres)]))
            .seatLayerPickerFont(
                size: SeatLayerPickerSizeTokens.confirmSightFont,
                weight: .bold
            )
            .foregroundColor(seatLayerPickerPhotoPlateInk)
            .lineLimit(1)
            .padding(.horizontal, SeatLayerPickerSizeTokens.confirmSightPadX)
            .padding(.vertical, SeatLayerPickerSizeTokens.confirmSightPadY)
            .background(Capsule().fill(seatLayerPickerPhotoPlate))
    }
}

/// The metre figure as the runtime rounded it.
///
/// The number arrives already rounded, so this only decides whether to print a
/// decimal point at all: `7` rather than `7.0`, `7.4` unchanged.
func seatLayerPickerSightlineFigure(_ metres: Double) -> String {
    metres == metres.rounded()
        ? String(Int(metres.rounded()))
        : String(metres)
}

// MARK: - The ways further in

/// The 3D way in as a square in the decision row, in front of `Cancel`.
///
/// Where there is no photograph there is no strip to hold a pill, and a 44 pt
/// bar carrying one control was dead height on a card that already covers a
/// third of the phone. The action keeps its full target and its full spoken
/// name; what it loses is a row of its own.
struct SeatLayerPickerSee3DSquare: View {
    let palette: SeatLayerPickerPalette
    let strings: SeatLayerPickerStrings
    let side: Double
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            VStack(spacing: 1) {
                Image(systemName: "cube")
                    .font(.system(size: 15, weight: .semibold))
                Text(strings.text(.venue3D))
                    .kerning(0.4)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.confirm3dSquareFontSize,
                        weight: .heavy
                    )
                    .lineLimit(1)
            }
            .foregroundColor(palette.text)
            .frame(width: side, height: side)
            // The accent, held back to a tint: this is the way further in, not
            // the answer to the card's question.
            .background(seatLayerPickerBlend(palette.accent, 0.12, over: palette.surface))
            .clipShape(RoundedRectangle(
                cornerRadius: SeatLayerPickerRadiusTokens.button,
                style: .continuous
            ))
            .overlay {
                RoundedRectangle(
                    cornerRadius: SeatLayerPickerRadiusTokens.button,
                    style: .continuous
                ).stroke(palette.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        // The square has no room for the sentence; a screen reader hears it.
        .accessibilityLabel(strings.text(.seeItIn3D))
    }
}

/// The card's inspection row inside the 3D venue.
///
/// One line of compact chips, not a stack of full-width rows. The passport and
/// the view from the seat used to be two 44 pt bars above the two answers,
/// which put the card over the very section the buyer had just flown into.
///
/// The web's third chip, `Save to compare`, is absent: nothing in the snapshot
/// carries a compare set, and a control that cannot say anything true is worse
/// than an absent one.
struct SeatLayerPickerInspectionRow: View {
    let palette: SeatLayerPickerPalette
    let strings: SeatLayerPickerStrings
    let onPassport: (() -> Void)?
    let onViewFromSeat: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            if let onPassport {
                SeatLayerPickerInspectChip(
                    palette: palette,
                    // The accent dot is the passport's mark on the web chip;
                    // the word beside it is the whole label at this size.
                    dot: true,
                    label: strings.text(.passport),
                    spoken: strings.text(.passport),
                    action: onPassport
                )
            }
            if let onViewFromSeat {
                SeatLayerPickerInspectChip(
                    palette: palette,
                    dot: false,
                    // The seat is named twice directly above this chip, so the
                    // visible word is the short one.
                    label: strings.text(.viewFromHere),
                    spoken: strings.text(.viewFromThisSeat),
                    action: onViewFromSeat
                )
            }
        }
    }
}

/// One chip on the 3D card's inspection row.
struct SeatLayerPickerInspectChip: View {
    let palette: SeatLayerPickerPalette
    let dot: Bool
    let label: String
    let spoken: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if dot {
                    Circle().fill(palette.accent).frame(width: 7, height: 7)
                }
                Text(label)
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.confirmInspectChipFontSize,
                        weight: .heavy
                    )
                    .lineLimit(1)
            }
            .foregroundColor(palette.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(
                maxWidth: .infinity,
                minHeight: SeatLayerPickerSizeTokens.confirmInspectChipHeight
            )
            // The accent, held back to a tint: these are ways further in, and
            // the answer is the only filled button on the card.
            .background(seatLayerPickerBlend(palette.accent, 0.12, over: palette.surface))
            .clipShape(RoundedRectangle(
                cornerRadius: SeatLayerPickerRadiusTokens.button,
                style: .continuous
            ))
            .overlay {
                RoundedRectangle(
                    cornerRadius: SeatLayerPickerRadiusTokens.button,
                    style: .continuous
                ).stroke(palette.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
    }
}

/// What the runtime is willing to say about how this seat's view was made.
///
/// 3D only, as on the web: outside the scene there is no model on screen to be
/// honest about. It is the teaser, not the passport — the passport itself is
/// the runtime's own surface and the bridge exposes no command to open it — so
/// this is a BUTTON only where a host has taken the confidence callback and can
/// show something. With no callback it stays an information row: a control that
/// opens nothing is worse than a line of text.
struct SeatLayerPickerConfidenceTeaser: View {
    let disclosure: SeatConfidenceDisclosure
    let palette: SeatLayerPickerPalette
    let strings: SeatLayerPickerStrings
    let onOpen: (() -> Void)?

    var body: some View {
        let row = content
        Group {
            if let onOpen {
                Button(action: onOpen) { row }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
            } else {
                // Not focusable, not a button, and not announced as one: there
                // is nothing behind it to press.
                row.accessibilityElement(children: .combine)
            }
        }
        .padding(.top, SeatLayerPickerSizeTokens.confidenceTeaserTop)
    }

    private var content: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(disclosure.headline ?? "")
                    .seatLayerPickerFont(
                        size: SeatLayerPickerSizeTokens.confidenceTeaserHeadFont,
                        weight: .bold
                    )
                    .foregroundColor(palette.text)
                    .lineLimit(1)
                let detail = disclosure.modeledTarget ?? disclosure.reality ?? ""
                if !detail.isEmpty {
                    Text(detail)
                        .seatLayerPickerFont(
                            size: SeatLayerPickerSizeTokens.confidenceTeaserDetailFont
                        )
                        .foregroundColor(palette.mutedText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(strings.text(.passport))
                .seatLayerPickerFont(
                    size: SeatLayerPickerSizeTokens.confidenceTeaserBadgeFont,
                    weight: .bold
                )
                .foregroundColor(seatLayerPickerReadableAccent(palette))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, SeatLayerPickerSizeTokens.confidenceTeaserPadX)
        .padding(.vertical, SeatLayerPickerSizeTokens.confidenceTeaserPadY)
        .frame(
            maxWidth: .infinity,
            minHeight: SeatLayerPickerSizeTokens.confidenceTeaserMinHeight
        )
        .background(seatLayerPickerBlend(palette.accent, 0.07, over: palette.surface))
        .clipShape(RoundedRectangle(
            cornerRadius: SeatLayerPickerSizeTokens.confidenceTeaserRadius,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(
                cornerRadius: SeatLayerPickerSizeTokens.confidenceTeaserRadius,
                style: .continuous
            ).stroke(
                seatLayerPickerBlend(palette.accent, 0.35, over: palette.divider),
                lineWidth: 1
            )
        }
    }
}

/// The accent, walked toward the text until it can be read on the surface.
///
/// A host's brand accent is chosen to be pressed, not to be read at 11 pt, and
/// the same hex that carries white on a button can measure 2:1 as small bold
/// type. Rather than refuse the brand, the badge borrows the text's ink one
/// step at a time until it clears the bar.
func seatLayerPickerReadableAccent(_ palette: SeatLayerPickerPalette) -> Color {
    let surface = SeatLayerPickerInkColor(palette.surface)
    let accent = SeatLayerPickerInkColor(palette.accent)
    let text = SeatLayerPickerInkColor(palette.text)
    if SeatLayerPickerInk.contrastRatio(accent, surface) >= 4.5 { return palette.accent }
    for step in stride(from: 0.1, through: 1.0, by: 0.1) {
        let candidate = SeatLayerPickerInk.lerp(accent, text, step)
        if SeatLayerPickerInk.contrastRatio(candidate, surface) >= 4.5 {
            return candidate.color
        }
    }
    return palette.text
}

/// The one thing a single ticket type has to say for itself.
struct SeatLayerPickerTierNote: View {
    let note: String
    let palette: SeatLayerPickerPalette

    var body: some View {
        Text(note)
            .seatLayerPickerFont(size: 11)
            .lineSpacing(4)
            .foregroundColor(palette.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

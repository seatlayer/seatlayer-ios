#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// What one tone paints: the band's ground, its title ink, its body ink.
struct SeatLayerSeatNoteToneColors {
    /// The band's own ground, tinted out of the surface it sits on.
    let ground: Color
    /// The title's ink, measured against `ground` rather than against the
    /// surface the ground is mixed from.
    let ink: Color
    /// The organizer's second line, one step quieter than `ink`.
    let bodyInk: Color
    /// The glyph's ink.
    let iconInk: Color
}

/// The colours `tone` paints in `palette`, as SwiftUI sees them.
///
/// A thin conversion over the platform-free `seatLayerSeatNoteInk`: the rule
/// lives there so the contrast gate can measure it without a simulator, and
/// this only carries the host's own branded palette into it.
func seatLayerSeatNoteToneColors(
    _ palette: SeatLayerPickerPalette,
    _ tone: SeatLayerSeatNoteTone
) -> SeatLayerSeatNoteToneColors {
    let resolved = seatLayerSeatNoteInk(
        SeatLayerSeatNoteInkPalette(
            surface: SeatLayerPickerInkColor(palette.surface),
            text: SeatLayerPickerInkColor(palette.text),
            mutedText: SeatLayerPickerInkColor(palette.mutedText),
            warning: SeatLayerPickerInkColor(palette.warning),
            warnText: SeatLayerPickerInkColor(palette.warnText),
            premium: SeatLayerPickerInkColor(palette.premium),
            premiumText: SeatLayerPickerInkColor(palette.premiumText)
        ),
        tone
    )
    return SeatLayerSeatNoteToneColors(
        ground: resolved.ground.color,
        ink: resolved.ink.color,
        bodyInk: resolved.bodyInk.color,
        iconInk: resolved.iconInk.color
    )
}

/// A seat's notes, as full-bleed bands under the category band.
///
/// No radius, no border and no inset: a band is the card's full width or it is
/// a plate again. The hairline lives on the JOIN, so the first band sits flush
/// against the category band above it and the block reads as a continuation of
/// that band rather than as a new object.
///
/// `compact` is the wide layout's tap-card form — a narrower popup floating
/// over the map, so the type comes down a rung and the text inset moves to the
/// tap card's own leading inset. The bands stay bands.
public struct SeatLayerPickerSeatNotes: View {
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var controller: SeatLayerPickerController
    private let rows: [SeatLayerSeatNote]
    private let compact: Bool

    public init(rows: [SeatLayerSeatNote], compact: Bool = false) {
        self.rows = rows
        self.compact = compact
    }

    public var body: some View {
        if !rows.isEmpty {
            let palette = resolveSeatLayerPickerPalette(
                style: style,
                colorScheme: colorScheme,
                snapshot: controller.snapshot
            )
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                    SeatLayerPickerSeatNoteBand(
                        row: row,
                        compact: compact,
                        palette: palette,
                        // Only BETWEEN bands: a line above the first one would
                        // fight the category band's own edge.
                        joined: index > 0
                    )
                }
            }
        }
    }
}

struct SeatLayerPickerSeatNoteBand: View {
    let row: SeatLayerSeatNote
    let compact: Bool
    let palette: SeatLayerPickerPalette
    let joined: Bool

    var body: some View {
        let tone = seatLayerSeatNoteToneColors(palette, row.tone)
        HStack(alignment: .top, spacing: SeatLayerPickerSizeTokens.noteIconGap) {
            SeatLayerPickerSeatIcon(
                iconKey: row.iconKey,
                color: tone.iconInk,
                size: compact
                    ? SeatLayerPickerSizeTokens.noteCompactIconSize
                    : SeatLayerPickerSizeTokens.noteIconSize
            )
            // The drawing's optical centre sits a point below the cap height
            // of the title beside it.
            .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .seatLayerPickerFont(
                        size: compact ? 11.5 : 12.5,
                        weight: compact ? .bold : .heavy
                    )
                    .foregroundColor(tone.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = row.note {
                    Text(note)
                        .seatLayerPickerFont(size: compact ? 10.5 : 11)
                        .foregroundColor(tone.bodyInk)
                        .lineSpacing(compact ? 3 : 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, compact
            ? SeatLayerPickerSizeTokens.noteCompactPadLeading
            : SeatLayerPickerSizeTokens.notePadX)
        .padding(.trailing, compact
            ? SeatLayerPickerSizeTokens.noteCompactPadX
            : SeatLayerPickerSizeTokens.notePadX)
        .padding(.vertical, compact
            ? SeatLayerPickerSizeTokens.noteCompactPadY
            : SeatLayerPickerSizeTokens.notePadY)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.ground)
        .overlay(alignment: .top) {
            if joined {
                Rectangle()
                    .fill(palette.divider.opacity(
                        SeatLayerPickerOpacityTokens.noteHairline
                    ))
                    .frame(height: 1)
            }
        }
        // The row is one fact, and it is read as one sentence: the drawing is
        // silent and the organizer's line belongs to the title above it.
        .accessibilityElement(children: .combine)
    }
}
#endif

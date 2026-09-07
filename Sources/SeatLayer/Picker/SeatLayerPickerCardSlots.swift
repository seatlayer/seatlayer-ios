#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The named visual slots the seat card offers a host.
///
/// Deliberately narrower than replacing the whole part: a host that only wants
/// its own button radius should not have to rebuild a surface that decides
/// which seats may be asked about, how a photograph is fetched and what a
/// screen reader hears.
public struct SeatLayerPickerCardStyles: Sendable, Equatable {
    /// The card's own box: ground, edge and radius.
    public var confirmCard: SeatLayerPickerPartStyle?
    /// `Add seat` and `Remove seat`.
    public var primaryButton: SeatLayerPickerPartStyle?
    /// `Cancel`.
    public var secondaryButton: SeatLayerPickerPartStyle?
    /// The pills that ride the photograph.
    public var pill: SeatLayerPickerPartStyle?
    /// The glass the card stands on, as a token hex.
    ///
    /// Transparent by default in the sense that the picker chooses it: a host
    /// naming one gets its own veil, hole and all.
    public var scrimColor: String?

    public init(
        confirmCard: SeatLayerPickerPartStyle? = nil,
        primaryButton: SeatLayerPickerPartStyle? = nil,
        secondaryButton: SeatLayerPickerPartStyle? = nil,
        pill: SeatLayerPickerPartStyle? = nil,
        scrimColor: String? = nil
    ) {
        self.confirmCard = confirmCard
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.pill = pill
        self.scrimColor = scrimColor
    }

    /// The veil colour as a drawable, or nil where the host named none.
    public var scrim: Color? {
        scrimColor.flatMap { UIColor(slHex: $0) }.map(Color.init(uiColor:))
    }
}

private struct SeatLayerPickerCardStylesKey: EnvironmentKey {
    static let defaultValue = SeatLayerPickerCardStyles()
}

extension EnvironmentValues {
    /// The seat card's named style slots.
    public var seatLayerPickerCardStyles: SeatLayerPickerCardStyles {
        get { self[SeatLayerPickerCardStylesKey.self] }
        set { self[SeatLayerPickerCardStylesKey.self] = newValue }
    }
}

extension View {
    /// Restyle the seat card's named slots for this subtree.
    public func seatLayerPickerCardStyles(
        _ styles: SeatLayerPickerCardStyles
    ) -> some View {
        environment(\.seatLayerPickerCardStyles, styles)
    }
}

/// What the host does when the buyer asks how a seat's view was made.
///
/// The passport itself is the runtime's own surface and the bridge exposes no
/// command to open it, so the card's teaser is a BUTTON only where a host has
/// taken this and can show something. With nothing here it stays an information
/// row: a control that opens nothing is worse than a line of text.
public typealias SeatLayerPickerSeatConfidenceHandler =
    @MainActor (SelectedSeat, SeatConfidenceDisclosure) -> Void

private struct SeatLayerPickerSeatConfidenceKey: EnvironmentKey {
    static let defaultValue: SeatLayerPickerSeatConfidenceHandler? = nil
}

extension EnvironmentValues {
    /// The host's seat-confidence handler, or nil where it took none.
    public var seatLayerOnSeatConfidence: SeatLayerPickerSeatConfidenceHandler? {
        get { self[SeatLayerPickerSeatConfidenceKey.self] }
        set { self[SeatLayerPickerSeatConfidenceKey.self] = newValue }
    }
}

extension View {
    /// Take the buyer's request to see how a seat's view was made.
    public func seatLayerOnSeatConfidence(
        _ handler: SeatLayerPickerSeatConfidenceHandler?
    ) -> some View {
        environment(\.seatLayerOnSeatConfidence, handler)
    }
}
#endif

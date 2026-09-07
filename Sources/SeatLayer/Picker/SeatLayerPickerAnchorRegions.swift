import Foundation

/// Where a floating control stands on the map.
///
/// Every piece of chrome drawn inside the map's rectangle belongs to one of
/// these seven regions, and nothing free-floats: a control positioned against
/// a number of its own is a control that will one day be drawn on top of
/// another one. The regions are the map's own edges plus the insets the design
/// tokens name, so a control moves by changing which region it is in rather
/// than by changing a padding.
///
/// Pure, so the arithmetic every chrome component depends on is exercised by
/// the macOS unit suite rather than by a simulator.
public enum SeatLayerPickerMapAnchorRegion: String, Sendable, CaseIterable {
    /// Test chip, and the immersive back pill it steps below.
    case topLeading
    /// The Map | 3D segmented control.
    case topTrailing
    /// The floor rail, from the map's own top edge.
    case leadingRail
    /// Empty on a phone by default; the colourblind disc where a host asks.
    case bottomLeading
    /// The control column: accessibility, `+`, whole venue.
    case bottomTrailing
    /// Toasts and the hold-extend prompt.
    case bottomCentre
    /// Seat card, prompts and the buyer-facing status overlays.
    case centre
}

/// The four edge distances one anchor region keeps from the map's own edges.
///
/// Only the edges the region is anchored to carry a number; the others are
/// nil, so a caller cannot accidentally pin a bottom-trailing control to the
/// top of the map.
public struct SeatLayerPickerAnchorInsets: Sendable, Equatable {
    public let top: Double?
    public let leading: Double?
    public let bottom: Double?
    public let trailing: Double?

    public init(top: Double? = nil, leading: Double? = nil, bottom: Double? = nil, trailing: Double? = nil) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

/// The measured facts one layout pass hands the anchor regions.
///
/// `bottomLift` is §2.5's answer to who owns the bottom safe inset: the dock
/// carries it where a host mounted one, and with no dock the bottom anchors
/// sit at `mapAnchorInset` from the map's own bottom edge with nothing
/// reported. The map's rectangle already ends above the cart sheet, which is a
/// row of the column rather than chrome on the map, so the sheet is not in
/// this number.
public struct SeatLayerPickerAnchorPlan: Sendable, Equatable {
    /// Distance from every map edge — `size.mapAnchorInset`.
    public let inset: Double
    /// Distance between two members of one region — `size.mapAnchorGap`.
    public let gap: Double
    /// Extra room at the foot for a mounted dock plus its safe inset.
    public let bottomLift: Double
    /// Height of the Map | 3D control where it is drawn on the same line as
    /// the leading rail, which is what pushes the floor rail down a line.
    public let topTrailingControlHeight: Double
    /// Height of the immersive scene's back pill, counted only while it is
    /// actually drawn.
    public let backPillHeight: Double

    public init(
        inset: Double = SeatLayerPickerSizeTokens.mapAnchorInset,
        gap: Double = SeatLayerPickerSizeTokens.mapAnchorGap,
        bottomLift: Double = 0,
        topTrailingControlHeight: Double = 0,
        backPillHeight: Double = 0
    ) {
        self.inset = max(0, inset)
        self.gap = max(0, gap)
        self.bottomLift = max(0, bottomLift)
        self.topTrailingControlHeight = max(0, topTrailingControlHeight)
        self.backPillHeight = max(0, backPillHeight)
    }

    /// The edges `region` is anchored to.
    public func insets(for region: SeatLayerPickerMapAnchorRegion) -> SeatLayerPickerAnchorInsets {
        switch region {
        case .topLeading:
            return SeatLayerPickerAnchorInsets(top: testChipTop, leading: inset)
        case .topTrailing:
            return SeatLayerPickerAnchorInsets(top: inset, trailing: inset)
        case .leadingRail:
            return SeatLayerPickerAnchorInsets(top: leadingRailTop, leading: 0, trailing: 0)
        case .bottomLeading:
            return SeatLayerPickerAnchorInsets(leading: inset, bottom: inset + bottomLift)
        case .bottomTrailing:
            return SeatLayerPickerAnchorInsets(bottom: inset + bottomLift, trailing: inset)
        case .bottomCentre:
            return SeatLayerPickerAnchorInsets(leading: inset, bottom: inset + bottomLift, trailing: inset)
        case .centre:
            return SeatLayerPickerAnchorInsets()
        }
    }

    /// The gap between two members of `region`.
    ///
    /// The control column is tighter than the rest: three discs of one subject
    /// read as one control at `size.zoomColumnGap`, and at the map's own gap
    /// they read as three separate ones.
    public func gap(for region: SeatLayerPickerMapAnchorRegion) -> Double {
        region == .bottomTrailing ? SeatLayerPickerSizeTokens.zoomColumnGap : gap
    }

    /// Where the test chip starts.
    ///
    /// One line below the immersive scene's back pill, and only while that
    /// pill is actually drawn — not merely whenever the scene is up. A step
    /// keyed to "the scene is showing" leaves a gap on every scene that draws
    /// no pill.
    public var testChipTop: Double {
        backPillHeight > 0 ? inset + backPillHeight + gap : inset
    }

    /// Where the floor rail starts: the map's own top line, or one line under
    /// the Map | 3D control when that shares the line. The rail runs the map's
    /// full width, so the two would otherwise be drawn over each other.
    public var leadingRailTop: Double {
        topTrailingControlHeight > 0 ? inset + topTrailingControlHeight + gap : inset
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Native title/caption/actions over renderer-owned seat panorama pixels.
public struct SeatLayerSeatViewChrome: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @Environment(\.seatLayerPickerStyle) private var style
    private let topInset: Double
    private let bottomInset: Double
    private let showDragHint: Bool

    public init(
        topInset: Double = 10,
        bottomInset: Double = 10,
        showDragHint: Bool = true
    ) {
        self.topInset = max(0, topInset)
        self.bottomInset = max(0, bottomInset)
        self.showDragHint = showDragHint
    }

    public var body: some View {
        let availability = SeatLayerPickerImmersive.availability(
            snapshot: controller.snapshot,
            bundle: controller.bundleInfo,
            seatView: controller.seatView
        )
        if availability.panoramaChrome,
           let seatView = controller.seatView {
            let wording = SeatLayerPickerImmersive.panoramaWording(seatView)
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            if let title = wording.title {
                                Text(title)
                                    .seatLayerPickerFont(size: 14, weight: .heavy)
                                    .lineLimit(2)
                            }
                            if let caption = wording.caption {
                                Text(caption)
                                    .seatLayerPickerFont(size: 12, weight: .semibold)
                                    .foregroundColor(
                                        SeatLayerPickerPalette.immersiveCaptionInk.opacity(mutedInk)
                                    )
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                        if let badge = wording.badge {
                            Text(badge)
                                .seatLayerPickerFont(size: 12, weight: .heavy)
                                .foregroundColor(SeatLayerPickerPalette.immersiveCaptionInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    SeatLayerPickerPalette.immersiveCaptionInk.opacity(
                                        seatView.real ? badgeRealWash : badgeWash
                                    )
                                )
                                .clipShape(Capsule())
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(SeatLayerPickerPalette.immersiveCaptionInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .seatLayerImmersiveCaptionGlass(radius: SeatLayerPickerRadiusTokens.chip)
                    if showDragHint, let hint = wording.dragHint {
                        Text(hint)
                            .seatLayerPickerFont(
                                size: SeatLayerPickerSizeTokens.immersiveCaptionFontSize,
                                weight: .semibold
                            )
                            .foregroundColor(
                                SeatLayerPickerPalette.immersiveCaptionInk.opacity(mutedInk)
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .seatLayerImmersiveCaptionGlass(
                                radius: SeatLayerPickerRadiusTokens.chip
                            )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(wording.summary ?? style.strings.text(.viewFromYourSeat))
            .accessibilityIdentifier("seatlayer-seat-view-chrome")
            .transition(.opacity)
        }
    }

    // tokens.json gap: how much of the caption ink the secondary lines and
    // the disclosure badge's ground take.
    private let mutedInk = 0.72
    private let badgeWash = 0.14
    private let badgeRealWash = 0.24
}
#endif

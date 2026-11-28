import SwiftUI
import UIKit
import XCTest
@testable import SeatLayer

/// The seat card's two answers in every language the picker speaks, on the
/// narrowest phones, at the largest text: no answer is cut.
///
/// Label widths come from the same measure the card uses to lay the answers
/// out, so these run in a simulator, where the system font is the one the card
/// draws with.
@available(iOS 16.0, *)
final class SeatCardAnswerFitTests: XCTestCase {
    private let phones: [Double] = [320, 375, 390]

    func testNoAnswerIsCutInAnyLanguageAtTheLargestText() {
        let largest = DynamicTypeSize.accessibility5
        let action = SeatLayerPickerSizeTokens.confirmActionHeight
            * min(SeatLayerPickerTypeScaleTokens.card, seatLayerPickerTypeScale(largest))
        var cut: [String] = []
        var stacked: [String] = []
        for locale in SeatLayerPickerStrings.supportedLocales {
            let strings = SeatLayerPickerStrings(localeIdentifier: locale)
            let cancel = seatLayerPickerAnswerLabelWidth(
                strings.text(.cancel),
                dynamicTypeSize: largest
            )
            let receipt = seatLayerPickerAnswerLabelWidth(
                strings.text(.added),
                dynamicTypeSize: largest
            )
            for key in [SeatLayerPickerStringKey.addSeat, .select, .removeSeat] {
                let primary = max(
                    receipt,
                    seatLayerPickerAnswerLabelWidth(strings.text(key), dynamicTypeSize: largest)
                )
                for phone in phones {
                    // The card is the screen less its gutters, at most 310
                    // points, and the row is the card less 10 points a side.
                    let row = min(
                        SeatLayerPickerSizeTokens.confirmCardMaxWidth,
                        phone - 2 * SeatLayerPickerSizeTokens.confirmCardGutter
                    ) - 20
                    for reserved in [0, action + seatLayerPickerAnswerGap] {
                        let name = "\(locale) \(key.rawValue) \(Int(phone)) 3D=\(reserved > 0)"
                        switch seatLayerPickerAnswerLayout(
                            available: row,
                            reservedFor3D: reserved,
                            cancelLabel: cancel,
                            primaryLabel: primary
                        ) {
                        case let .row(cancelWidth):
                            let room = row - reserved - seatLayerPickerAnswerGap
                            if cancelWidth < cancel + seatLayerPickerCancelChrome
                                || room - cancelWidth
                                    < primary * seatLayerPickerPrimaryMinimumScale
                                    + seatLayerPickerPrimaryChrome {
                                cut.append(name)
                            }
                        case .stacked:
                            stacked.append(name)
                            // Each answer on a line of its own: Cancel after
                            // the 3D square, the primary answer the full row.
                            if row - reserved < cancel + seatLayerPickerCancelChrome
                                || row < primary * seatLayerPickerPrimaryMinimumScale
                                + seatLayerPickerPrimaryChrome {
                                cut.append(name + " (stacked)")
                            }
                        }
                    }
                }
            }
        }
        XCTAssertEqual(cut, [], "answers cut at the largest text")
        print("SeatCardAnswerFit stacked: \(stacked.count) — \(stacked.joined(separator: ", "))")
    }

    /// English on a 390-point phone keeps the answers side by side, with the
    /// 3D square in the row: "Cancel" takes the width it needs.
    func testEnglishStaysSideBySideOnA390PointPhone() {
        let largest = DynamicTypeSize.accessibility5
        let strings = SeatLayerPickerStrings(localeIdentifier: "en")
        let action = SeatLayerPickerSizeTokens.confirmActionHeight
            * min(SeatLayerPickerTypeScaleTokens.card, seatLayerPickerTypeScale(largest))
        let layout = seatLayerPickerAnswerLayout(
            available: 290,
            reservedFor3D: action + seatLayerPickerAnswerGap,
            cancelLabel: seatLayerPickerAnswerLabelWidth(
                strings.text(.cancel),
                dynamicTypeSize: largest
            ),
            primaryLabel: seatLayerPickerAnswerLabelWidth(
                strings.text(.addSeat),
                dynamicTypeSize: largest
            )
        )
        guard case let .row(cancelWidth) = layout else {
            return XCTFail("expected the answers side by side, got \(layout)")
        }
        let share = (290 - action - 2 * seatLayerPickerAnswerGap) * seatLayerPickerCardCancelShare
        XCTAssertGreaterThan(cancelWidth, share, "Cancel needs more than its 34% here")
    }
}

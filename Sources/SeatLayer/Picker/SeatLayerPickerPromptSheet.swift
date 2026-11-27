#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// The bottom sheet a decision prompt stands in: rounded top corners, hard
/// against the bottom edge, as tall as its content.
///
/// A prompt taller than the room it is given (a short phone, large text, a
/// long list of ticket types) scrolls instead of running off the screen, and
/// it opens at its foot, so the answers are in sight from the start.
struct SeatLayerPickerPromptSheet<Content: View>: View {
    let surface: Color
    let content: Content
    @State private var contentHeight: Double = 0

    init(surface: Color, @ViewBuilder content: () -> Content) {
        self.surface = surface
        self.content = content()
    }

    var body: some View {
        GeometryReader { room in
            let fits = !seatLayerPickerPromptScrolls(content: contentHeight, room: room.size.height)
            ScrollViewReader { reader in
                ScrollView(.vertical, showsIndicators: !fits) {
                    VStack(spacing: 0) {
                        content
                        Color.clear.frame(height: 0).id(Self.foot)
                    }
                    .background {
                        GeometryReader { measured in
                            Color.clear.preference(
                                key: SeatLayerPickerPromptHeightKey.self,
                                value: measured.size.height
                            )
                        }
                    }
                }
                .scrollDisabledIfPossible(fits)
                .onPreferenceChange(SeatLayerPickerPromptHeightKey.self) { height in
                    guard height.isFinite, height > 0, height != contentHeight else { return }
                    contentHeight = height
                    reader.scrollTo(Self.foot, anchor: .bottom)
                }
            }
            .frame(height: min(max(contentHeight, 1), room.size.height))
            .background(surface)
            .clipShape(UnevenRoundedRectangleCompat(
                topLeading: SeatLayerPickerRadiusTokens.sheet,
                topTrailing: SeatLayerPickerRadiusTokens.sheet
            ))
            .shadow(color: .black.opacity(0.24), radius: 18, y: -4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private static var foot: String { "seatlayer-prompt-foot" }
}

private struct SeatLayerPickerPromptHeightKey: PreferenceKey {
    static let defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = max(value, nextValue())
    }
}
#endif

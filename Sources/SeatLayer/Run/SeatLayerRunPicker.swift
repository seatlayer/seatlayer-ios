#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// The buyer pressed continue on the run page. Take the hold to your checkout.
public typealias SeatLayerRunContinueHandler = @MainActor (SeatLayerRunHandoff) async -> Void

/// The complete run picker: the bar the event picker wears (brand mark, name,
/// hold clock, close) over the run page, which draws the performances, the
/// map, the seat card and the cart.
public struct SeatLayerRunPicker: View {
    private let configuration: SeatLayerRunConfiguration
    private let controller: SeatLayerRunController?
    private let theme: SeatLayerPickerTheme
    private let themeMode: SeatLayerPickerThemeMode
    private let strings: SeatLayerPickerStrings
    private let onContinue: SeatLayerRunContinueHandler
    private let onBooked: ((SeatLayerRunHandoff) -> Void)?
    private let onClose: (() -> Void)?

    /// - Parameters:
    ///   - strings: The bar's words. Pass the language the page speaks:
    ///     `configuration.locale` is used when `strings` names none.
    ///   - onContinue: The buyer pressed continue: take the hold to checkout.
    ///   - onBooked: A hold is booked, after `controller.markBooked`.
    ///   - onClose: The close button. Without it the bar has none.
    public init(
        configuration: SeatLayerRunConfiguration,
        controller: SeatLayerRunController? = nil,
        theme: SeatLayerPickerTheme = .init(),
        themeMode: SeatLayerPickerThemeMode = .auto,
        strings: SeatLayerPickerStrings = .init(),
        onContinue: @escaping SeatLayerRunContinueHandler,
        onBooked: ((SeatLayerRunHandoff) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.controller = controller
        self.theme = theme
        self.themeMode = themeMode
        var merged = strings
        if merged.localeIdentifier == nil { merged.localeIdentifier = configuration.locale }
        self.strings = merged
        self.onContinue = onContinue
        self.onBooked = onBooked
        self.onClose = onClose
    }

    public var body: some View {
        SeatLayerRunPickerOwner(given: controller) { controller in
            SeatLayerRunPickerLayout(
                controller: controller,
                configuration: configuration,
                themeMode: themeMode,
                onContinue: onContinue,
                onBooked: onBooked,
                onClose: onClose
            )
            .environment(
                \.seatLayerPickerStyle,
                SeatLayerPickerStyleEnvironment(mode: themeMode, theme: theme, strings: strings)
            )
            .environment(\.locale, strings.resolvedLocale)
            .environment(\.layoutDirection, strings.usesRightToLeftLayout ? .rightToLeft : .leftToRight)
        }
    }
}

/// Holds the picker's own controller when the app gives none.
private struct SeatLayerRunPickerOwner<Content: View>: View {
    @StateObject private var owned = SeatLayerRunController()
    let given: SeatLayerRunController?
    @ViewBuilder let content: (SeatLayerRunController) -> Content

    var body: some View { content(given ?? owned) }
}

private struct SeatLayerRunPickerLayout: View {
    @ObservedObject var controller: SeatLayerRunController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    let configuration: SeatLayerRunConfiguration
    let themeMode: SeatLayerPickerThemeMode
    let onContinue: SeatLayerRunContinueHandler
    let onBooked: ((SeatLayerRunHandoff) -> Void)?
    let onClose: (() -> Void)?
    /// A new page after the buyer's retry.
    @State private var page = 0
    @State private var closing = false
    @State private var sentBottomInset: Double?
    @State private var insetsRefused = false
    /// The side the page opened on, kept for the picker's life: the page
    /// does not change sides while it is up.
    @State private var bootScheme: ColorScheme?

    var body: some View {
        let scheme = bootScheme ?? colorScheme
        let palette = resolveSeatLayerPickerPalette(
            style: style,
            colorScheme: scheme,
            branding: controller.status?.branding
        )
        let wide = sizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
        GeometryReader { geometry in
            let bottomInset = geometry.safeAreaInsets.bottom
            VStack(spacing: 0) {
                SeatLayerHeaderBar(
                    palette: palette,
                    // Until the page names the run, the bar keeps the event
                    // picker's loading words.
                    title: controller.descriptor?.name,
                    venue: nil,
                    logoURL: controller.status?.branding?.logoURL,
                    showsDetails: true,
                    compact: !wide,
                    onClose: onClose == nil ? nil : requestClose
                ) {
                    if let hold = controller.hold {
                        SeatLayerHoldClock(
                            expiresAt: hold.expiresAt.timeIntervalSince1970 * 1000,
                            palette: palette,
                            // While the page's line is down, 0:00 waits for
                            // the server's word.
                            awaitingServer: controller.connection?.lineDown == true
                        )
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                ZStack {
                    if case .failed(let error) = controller.phase {
                        SeatLayerFailurePanel(
                            error: error,
                            retryable: error.isRetryable,
                            palette: palette,
                            owner: controller,
                            retry: retry
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        SeatLayerRunMap(
                            configuration: configuration,
                            controller: controller,
                            themeMode: themeMode == .auto ? (scheme == .dark ? .dark : .light) : themeMode
                        )
                        .id(page)
                        .accessibilityIdentifier("seatlayer-run-map")
                        // A page that takes the inset runs its cart under the
                        // home indicator; for one that does not, the app keeps
                        // it clear, on the cart's surface.
                        .padding(.bottom, pageTakesInsets ? 0 : bottomInset)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(pageTakesInsets ? palette.mapBackground : palette.surface)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear { follow(bottomInset) }
            .onChange(of: bottomInset) { follow($0) }
            .onChange(of: controller.isReady) { ready in
                if ready {
                    // A page that just booted knows no insets.
                    sentBottomInset = nil
                    insetsRefused = false
                    follow(bottomInset)
                }
            }
        }
        .background(palette.background)
        .onAppear { if bootScheme == nil { bootScheme = colorScheme } }
        .onReceive(controller.continues) { handoff in
            Task { @MainActor in await onContinue(handoff) }
        }
        .onReceive(controller.bookings) { handoff in onBooked?(handoff) }
        .onChange(of: scenePhase) { phase in
            guard controller.isReady else { return }
            switch phase {
            case .active: Task { _ = try? await controller.setForeground(true) }
            case .background: Task { _ = try? await controller.setForeground(false) }
            default: break
            }
        }
    }

    /// Whether the page keeps its cart clear of the home indicator itself,
    /// from the inset the app sends. Without it the app keeps a band.
    private var pageTakesInsets: Bool {
        controller.isReady && !insetsRefused && controller.supports(command: "group.setViewportInsets")
    }

    private func follow(_ bottomInset: Double) {
        guard pageTakesInsets, bottomInset != sentBottomInset else { return }
        sentBottomInset = bottomInset
        Task { @MainActor in
            do {
                try await controller.setViewportInsets(bottom: bottomInset)
            } catch {
                // The page did not take it: the app keeps the band.
                insetsRefused = true
            }
        }
    }

    private func retry() {
        controller.phase = .loading
        page += 1
    }

    private func requestClose() {
        guard !closing else { return }
        closing = true
        Task { @MainActor in
            await controller.destroy()
            closing = false
            onClose?()
        }
    }
}
#endif

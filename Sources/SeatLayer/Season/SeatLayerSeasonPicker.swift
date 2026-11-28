#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// The buyer pressed continue on the Season page. Book the hold on your server.
public typealias SeatLayerSeasonContinueHandler = @MainActor (SeatLayerSeasonHandoff) async -> Void

/// The complete Season picker: the bar the event picker wears (brand mark,
/// the Season's name, hold clock, close) over the Season page, which draws the
/// package, the dates, the map and the cart.
public struct SeatLayerSeasonPicker: View {
    private let configuration: SeatLayerSeasonConfiguration
    private let controller: SeatLayerSeasonController?
    private let theme: SeatLayerPickerTheme
    private let themeMode: SeatLayerPickerThemeMode
    private let strings: SeatLayerPickerStrings
    private let onContinue: SeatLayerSeasonContinueHandler
    private let onBooked: ((SeatLayerSeasonHandoff) -> Void)?
    private let onClose: ((SeatLayerSeasonClose) -> Void)?

    /// - Parameters:
    ///   - themeMode: Which side to paint. `.auto` follows the app live, with
    ///     no reload.
    ///   - strings: The bar's words. Pass the language the page speaks:
    ///     `configuration.locale` is used when `strings` names none.
    ///   - onContinue: The buyer pressed continue: book the hold on your server.
    ///   - onBooked: A hold is booked, after `controller.markBooked`.
    ///   - onClose: The buyer closed the Season, and how: with seats held the
    ///     page first asks whether to release or keep them. Without it the bar
    ///     has no close button.
    public init(
        configuration: SeatLayerSeasonConfiguration,
        controller: SeatLayerSeasonController? = nil,
        theme: SeatLayerPickerTheme = .init(),
        themeMode: SeatLayerPickerThemeMode = .auto,
        strings: SeatLayerPickerStrings = .init(),
        onContinue: @escaping SeatLayerSeasonContinueHandler,
        onBooked: ((SeatLayerSeasonHandoff) -> Void)? = nil,
        onClose: ((SeatLayerSeasonClose) -> Void)? = nil
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
        SeatLayerSeasonPickerOwner(given: controller) { controller in
            SeatLayerSeasonPickerLayout(
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
private struct SeatLayerSeasonPickerOwner<Content: View>: View {
    @StateObject private var owned = SeatLayerSeasonController()
    let given: SeatLayerSeasonController?
    @ViewBuilder let content: (SeatLayerSeasonController) -> Content

    var body: some View { content(given ?? owned) }
}

private struct SeatLayerSeasonPickerLayout: View {
    @ObservedObject var controller: SeatLayerSeasonController
    @Environment(\.seatLayerPickerStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    let configuration: SeatLayerSeasonConfiguration
    let themeMode: SeatLayerPickerThemeMode
    let onContinue: SeatLayerSeasonContinueHandler
    let onBooked: ((SeatLayerSeasonHandoff) -> Void)?
    let onClose: ((SeatLayerSeasonClose) -> Void)?
    /// A new page after the buyer's retry.
    @State private var page = 0
    /// Whether a page was up: the next one opens on the buyer's last hold.
    @State private var pageWasUp = false
    @State private var closing = false
    @State private var sentBottomInset: Double?
    @State private var insetsRefused = false
    /// The side a page opens on, kept for the picker's life: a change of side
    /// is sent to the page, which repaints in place.
    @State private var bootScheme: ColorScheme?
    /// The side the page is painted on now.
    @State private var pageScheme: ColorScheme?

    var body: some View {
        let scheme = pageScheme ?? bootScheme ?? colorScheme
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
                    // Until the page names the Season, the bar keeps the event
                    // picker's loading words.
                    title: controller.status?.seasonName,
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
                        SeatLayerSeasonMap(
                            configuration: configuration,
                            controller: controller,
                            themeMode: bootMode,
                            again: pageWasUp
                        )
                        .id(page)
                        .accessibilityIdentifier("seatlayer-season-map")
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
                guard ready else { return }
                pageWasUp = true
                // A page that just booted is on its boot side, with no insets.
                pageScheme = nil
                sentBottomInset = nil
                insetsRefused = false
                follow(bottomInset)
                followTheme(colorScheme)
            }
        }
        .background(palette.background)
        .onAppear { if bootScheme == nil { bootScheme = colorScheme } }
        .onChange(of: colorScheme) { followTheme($0) }
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

    /// The side every page of this picker opens on.
    private var bootMode: SeatLayerPickerThemeMode {
        guard themeMode == .auto else { return themeMode }
        return (bootScheme ?? colorScheme) == .dark ? .dark : .light
    }

    /// Whether the page keeps its cart clear of the home indicator itself,
    /// from the inset the app sends. Without it the app keeps a band.
    private var pageTakesInsets: Bool {
        controller.isReady && !insetsRefused && controller.supports(command: "season.setViewportInsets")
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

    /// The app changed sides: the page repaints in place, as a reload would
    /// lose the buyer's place. A page that cannot stays on its boot side, and
    /// so does the bar.
    private func followTheme(_ scheme: ColorScheme) {
        guard themeMode == .auto,
              controller.isReady,
              controller.supports(command: "season.setThemeMode"),
              scheme != (pageScheme ?? bootScheme) else { return }
        pageScheme = scheme
        Task { @MainActor in try? await controller.setThemeMode(scheme == .dark ? .dark : .light) }
    }

    private func retry() {
        controller.phase = .loading
        page += 1
    }

    /// Each press is sent: a second one while the page's question is up
    /// dismisses it, and both answer that the buyer stayed.
    private func requestClose() {
        guard !closing else { return }
        Task { @MainActor in
            guard let close = try? await controller.requestClose(), close.outcome.closes, !closing else {
                // Stayed, or the page kept the seats and said why on its own
                // status line.
                return
            }
            closing = true
            await controller.destroy()
            closing = false
            onClose?(close)
        }
    }
}
#endif

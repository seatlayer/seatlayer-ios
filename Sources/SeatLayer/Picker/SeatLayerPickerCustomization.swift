#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
#endif

/// Stable ownership points for replacing complete picker parts.
/// Required attribution and truthful test-mode status are intentionally absent.
public enum SeatLayerPickerPart: String, CaseIterable, Sendable, Hashable {
    case header
    case legend
    case floorSelector
    case floorStrip
    case sectionNavigator
    case dockBar
    case accessibilityFilters
    case map
    case mapControls
    case bestAvailable
    case seatConfirmation
    case confirmCard
    case generalAdmissionPrompt
    case tablePrompt
    case cartList
    case cartSheet
    case venue3D
    case seatViewChrome
    case holdCountdown
    case holdLapse
    case actionError
    case checkoutBar
    case loading
    case error
    case empty
}

#if canImport(SwiftUI) && canImport(UIKit)

/// Aesthetic adjustments that do not change inventory or component ownership.
public struct SeatLayerPickerPartStyle: Sendable, Equatable {
    public var background: String?
    public var border: String?
    public var borderWidth: Double
    public var cornerRadius: Double?
    public var opacity: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double

    public init(
        background: String? = nil,
        border: String? = nil,
        borderWidth: Double = 0,
        cornerRadius: Double? = nil,
        opacity: Double = 1,
        horizontalPadding: Double = 0,
        verticalPadding: Double = 0
    ) {
        self.background = background
        self.border = border
        self.borderWidth = max(0, borderWidth)
        self.cornerRadius = cornerRadius.map { max(0, $0) }
        self.opacity = min(1, max(0, opacity))
        self.horizontalPadding = max(0, horizontalPadding)
        self.verticalPadding = max(0, verticalPadding)
    }
}

/// Named visual slots shared by the ready-made tree and custom builders.
public struct SeatLayerPickerStyles: Sendable, Equatable {
    public var parts: [SeatLayerPickerPart: SeatLayerPickerPartStyle]

    public init(parts: [SeatLayerPickerPart: SeatLayerPickerPartStyle] = [:]) {
        self.parts = parts
    }

    public subscript(part: SeatLayerPickerPart) -> SeatLayerPickerPartStyle? {
        get { parts[part] }
        set { parts[part] = newValue }
    }
}

/// Live, scoped input supplied to every whole-part replacement.
/// `defaultContent` is the same public component used by the ready-made picker.
@MainActor
public struct SeatLayerPickerPartContext {
    public let part: SeatLayerPickerPart
    public let snapshot: SeatLayerPickerSnapshot?
    public let controller: SeatLayerPickerController
    public let presentation: SeatLayerPickerPresentationModel
    public let themeMode: SeatLayerPickerThemeMode
    public let theme: SeatLayerPickerTheme
    public let strings: SeatLayerPickerStrings
    public let options: SeatLayerPickerOptions
    public let style: SeatLayerPickerPartStyle?
    public let defaultContent: AnyView
}

public typealias SeatLayerPickerPartBuilder = @MainActor (SeatLayerPickerPartContext) -> AnyView

/// Optional replacements for the canonical 25 public picker parts.
public struct SeatLayerPickerBuilders {
    public var header: SeatLayerPickerPartBuilder?
    public var legend: SeatLayerPickerPartBuilder?
    public var floorSelector: SeatLayerPickerPartBuilder?
    public var floorStrip: SeatLayerPickerPartBuilder?
    public var sectionNavigator: SeatLayerPickerPartBuilder?
    public var dockBar: SeatLayerPickerPartBuilder?
    public var accessibilityFilters: SeatLayerPickerPartBuilder?
    public var map: SeatLayerPickerPartBuilder?
    public var mapControls: SeatLayerPickerPartBuilder?
    public var bestAvailable: SeatLayerPickerPartBuilder?
    public var seatConfirmation: SeatLayerPickerPartBuilder?
    public var confirmCard: SeatLayerPickerPartBuilder?
    public var generalAdmissionPrompt: SeatLayerPickerPartBuilder?
    public var tablePrompt: SeatLayerPickerPartBuilder?
    public var cartList: SeatLayerPickerPartBuilder?
    public var cartSheet: SeatLayerPickerPartBuilder?
    public var venue3D: SeatLayerPickerPartBuilder?
    public var seatViewChrome: SeatLayerPickerPartBuilder?
    public var holdCountdown: SeatLayerPickerPartBuilder?
    public var holdLapse: SeatLayerPickerPartBuilder?
    public var actionError: SeatLayerPickerPartBuilder?
    public var checkoutBar: SeatLayerPickerPartBuilder?
    public var loading: SeatLayerPickerPartBuilder?
    public var error: SeatLayerPickerPartBuilder?
    public var empty: SeatLayerPickerPartBuilder?

    public init(
        header: SeatLayerPickerPartBuilder? = nil,
        legend: SeatLayerPickerPartBuilder? = nil,
        floorSelector: SeatLayerPickerPartBuilder? = nil,
        floorStrip: SeatLayerPickerPartBuilder? = nil,
        sectionNavigator: SeatLayerPickerPartBuilder? = nil,
        dockBar: SeatLayerPickerPartBuilder? = nil,
        accessibilityFilters: SeatLayerPickerPartBuilder? = nil,
        map: SeatLayerPickerPartBuilder? = nil,
        mapControls: SeatLayerPickerPartBuilder? = nil,
        bestAvailable: SeatLayerPickerPartBuilder? = nil,
        seatConfirmation: SeatLayerPickerPartBuilder? = nil,
        confirmCard: SeatLayerPickerPartBuilder? = nil,
        generalAdmissionPrompt: SeatLayerPickerPartBuilder? = nil,
        tablePrompt: SeatLayerPickerPartBuilder? = nil,
        cartList: SeatLayerPickerPartBuilder? = nil,
        cartSheet: SeatLayerPickerPartBuilder? = nil,
        venue3D: SeatLayerPickerPartBuilder? = nil,
        seatViewChrome: SeatLayerPickerPartBuilder? = nil,
        holdCountdown: SeatLayerPickerPartBuilder? = nil,
        holdLapse: SeatLayerPickerPartBuilder? = nil,
        actionError: SeatLayerPickerPartBuilder? = nil,
        checkoutBar: SeatLayerPickerPartBuilder? = nil,
        loading: SeatLayerPickerPartBuilder? = nil,
        error: SeatLayerPickerPartBuilder? = nil,
        empty: SeatLayerPickerPartBuilder? = nil
    ) {
        self.header = header
        self.legend = legend
        self.floorSelector = floorSelector
        self.floorStrip = floorStrip
        self.sectionNavigator = sectionNavigator
        self.dockBar = dockBar
        self.accessibilityFilters = accessibilityFilters
        self.map = map
        self.mapControls = mapControls
        self.bestAvailable = bestAvailable
        self.seatConfirmation = seatConfirmation
        self.confirmCard = confirmCard
        self.generalAdmissionPrompt = generalAdmissionPrompt
        self.tablePrompt = tablePrompt
        self.cartList = cartList
        self.cartSheet = cartSheet
        self.venue3D = venue3D
        self.seatViewChrome = seatViewChrome
        self.holdCountdown = holdCountdown
        self.holdLapse = holdLapse
        self.actionError = actionError
        self.checkoutBar = checkoutBar
        self.loading = loading
        self.error = error
        self.empty = empty
    }

    public subscript(part: SeatLayerPickerPart) -> SeatLayerPickerPartBuilder? {
        switch part {
        case .header: return header
        case .legend: return legend
        case .floorSelector: return floorSelector
        case .floorStrip: return floorStrip
        case .sectionNavigator: return sectionNavigator
        case .dockBar: return dockBar
        case .accessibilityFilters: return accessibilityFilters
        case .map: return map
        case .mapControls: return mapControls
        case .bestAvailable: return bestAvailable
        case .seatConfirmation: return seatConfirmation
        case .confirmCard: return confirmCard
        case .generalAdmissionPrompt: return generalAdmissionPrompt
        case .tablePrompt: return tablePrompt
        case .cartList: return cartList
        case .cartSheet: return cartSheet
        case .venue3D: return venue3D
        case .seatViewChrome: return seatViewChrome
        case .holdCountdown: return holdCountdown
        case .holdLapse: return holdLapse
        case .actionError: return actionError
        case .checkoutBar: return checkoutBar
        case .loading: return loading
        case .error: return error
        case .empty: return empty
        }
    }
}

private struct SeatLayerPickerBuildersKey: EnvironmentKey {
    static let defaultValue = SeatLayerPickerBuilders()
}

private struct SeatLayerPickerStylesKey: EnvironmentKey {
    static let defaultValue = SeatLayerPickerStyles()
}

extension EnvironmentValues {
    var seatLayerPickerBuilders: SeatLayerPickerBuilders {
        get { self[SeatLayerPickerBuildersKey.self] }
        set { self[SeatLayerPickerBuildersKey.self] = newValue }
    }

    var seatLayerPickerStyles: SeatLayerPickerStyles {
        get { self[SeatLayerPickerStylesKey.self] }
        set { self[SeatLayerPickerStylesKey.self] = newValue }
    }
}

struct SeatLayerPickerPartHost<DefaultContent: View>: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    @EnvironmentObject private var presentation: SeatLayerPickerPresentationModel
    @Environment(\.seatLayerPickerStyle) private var pickerStyle
    @Environment(\.seatLayerPickerBuilders) private var builders
    @Environment(\.seatLayerPickerStyles) private var styles
    let part: SeatLayerPickerPart
    let defaultContent: () -> DefaultContent

    init(_ part: SeatLayerPickerPart, @ViewBuilder defaultContent: @escaping () -> DefaultContent) {
        self.part = part
        self.defaultContent = defaultContent
    }

    var body: some View {
        let child = AnyView(defaultContent())
        let rendered = builders[part]?(
            SeatLayerPickerPartContext(
                part: part,
                snapshot: controller.snapshot,
                controller: controller,
                presentation: presentation,
                themeMode: pickerStyle.mode,
                theme: pickerStyle.theme,
                strings: pickerStyle.strings,
                options: pickerStyle.options,
                style: styles[part],
                defaultContent: child
            )
        ) ?? child
        rendered.modifier(SeatLayerPickerPartStyleModifier(style: styles[part]))
    }
}

private struct SeatLayerPickerPartStyleModifier: ViewModifier {
    let style: SeatLayerPickerPartStyle?

    func body(content: Content) -> some View {
        let radius = style?.cornerRadius ?? 0
        content
            .padding(.horizontal, style?.horizontalPadding ?? 0)
            .padding(.vertical, style?.verticalPadding ?? 0)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: style?.borderWidth ?? 0)
            }
            .opacity(style?.opacity ?? 1)
    }

    private var background: Color {
        style?.background.flatMap(UIColor.init(slHex:)).map(Color.init(uiColor:)) ?? .clear
    }

    private var border: Color {
        style?.border.flatMap(UIColor.init(slHex:)).map(Color.init(uiColor:)) ?? .clear
    }
}
#endif

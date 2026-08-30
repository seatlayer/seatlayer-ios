import Foundation

/// Internal handshake contract for one hosted renderer surface.
///
/// The raw chart and the native picker intentionally have different protocol
/// ranges. Keeping that choice in a value prevents an additive picker release
/// from silently changing the source-compatible `SeatLayerView` handshake.
struct SeatLayerBridgeProfile: Sendable, Equatable {
    enum Surface: String, Sendable {
        case chart
        case picker
    }

    static let raw = SeatLayerBridgeProfile(
        surface: .chart,
        protocolRange: ProtocolRange(min: 1, max: 1)
    )

    static func picker(
        enable3D: Bool = true,
        enableSeatView: Bool = true,
        config: [String: JSONValue] = [:]
    ) -> SeatLayerBridgeProfile {
        var capabilities = [
            "picker-session-v2",
            "picker-snapshot-v1",
            "picker-actions-v1",
            "native-picker-chrome-v1",
            "native-chrome-contract-v1",
            "checkout-handoff-v1",
            "checkout-handoff-reject-v1",
            "hold-ownership-v1",
            "cart-line-remove-v1",
            "table-quantity-v1",
        ]
        var commands = [
            "picker.getSnapshot",
            "picker.selectObjects",
            "picker.deselectObjects",
            "picker.clearSelection",
            "picker.selectCategories",
            "picker.deselectCategories",
            "picker.setSeatTier",
            "picker.removeCartLine",
            "picker.setTableQuantity",
            "picker.setSelectableObjects",
            "picker.setMaxSelection",
            "picker.setCategoryFilter",
            "picker.setAccessibilityFilter",
            "picker.setLimitedViewFilter",
            "picker.focusSection",
            "picker.overview",
            "picker.setRung",
            "picker.setFloor",
            "picker.setColorblindSafe",
            "picker.setThemeMode",
            "picker.setViewMode",
            "picker.setInteractionEnabled",
            "picker.zoomIn",
            "picker.zoomOut",
            "picker.zoomToFit",
            "picker.holdGA",
            "picker.bestAvailable",
            "picker.resumeHold",
            "picker.extendHold",
            "picker.continue",
            "picker.rejectHandoff",
            "picker.abort",
            "picker.lifecycle",
            "picker.destroy",
        ]

        if enable3D {
            capabilities.append(contentsOf: ["venue-3d-v1", "venue-3d-controls-v1"])
            commands.append(contentsOf: [
                "picker.setBuyerView",
                "picker.setVenue3DNavigationMode",
            ])
        }
        if enableSeatView {
            capabilities.append("seat-view-v1")
            commands.append("picker.openSeatView")
        }

        return SeatLayerBridgeProfile(
            surface: .picker,
            protocolRange: ProtocolRange(min: 2, max: 2),
            requiredCapabilities: capabilities,
            requiredCommands: commands,
            requiredEvents: ["picker.snapshot"],
            optionalCapabilities: [
                "native-seat-view-chrome-v1",
                "viewport-insets-v1",
                "floor-stack-v1",
                "chart-load-trace-v1",
                "availability-refresh-v1",
                "access-needs-v1",
                "hold-selection-v1",
            ],
            config: config
        )
    }

    let surface: Surface
    let protocolRange: ProtocolRange
    let requiredCapabilities: [String]
    let requiredCommands: [String]
    let requiredEvents: [String]
    let optionalCapabilities: [String]
    let config: [String: JSONValue]

    private init(
        surface: Surface,
        protocolRange: ProtocolRange,
        requiredCapabilities: [String] = [],
        requiredCommands: [String] = [],
        requiredEvents: [String] = [],
        optionalCapabilities: [String] = [],
        config: [String: JSONValue] = [:]
    ) {
        self.surface = surface
        self.protocolRange = protocolRange
        self.requiredCapabilities = requiredCapabilities
        self.requiredCommands = requiredCommands
        self.requiredEvents = requiredEvents
        self.optionalCapabilities = optionalCapabilities
        self.config = config
    }

    var isPicker: Bool { surface == .picker }

    /// Fails closed when a surface cannot provide the complete contract this
    /// profile needs. Additive capabilities remain optional and are checked at
    /// the component/action boundary instead.
    func validate(_ bundle: BundleInfo) throws {
        switch negotiate(native: protocolRange, web: bundle.protocolRange) {
        case .incompatible(let reason):
            throw SeatLayerError.incompatible(
                native: protocolRange,
                web: bundle.protocolRange,
                reason: reason
            )
        case .agreed:
            break
        }

        let missingCapabilities = requiredCapabilities.filter {
            !bundle.supports(capability: $0)
        }
        let missingCommands = requiredCommands.filter {
            !bundle.supports(command: $0)
        }
        let advertisedEvents = Set(bundle.events)
        let missingEvents = requiredEvents.filter { !advertisedEvents.contains($0) }

        guard missingCapabilities.isEmpty,
              missingCommands.isEmpty,
              missingEvents.isEmpty else {
            var missing: [String] = []
            if !missingCapabilities.isEmpty {
                missing.append("capabilities: \(missingCapabilities.joined(separator: ", "))")
            }
            if !missingCommands.isEmpty {
                missing.append("commands: \(missingCommands.joined(separator: ", "))")
            }
            if !missingEvents.isEmpty {
                missing.append("events: \(missingEvents.joined(separator: ", "))")
            }
            throw SeatLayerError.incompatible(
                native: protocolRange,
                web: bundle.protocolRange,
                reason: "the bundle is missing required \(surface.rawValue) contract entries (\(missing.joined(separator: "; ")))"
            )
        }
    }

    /// Builds the handshake reply without changing the raw chart payload.
    func initPayload(
        configuration: SeatLayerConfiguration,
        bundle: BundleInfo? = nil
    ) -> JSONValue {
        let base = configuration.initPayload(protocolRange: protocolRange)
        guard isPicker, var fields = base.objectValue else { return base }

        var mergedConfig = fields["config"]?.objectValue ?? [:]
        mergedConfig.merge(config) { _, profileValue in profileValue }

        var chrome = fields["chrome"]?.objectValue ?? [:]
        chrome.merge([
            "owner": .string("native"),
            "seatTooltip": .bool(false),
            "testModeIndicator": .bool(false),
            "attribution": .bool(false),
        ]) { _, profileValue in profileValue }

        if let bundle,
           bundle.supports(capability: "native-seat-view-chrome-v1"),
           bundle.events.contains("seatView.changed") {
            chrome["seatViewTitle"] = .bool(false)
            chrome["seatViewCaption"] = .bool(false)
            chrome["seatViewBadge"] = .bool(false)
        }

        fields["surface"] = [
            "kind": .string("picker"),
            "stateContract": .int(1),
            "chromeOwner": .string("native"),
        ]
        fields["requirements"] = [
            "capabilities": .array(requiredCapabilities.map(JSONValue.string)),
        ]
        fields["chrome"] = .object(chrome)
        fields["config"] = .object(mergedConfig)
        return .object(fields)
    }
}

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
        /// The run page (`group.html`): a few performances of one run.
        case group
        /// The Season page (`season.html`): a package of dates, the same seat
        /// for each.
        case season
    }

    static let raw = SeatLayerBridgeProfile(
        surface: .chart,
        protocolRange: ProtocolRange(min: 1, max: 1)
    )

    /// The picker profile.
    ///
    /// Only the capabilities the session cannot run without are required.
    /// Everything else — every command, the snapshot event, and each additive
    /// capability — is read from the bundle's own `hello` tables at the call
    /// site and silently withheld when a runtime does not advertise it. A
    /// wrapper that failed the handshake over one missing command would refuse
    /// to boot against a runtime it could have degraded on.
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
            "checkout-handoff-v1",
            "checkout-handoff-reject-v1",
            "hold-ownership-v1",
            "cart-line-remove-v1",
            "table-quantity-v1",
        ]
        if enable3D {
            capabilities.append(contentsOf: ["venue-3d-v1", "venue-3d-controls-v1"])
        }
        if enableSeatView {
            capabilities.append("seat-view-v1")
        }

        return SeatLayerBridgeProfile(
            surface: .picker,
            protocolRange: ProtocolRange(min: 2, max: 2),
            requiredCapabilities: capabilities,
            optionalCapabilities: [
                // Read as gates, never required: a runtime without one draws
                // the chrome it can and says nothing about the rest.
                "native-chrome-contract-v1",
                "native-seat-view-chrome-v1",
                "viewport-insets-v1",
                "floor-stack-v1",
                "chart-load-trace-v1",
                "availability-refresh-v1",
                "access-needs-v1",
                "hold-selection-v1",
                "hold-mark-booked-v1",
                "host-pricing-v1",
                "seat-view-thumbnail-v1",
                "accessibility-focus-v1",
                "section-access-counts-v1",
                "connection-state-v1",
                // Present-only reads: the snapshot simply carries the extra
                // field, and chrome that cannot see it renders as before.
                "seat-screen-point-v1",
                "category-availability-v1",
            ],
            config: config
        )
    }

    /// The run page. The page draws the run; the app draws only its bar
    /// (brand, name, hold clock, close) and the failure view.
    static func group(config: [String: JSONValue] = [:]) -> SeatLayerBridgeProfile {
        SeatLayerBridgeProfile(
            surface: .group,
            protocolRange: ProtocolRange(min: 2, max: 2),
            requiredCapabilities: ["group-surface-v1", "group-app-shell-v1"],
            optionalCapabilities: ["connection-state-v1"],
            config: config
        )
    }

    /// The Season page. The page draws the package, the dates, the map and
    /// the cart; the app draws only its bar and the failure view.
    static func season(config: [String: JSONValue] = [:]) -> SeatLayerBridgeProfile {
        SeatLayerBridgeProfile(
            surface: .season,
            protocolRange: ProtocolRange(min: 2, max: 2),
            requiredCapabilities: ["season-surface-v1", "season-app-shell-v1"],
            optionalCapabilities: ["connection-state-v1"],
            config: config
        )
    }

    /// The same profile without one host config key.
    func removingConfig(_ key: String) -> SeatLayerBridgeProfile {
        var trimmed = config
        trimmed.removeValue(forKey: key)
        return replacingConfig(trimmed)
    }

    /// The same profile with these host config keys set.
    func settingConfig(_ values: [String: JSONValue]) -> SeatLayerBridgeProfile {
        replacingConfig(config.merging(values) { _, new in new })
    }

    private func replacingConfig(_ trimmed: [String: JSONValue]) -> SeatLayerBridgeProfile {
        SeatLayerBridgeProfile(
            surface: surface,
            protocolRange: protocolRange,
            requiredCapabilities: requiredCapabilities,
            requiredCommands: requiredCommands,
            requiredEvents: requiredEvents,
            optionalCapabilities: optionalCapabilities,
            config: trimmed
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
    /// A surface whose page reports to a native session: the picker, the run,
    /// the Season.
    var hostsSession: Bool { surface != .chart }
    /// A page that draws all but the app's bar: the run, the Season. Its
    /// events go to its session as they are.
    var isAppShellPage: Bool { surface == .group || surface == .season }
    /// The page's name in a handshake failure.
    var pageName: String {
        switch surface {
        case .chart, .picker: return "picker runtime"
        case .group: return "run page"
        case .season: return "Season page"
        }
    }

    /// The command that tears the page's surface down.
    var destroyCommand: String {
        switch surface {
        case .chart: return "destroy"
        case .picker: return "picker.destroy"
        case .group: return "group.destroy"
        case .season: return "season.destroy"
        }
    }

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
        configuration: any SeatLayerSurfaceLoading,
        bundle: BundleInfo? = nil
    ) -> JSONValue {
        surfaceInitPayload(
            configuration.initPayload(protocolRange: protocolRange),
            bundle: bundle
        )
    }

    /// Adds this surface's own fields to a configuration's handshake reply.
    func surfaceInitPayload(_ base: JSONValue, bundle: BundleInfo? = nil) -> JSONValue {
        guard surface != .chart, var fields = base.objectValue else { return base }
        if isAppShellPage {
            var merged = fields["config"]?.objectValue ?? [:]
            merged.merge(config) { _, profileValue in profileValue }
            fields["surface"] = ["kind": .string(surface.rawValue)]
            // A null here leaves out what the configuration would say.
            fields["config"] = .object(merged.filter { !$0.value.isNull })
            return .object(fields)
        }

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

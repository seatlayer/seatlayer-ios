#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Supplies one stable controller to a tree of custom picker components.
public struct SeatLayerPickerScope<Content: View>: View {
    @StateObject private var controller: SeatLayerPickerController
    private let content: (SeatLayerPickerController) -> Content

    public init(
        controller: SeatLayerPickerController? = nil,
        @ViewBuilder content: @escaping (SeatLayerPickerController) -> Content
    ) {
        _controller = StateObject(wrappedValue: controller ?? SeatLayerPickerController())
        self.content = content
    }

    public var body: some View {
        content(controller)
            .environmentObject(controller)
    }
}

/// SwiftUI map-only component for custom native compositions.
public struct SeatLayerPickerMap: UIViewRepresentable {
    public typealias UIViewType = SeatLayerPickerMapView

    private let configuration: SeatLayerConfiguration
    private let options: SeatLayerPickerOptions
    private let controller: SeatLayerPickerController
    private let themeMode: SeatLayerPickerThemeMode?
    private let mapTheme: SeatLayerPickerMapTheme?

    public init(
        configuration: SeatLayerConfiguration,
        options: SeatLayerPickerOptions = .init(),
        controller: SeatLayerPickerController,
        themeMode: SeatLayerPickerThemeMode? = .auto,
        mapTheme: SeatLayerPickerMapTheme? = nil
    ) {
        self.configuration = configuration
        self.options = options
        self.controller = controller
        self.themeMode = themeMode
        self.mapTheme = mapTheme
    }

    public func makeUIView(context: Context) -> SeatLayerPickerMapView {
        let view = SeatLayerPickerMapView(
            configuration: configuration,
            options: options,
            controller: controller
        )
        context.coordinator.mapView = view
        Task { @MainActor in
            do {
                _ = try await view.load()
                try await controller.setThemeMode(themeMode, mapTheme: mapTheme)
            } catch let error as SeatLayerError {
                controller.record(error)
            } catch {
                controller.record(.transport(error.localizedDescription))
            }
        }
        return view
    }

    public func updateUIView(_ uiView: SeatLayerPickerMapView, context: Context) {
        guard context.coordinator.themeMode != themeMode
                || context.coordinator.mapTheme != mapTheme else { return }
        context.coordinator.themeMode = themeMode
        context.coordinator.mapTheme = mapTheme
        Task { @MainActor in
            try? await controller.setThemeMode(themeMode, mapTheme: mapTheme)
        }
    }

    public static func dismantleUIView(_ uiView: SeatLayerPickerMapView, coordinator: Coordinator) {
        Task { @MainActor in await uiView.destroy() }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(themeMode: themeMode, mapTheme: mapTheme)
    }

    public final class Coordinator {
        fileprivate weak var mapView: SeatLayerPickerMapView?
        fileprivate var themeMode: SeatLayerPickerThemeMode?
        fileprivate var mapTheme: SeatLayerPickerMapTheme?

        fileprivate init(
            themeMode: SeatLayerPickerThemeMode?,
            mapTheme: SeatLayerPickerMapTheme?
        ) {
            self.themeMode = themeMode
            self.mapTheme = mapTheme
        }
    }
}

/// Reusable native overview action for custom chrome.
public struct SeatLayerPickerOverviewButton<Label: View>: View {
    @EnvironmentObject private var controller: SeatLayerPickerController
    private let label: () -> Label

    public init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    public var body: some View {
        Button {
            Task { @MainActor in
                do {
                    _ = try await controller.overview()
                } catch let error as SeatLayerError {
                    controller.record(error)
                } catch {
                    controller.record(.transport(error.localizedDescription))
                }
            }
        } label: {
            label()
        }
        .disabled(!controller.isReady)
        .accessibilityLabel("Show the whole venue")
    }
}

public extension SeatLayerPickerOverviewButton where Label == SwiftUI.Label<Text, Image> {
    init() {
        self.init {
            Label("Overview", systemImage: "rectangle.inset.filled.and.person.filled")
        }
    }
}
#endif

import Foundation

/// Platform-neutral contrast policy for native system chrome while the
/// ready-made picker owns the screen.
public enum SeatLayerPickerSystemAppearance {
    /// Immersive renderer surfaces always use the dark native control palette,
    /// so their status-bar foreground must remain light regardless of the
    /// surrounding app's appearance.
    public static func prefersLightForeground(
        themeMode: SeatLayerPickerThemeMode,
        systemIsDark: Bool,
        immersive: Bool
    ) -> Bool {
        if immersive { return true }
        switch themeMode {
        case .auto: return systemIsDark
        case .light: return false
        case .dark: return true
        }
    }
}

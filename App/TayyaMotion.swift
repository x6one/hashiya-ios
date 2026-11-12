import SwiftUI

extension EnvironmentValues {
    /// Motion policy used by app chrome. Release always reads the OS setting.
    /// DEBUG captures may override it without writing the read-only system key.
    var tayyaReduceMotion: Bool {
        #if DEBUG
        if let override = debugReduceMotionOverride { return override }
        #endif
        return accessibilityReduceMotion
    }
}

#if DEBUG
private struct DebugReduceMotionOverrideKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var debugReduceMotionOverride: Bool? {
        get { self[DebugReduceMotionOverrideKey.self] }
        set { self[DebugReduceMotionOverrideKey.self] = newValue }
    }
}
#endif

#if DEBUG
import SwiftUI

/// Deterministic native capture settings. With no flags, every environment
/// value continues to come from the user's device; Release omits this modifier.
struct DebugVisualEnvironment: ViewModifier {
    private let arguments = ProcessInfo.processInfo.arguments

    private var appearance: ColorScheme? {
        if arguments.contains("--test-appearance-light") { return .light }
        if arguments.contains("--test-appearance-dark") { return .dark }
        return nil
    }

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance)
            .transformEnvironment(\.dynamicTypeSize) { size in
                if arguments.contains("--test-accessibility-type") { size = .accessibility1 }
            }
            .transformEnvironment(\.accessibilityReduceMotion) { reduced in
                if arguments.contains("--test-reduce-motion") { reduced = true }
                else if arguments.contains("--test-motion-enabled") { reduced = false }
            }
    }
}
#endif

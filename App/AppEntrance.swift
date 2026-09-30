import SwiftUI

struct AppEntrance: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showing = true
    @State private var drawn = false
    var body: some View {
        ZStack {
            LibraryScreen().accessibilityHidden(showing)
            if showing {
                ZStack {
                    Color(red: 0.975, green: 0.97, blue: 0.95).ignoresSafeArea()
                    VStack(spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28).fill(.white).frame(width: 112, height: 132)
                                .rotationEffect(.degrees(drawn ? -6 : 0)).shadow(color: .black.opacity(0.06), radius: 20, y: 12)
                            Image(systemName: "pencil.and.outline").font(.system(size: 48, weight: .light))
                                .foregroundStyle(Color(red: 0.28, green: 0.44, blue: 0.52))
                                .scaleEffect(drawn ? 1 : 0.75)
                        }
                        Text("حاشية").font(.system(size: 42, weight: .semibold, design: .serif))
                        Text("مساحة هادئة لأفكارك").foregroundStyle(.secondary)
                        Text("By Ahmad Al-awi").font(.footnote).foregroundStyle(.secondary).padding(.top, 36)
                    }.opacity(drawn ? 1 : 0).offset(y: drawn ? 0 : 12)
                }.transition(.opacity).accessibilityIdentifier("openingAnimation")
            }
        }.task {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.8)) { drawn = true }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 1200))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { showing = false }
        }
    }
}

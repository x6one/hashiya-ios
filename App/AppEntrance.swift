import SwiftUI

struct AppEntrance: View {
    @Environment(\.tayyaReduceMotion) private var reduceMotion
    @AppStorage("tayya.openingSeen") private var openingSeen = false
    @State private var showing = true
    @State private var folded = false

    private var showsEntrance: Bool { showing && !openingSeen && !reduceMotion }

    var body: some View {
        ZStack {
            // Keep document URL intake and library state mounted during branding.
            LibraryScreen(allowsInitialWelcome: !showsEntrance)
                .allowsHitTesting(!showsEntrance)
                .accessibilityHidden(showsEntrance)
            if showsEntrance {
                entrance
                    .transition(.opacity)
                    .accessibilityIdentifier("openingAnimation")
            }
        }
        .task(id: reduceMotion) { await runEntrance() }
    }

    private var entrance: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    paperToFold
                    Text("طَيّة")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(TayyaTheme.ink)
                    Text("صفحاتك، بطريقتك.")
                        .font(.title3)
                        .foregroundStyle(TayyaTheme.detail)
                    Text("By Ahmad Al-awi")
                        .font(.footnote)
                        .foregroundStyle(TayyaTheme.detail)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background(TayyaTheme.paper.ignoresSafeArea())
    }

    private var paperToFold: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(TayyaTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(TayyaTheme.separator, lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) { FoldedPageCorner(size: 28) }
                .frame(width: 116, height: 148)
                .rotationEffect(.degrees(folded ? 0 : -6))
                .scaleEffect(folded ? 0.9 : 1)
                .opacity(folded ? 0 : 1)
            TayyaFold()
                .fill(TayyaTheme.ink)
                .overlay(alignment: .topTrailing) {
                    FoldedPageCorner(size: 20)
                        .offset(x: -18, y: 38)
                }
                .frame(width: 164, height: 164)
                .scaleEffect(folded ? 1 : 0.94)
                .opacity(folded ? 1 : 0)
        }
        .frame(width: 180, height: 180)
        .accessibilityHidden(true)
    }

    @MainActor
    private func runEntrance() async {
        guard !openingSeen else { showing = false; return }
        guard !reduceMotion else { finishEntrance(); return }
        do {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeInOut(duration: 0.35)) { folded = true }
            try await Task.sleep(for: .milliseconds(600))
            try Task.checkCancellation()
            withAnimation(.easeOut(duration: 0.2)) { finishEntrance() }
        } catch {
            // Cancellation must never leave an overlay blocking the library.
            finishEntrance()
        }
    }

    @MainActor
    private func finishEntrance() {
        openingSeen = true
        showing = false
    }
}

import SwiftUI

struct AppEntrance: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showing = true
    @State private var drawn = false
    @State private var folded = false
    var body: some View {
        ZStack {
            LibraryScreen().allowsHitTesting(!showing).accessibilityHidden(showing)
            if showing {
                ZStack {
                    TayyaTheme.paper.ignoresSafeArea()
                    VStack(spacing: 20) {
                        ZStack {
                            TayyaFold().trim(from: 0, to: drawn ? 1 : 0)
                                .stroke(TayyaTheme.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            TayyaFold().fill(TayyaTheme.ink).opacity(folded ? 1 : 0)
                            Path { p in
                                p.move(to: CGPoint(x: 117, y: 56))
                                p.addLine(to: CGPoint(x: 161, y: 76))
                                p.addLine(to: CGPoint(x: 153, y: 61))
                                p.closeSubpath()
                            }.fill(TayyaTheme.fold).opacity(folded ? 1 : 0)
                        }.frame(width: 180, height: 180)
                            .rotation3DEffect(.degrees(folded ? 0 : -25), axis: (x: 0, y: 1, z: 0))
                            .accessibilityHidden(true)
                        Text("طَيّة").font(.system(size: 46, weight: .semibold, design: .serif)).foregroundStyle(TayyaTheme.ink)
                        Text("صفحاتك، بطريقتك.").font(.title3).foregroundStyle(.secondary)
                    }.padding(24)
                }.transition(.opacity).accessibilityIdentifier("openingAnimation")
            }
        }.task {
            if reduceMotion { showing = false; return }
            withAnimation(.easeInOut(duration: 0.45)) { drawn = true }
            do {
                try await Task.sleep(for: .milliseconds(450))
                withAnimation(.easeInOut(duration: 0.3)) { folded = true }
                try await Task.sleep(for: .milliseconds(500))
                withAnimation(.easeOut(duration: 0.25)) { showing = false }
            } catch { /* A cancelled scene task must not animate off screen. */ }
        }
    }
}

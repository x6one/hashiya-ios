import SwiftUI

struct WelcomeScreen: View {
    let start: () -> Void
    let demonstrate: () -> Void
    var error: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    brand
                    VStack(alignment: .leading, spacing: 12) {
                        Text("أهلًا بك في طَيّة")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(TayyaTheme.text)
                            .accessibilityAddTraits(.isHeader)
                        Text("اقرأ مستنداتك، واكتب عليها، واجمع أفكارك في صفحات حاشية مستقلة.")
                            .font(.title3)
                            .lineSpacing(4)
                            .foregroundStyle(TayyaTheme.detail)
                    }
                    Label("بدون حساب — ملفاتك على جهازك", systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(TayyaTheme.detail)
                    VStack(alignment: .leading, spacing: 16) {
                        Button(action: demonstrate) {
                            Label("جرّب بملفات جاهزة", systemImage: "play.rectangle.fill")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(TayyaTheme.paper)
                                .background(TayyaTheme.ink, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("welcomeDemonstration")
                        if let error {
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("welcomeError")
                        }
                        Text("تفتح التجربة دليلًا قابلًا للكتابة، ودفترًا، وعرضًا تقديميًا. كل الأدوات متاحة ويمكنك تعديل الملفات أو حذفها.")
                            .font(.callout)
                            .lineSpacing(3)
                            .foregroundStyle(TayyaTheme.detail)
                        Button(action: start) {
                            Label("ابدأ بمكتبتك", systemImage: "books.vertical")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(TayyaTheme.ink)
                                .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(TayyaTheme.separator, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("welcomeLibrary")
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(TayyaTheme.paper)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .interactiveDismissDisabled()
    }

    private var brand: some View {
        TayyaFold()
            .fill(TayyaTheme.ink)
            .frame(width: 72, height: 72)
            .padding(18)
            .background(TayyaTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) { FoldedPageCorner(size: 22) }
            .accessibilityHidden(true)
    }
}

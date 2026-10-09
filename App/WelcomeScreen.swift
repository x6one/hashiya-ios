import SwiftUI

struct WelcomeScreen: View {
    let start: () -> Void
    let demonstrate: () -> Void
    var error: String? = nil
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "book.pages").font(.system(size: 52)).foregroundStyle(TayyaTheme.ink)
                    Text("أهلًا بك في طَيّة").font(.largeTitle.bold())
                    Text("اقرأ مستنداتك، واكتب عليها، واجمع أفكارك في صفحات حاشية مستقلة.").font(.title3)
                    Label("بدون حساب — ملفاتك على جهازك", systemImage: "lock.shield").foregroundStyle(.secondary)
                    Button(action: demonstrate) {
                        Label("جرّب بملفات جاهزة", systemImage: "play.rectangle.fill").frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.borderedProminent).tint(TayyaTheme.ink).accessibilityIdentifier("welcomeDemonstration")
                    if let error { Text(error).font(.callout).foregroundStyle(.red).accessibilityIdentifier("welcomeError") }
                    Text("تفتح التجربة دليلًا قابلًا للكتابة، ودفترًا، وعرضًا تقديميًا. كل الأدوات متاحة ويمكنك تعديل الملفات أو حذفها.").font(.callout).foregroundStyle(.secondary)
                    Button(action: start) {
                        Label("ابدأ بمكتبتك", systemImage: "books.vertical").frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.bordered).accessibilityIdentifier("welcomeLibrary")
                }.padding(28)
            }.background(TayyaTheme.paper)
        }.environment(\.layoutDirection, .rightToLeft).interactiveDismissDisabled()
    }
}

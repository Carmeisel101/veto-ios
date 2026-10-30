import SwiftUI

@main
struct VetoApp: App {
    @State private var engine = ClassifierEngine()

    var body: some Scene {
        WindowGroup {
            TabView {
                ClassifierView()
                    .tabItem { Label("Test", systemImage: "text.badge.checkmark") }
                AboutView()
                    .tabItem { Label("About", systemImage: "info.circle") }
            }
            .environment(engine)
            .task { await engine.loadIfNeeded() }
        }
    }
}

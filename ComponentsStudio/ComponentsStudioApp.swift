import SwiftUI

/// Entry point for the Components Studio sandbox. There is intentionally
/// no app shell or routing — the whole product is the studio itself.
@main
struct ComponentsStudioApp: App {
    init() {
        BundledFontRegistration.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            ComponentStudioView()
                .preferredColorScheme(.light)
        }
    }
}

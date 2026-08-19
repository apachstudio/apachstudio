import CoreText
import Foundation

/// Registers bundled OTF/TTF faces so `UIFont` / `Font.custom` resolve reliably
/// on first frame — UIAppFonts alone can lag behind the first SwiftUI layout pass.
enum BundledFontRegistration {
    private nonisolated(unsafe) static var didRegister = false

    static func registerAll() {
        guard !didRegister else { return }
        didRegister = true

        for name in ["Dripdrop"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "otf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

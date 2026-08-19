import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Studio root
//
// A clean, white-canvas catalog. Pick a component, then record it on the
// stage. Triple-tap the stage to toggle recording mode (hides all chrome).
//
// To add a new component:
//   1. Add a `case` to `StudioItem`.
//   2. Add its `title` and layout entries.
//   3. Register controls + presets in `StudioItemSpecs`.
//   4. Add a `case` to `ComponentStudioStage.body` — wire `specState`
//      into the view. The unified toolbar appears automatically.
//   5. Set `usesUnifiedStage = false` only if the component ships its
//      own embedded toolbar (see Satelite Cards).
//   6. Register the item in `StudioCatalog.categories`.
//   7. Set `StudioItem.lastUpdated` for the new item. Whenever you edit
//      a component, bump its `lastUpdated` — the catalog sorts newest first.

struct ComponentStudioView: View {
    var body: some View {
        NavigationStack {
            StudioCatalogScreen()
        }
    }
}

// MARK: - Catalog screen (Figma node 103:3914)
//
// Flat black-on-white catalog: graffiti "APACH" logo + breadcrumb, a ruled
// table (1px vertical rails + horizontal separators) of bold rows with a
// trailing arrow, and a footer. Content/taxonomy come from `StudioCatalog`.

/// Shared "Swiftui Components Studio" tag — pinned to the same screen position
/// (offset from the safe-area top + trailing inset) on the home and detail
/// pages so it reads as one persistent header element.
private enum StudioBreadcrumb {
    static let text = "Swiftui   Components   Studio"
    static let topInset: CGFloat = 46
    static let trailingInset: CGFloat = 44

    static var view: some View {
        Text(text)
            .font(AppFont.display(10))
            .kerning(-0.4)
            .foregroundStyle(Aurora.ink)
    }
}

private struct StudioCatalogScreen: View {
    /// Side margin to the table rails — logo, footer and rails all align here.
    private let railInset: CGFloat = 44
    /// Horizontal padding of text inside the rails.
    private let rowPadH: CGFloat = 24
    private let headerRowHeight: CGFloat = 56
    private let itemRowHeight: CGFloat = 68
    /// Gap between category blocks (Figma ref).
    private let groupSpacing: CGFloat = 32

    private var categories: [StudioCategory] { StudioCatalog.sortedCategories }

    var body: some View {
        ZStack {
            Aurora.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, railInset)
                    .padding(.top, 12)
                    .padding(.bottom, 36)

                ScrollView {
                    table
                        .padding(.horizontal, railInset)
                }
                .scrollIndicators(.hidden)

                footer
                    .padding(.horizontal, railInset)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
            }
            .overlay(alignment: .topTrailing) {
                StudioBreadcrumb.view
                    .padding(.top, StudioBreadcrumb.topInset)
                    .padding(.trailing, StudioBreadcrumb.trailingInset)
            }
        }
        .navigationDestination(for: StudioItem.self) { item in
            ComponentStudioStage(item: item)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Image("ApachLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 145, height: 59)
            Spacer()
        }
    }

    /// Each category is its own bordered block; blocks are separated by 32px.
    private var table: some View {
        VStack(spacing: groupSpacing) {
            ForEach(categories) { category in
                categoryBlock(category)
            }
        }
        .padding(.bottom, 8)
    }

    private func categoryBlock(_ category: StudioCategory) -> some View {
        VStack(spacing: 0) {
            headerRow(category.title)
            ForEach(category.items, id: \.self) { item in
                rule
                NavigationLink(value: item) {
                    itemRow(item.title)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().strokeBorder(Aurora.rule, lineWidth: 1))
    }

    private var rule: some View {
        Rectangle().fill(Aurora.rule).frame(height: 1)
    }

    private func headerRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.display(12))
                .kerning(-0.2)
                .foregroundStyle(Aurora.ink)
            Spacer()
        }
        .padding(.horizontal, rowPadH)
        .frame(height: headerRowHeight)
    }

    private func itemRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.display(16))
                .kerning(-0.2)
                .foregroundStyle(Aurora.ink)
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Aurora.listArrow)
        }
        .padding(.horizontal, rowPadH)
        .frame(height: itemRowHeight)
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack {
            Text("All   People   Are   Creative   Humans")
            Spacer()
            Text("All rights reserved ®")
        }
        .font(AppFont.display(10))
        .kerning(-0.4)
        .foregroundStyle(Aurora.ink)
    }
}

// MARK: - Stage

/// The neutral white canvas every component renders on. Triple-tap hides
/// the nav bar / title for clean screen recordings.
private struct ComponentStudioStage: View {
    let item: StudioItem

    @State private var recordingMode = false
    @State private var searchText = ""
    @State private var fullScreen = false
    /// Full-screen dismiss affordance — hidden until a double-tap reveals it.
    @State private var showFullScreenClose = false
    @State private var specState: ComponentSpecState

    init(item: StudioItem) {
        self.item = item
        _specState = State(initialValue: ComponentSpecState(defaults: item.specDefaults))
    }

    var body: some View {
        ZStack {
            Aurora.canvas.ignoresSafeArea()
            stageWithToolbar
                .contentShape(Rectangle())
                .onTapGesture(count: 3) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        recordingMode.toggle()
                    }
                    haptic()
                }
                // Breadcrumb pinned to the same position as on the home screen.
                .overlay(alignment: .topTrailing) {
                    if item.usesShaderChrome && !recordingMode {
                        StudioBreadcrumb.view
                            .padding(.top, StudioBreadcrumb.topInset)
                            .padding(.trailing, StudioBreadcrumb.trailingInset)
                    }
                }
        }
        // Full-screen (landscape) toggle — Shaders category only (not Dotted).
        .overlay(alignment: .bottomLeading) {
            if item.usesShaderChrome && item != .dottedBackground && !recordingMode {
                StudioCircleFAB(
                    symbol: "arrow.up.left.and.arrow.down.right",
                    isActive: false,
                    glyphColor: item.prefersDarkStageChrome ? .white : Aurora.iconInk,
                    accessibilityLabel: "Full screen"
                ) {
                    showFullScreenClose = false
                    fullScreen = true
                }
                .padding(.horizontal, StudioLayout.horizontalPadding)
                .padding(.bottom, 28)
            }
        }
        .fullScreenCover(isPresented: $fullScreen) {
            fullScreenStage
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Shader pages draw their own back + breadcrumb in ShaderPageLayout,
        // so the system nav bar is hidden for them.
        .navigationBarBackButtonHidden(item.usesShaderChrome)
        .toolbar((recordingMode || item.usesShaderChrome) ? .hidden : .visible, for: .navigationBar)
    }

    @ViewBuilder
    private var stageWithToolbar: some View {
        if item.usesUnifiedStage, let sheet = item.specSheet {
            UnifiedStudioStage(
                item: item,
                sheet: sheet,
                state: specState,
                showToolbar: !recordingMode
            ) {
                stageContent()
                    .frame(maxWidth: item.maxWidth)
                    .padding(.horizontal, item.horizontalPadding)
            }
        } else {
            stageContent()
                .frame(maxWidth: item.maxWidth)
                .padding(.horizontal, item.horizontalPadding)
        }
    }

    /// Landscape full-screen view of the card content (chrome stripped), so
    /// the animation + its background fill the whole screen. Available on the
    /// Shaders category only. Tap anywhere to dismiss.
    private var fullScreenStage: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                if item.fullScreenFillsDevice {
                    // Native device size — no rotation, so the shader's grid
                    // matches the screen 1:1 and nothing is stretched.
                    stageContent(chrome: false)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    stageContent(chrome: false)
                        .frame(width: geo.size.height, height: geo.size.width)
                        .rotationEffect(.degrees(90))
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }
        // Tapping the Dynamic Island region (top-center) reveals/hides the
        // close button — keeps the rest of the screen free for the
        // component's own gestures.
        .overlay(alignment: .top) {
            Color.clear
                .frame(width: 220, height: 64)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) { showFullScreenClose.toggle() }
                }
                .accessibilityLabel("Toggle close button")
        }
        .overlay(alignment: .topTrailing) {
            if showFullScreenClose {
                Button { fullScreen = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.black.opacity(0.4)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(20)
                .accessibilityLabel("Close full screen")
                .transition(.opacity)
            }
        }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private func stageContent(chrome: Bool = true) -> some View {
        let sheet = item.specSheet
        switch item {
        case .searchPillRest:
            let specs = SearchBoxSpecs(specState, sheet: sheet!)
            SearchBoxView(text: $searchText, initialFocused: false, motionSpecs: specs)
                .frame(maxWidth: .infinity)

        case .blurFocusLoading:
            let specs = SearchModalSpecs(specState, sheet: sheet!)
            SearchModalView(
                query: StudioSampleData.blurFocusQuery,
                onSubmitNewQuery: nil,
                motionSpecs: specs
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

        case .bubbleCard:
            ExpandingBubbleCard(
                place: StudioSampleData.pizzaPlace,
                satellites: StudioSampleData.pizzaIngredients,
                size: Cloud.bubbleH,
                rotation: 8
            )

        case .creditCard3D:
            let specs = CreditCard3DSpecs(specState, sheet: sheet!)
            CreditCard3DView(specs: specs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .verticalCardDeck:
            let specs = PlaceDeckSpecs(specState, sheet: sheet!)
            PlaceDeckView(
                places: StudioSampleData.deckPlaces,
                onTapCard: { _, _ in },
                onTapBackground: {},
                motionSpecs: specs
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .sampleGlassPill:
            let specs = SampleGlassPillSpecs(specState, sheet: sheet!)
            GlassPillView(specs: specs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .talkPill:
            let specs = TalkPillSpecs(specState, sheet: sheet!)
            TalkPillView(specs: specs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .photoRipple:
            let specs = PhotoRippleSpecs(specState, sheet: sheet!)
            PhotoRippleView(specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .photoRipple2:
            let specs = PhotoRipple2Specs(specState, sheet: sheet!)
            PhotoRipple2View(specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .refractiveText:
            let specs = BubbleTextRippleSpecs(specState, sheet: sheet!)
            BubbleTextRippleView(title: item.title, content: .text, specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .bubbleTextRipple:
            let specs = BubbleTextRippleSpecs(specState, sheet: sheet!)
            BubbleTextRippleView(title: item.title, content: .sphere, specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .dottedBackground:
            let specs = DottedBackgroundSpecs(specState, sheet: sheet!)
            DottedBackgroundView(specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .neumorphicDigit:
            let specs = NeumorphicDigitSpecs(specState, sheet: sheet!)
            NeumorphicDigitView(specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .neumorphicPills:
            let specs = NeumorphicPillsSpecs(specState, sheet: sheet!)
            NeumorphicPillsView(specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .flameInGlass:
            let specs = FlameInGlassSpecs(specState, sheet: sheet!)
            FlameInGlassView(chrome: chrome, specs: specs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .flame:
            let specs = FlameSpecs(specState, sheet: sheet!)
            FlameView(chrome: chrome, specs: specs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .sdfLiquid:
            let specs = SDFLiquidSpecs(specState, sheet: sheet!)
            SDFLiquidView(specs: specs, chrome: chrome)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

// MARK: - Catalog categories

struct StudioCategory: Identifiable {
    let id: String
    let title: String
    let items: [StudioItem]
    /// Latest `StudioItem.lastUpdated` in this section — drives section order.
    let lastUpdated: Date
}

private enum StudioCatalog {
    private static let categoryDefinitions: [(id: String, title: String, items: [StudioItem])] = [
        (id: "shaders", title: "Shaders", items: [
            .flame, .flameInGlass, .neumorphicPills, .dottedBackground, .neumorphicDigit, .photoRipple2,
            .photoRipple, .refractiveText, .bubbleTextRipple,
        ]),
        (id: "cards", title: "Cards", items: [.creditCard3D, .bubbleCard]),
        (id: "pills", title: "Pills", items: [.sampleGlassPill, .talkPill]),
        (id: "loading", title: "Loading", items: [.blurFocusLoading]),
        (id: "scroll", title: "Scroll", items: [.verticalCardDeck]),
        (id: "search", title: "Search", items: [.searchPillRest]),
    ]

    static var sortedCategories: [StudioCategory] {
        categoryDefinitions
            .map { def in
                let sortedItems = def.items.sorted { $0.lastUpdated > $1.lastUpdated }
                return StudioCategory(
                    id: def.id,
                    title: def.title,
                    items: sortedItems,
                    lastUpdated: sortedItems.first?.lastUpdated ?? .distantPast
                )
            }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }
}

// MARK: - Item registry

enum StudioItem: Hashable {
    case searchPillRest
    case blurFocusLoading
    case bubbleCard
    case creditCard3D
    case verticalCardDeck
    case sampleGlassPill
    case talkPill
    case photoRipple
    case photoRipple2
    case refractiveText
    case bubbleTextRipple
    case dottedBackground
    case neumorphicDigit
    case neumorphicPills
    case flameInGlass
    case flame
    case sdfLiquid

    /// Bump this timestamp whenever the component (view, specs, or sample data) changes.
    /// The catalog sorts items and sections by this date, newest first.
    var lastUpdated: Date {
        switch self {
        case .sdfLiquid: return studioCatalogDate(2026, 6, 28, 17, 0)
        case .flameInGlass: return studioCatalogDate(2026, 6, 28, 22, 15)
        case .flame: return studioCatalogDate(2026, 7, 7, 14, 40)
        case .refractiveText: return studioCatalogDate(2026, 6, 28, 1, 30)
        case .bubbleTextRipple: return studioCatalogDate(2026, 6, 28, 1, 30)
        case .dottedBackground: return studioCatalogDate(2026, 6, 27, 23, 30)
        case .neumorphicDigit: return studioCatalogDate(2026, 6, 28, 1, 30)
        case .neumorphicPills: return studioCatalogDate(2026, 6, 28, 23, 15)
        case .photoRipple2: return studioCatalogDate(2026, 6, 27, 14, 0)
        case .photoRipple: return studioCatalogDate(2026, 6, 27, 13, 0)
        case .bubbleCard: return studioCatalogDate(2026, 6, 26, 21, 11, 28)
        case .creditCard3D: return studioCatalogDate(2026, 8, 19, 21, 53)
        case .sampleGlassPill: return studioCatalogDate(2026, 6, 28, 12, 35, 0)
        case .talkPill: return studioCatalogDate(2026, 8, 13, 20, 42)
        case .blurFocusLoading: return studioCatalogDate(2026, 6, 26, 21, 4, 5)
        case .verticalCardDeck: return studioCatalogDate(2026, 6, 26, 21, 1, 47)
        case .searchPillRest: return studioCatalogDate(2026, 6, 26, 21, 1, 34)
        }
    }

    /// Full-screen layout: most shaders render landscape (rotated). A few
    /// read their own pixel size to build a grid and would distort when laid
    /// out landscape-then-rotated, so they fill the device at native size.
    var fullScreenFillsDevice: Bool {
        switch self {
        case .dottedBackground: return true
        default: return false
        }
    }

    var title: String {
        switch self {
        case .searchPillRest: return "AI Search"
        case .blurFocusLoading: return "Summary Blur Loading"
        case .bubbleCard: return "Satelite Cards"
        case .creditCard3D: return "AI Credit Card"
        case .verticalCardDeck: return "Vertical card deck"
        case .sampleGlassPill: return "Glass Pill"
        case .talkPill: return "Talk Pill"
        case .photoRipple: return "Liquid Photo"
        case .photoRipple2: return "Photo Ripple"
        case .refractiveText: return "Refractive Text"
        case .bubbleTextRipple: return "Refractive Sphere"
        case .dottedBackground: return "Dotted Background"
        case .neumorphicDigit: return "Neumorphic Icons"
        case .neumorphicPills: return "Neumorphic Pills"
        case .flameInGlass: return "Flame in Glass"
        case .flame: return "Flame"
        case .sdfLiquid: return "Liquid Blobs"
        }
    }

    /// Stable per-item key for persisting user-pinned presets.
    var storageKey: String { String(describing: self) }

    /// Items that render through `ShaderPageLayout`, which draws its own
    /// back button + breadcrumb. For these the system nav bar is hidden.
    var usesShaderChrome: Bool {
        switch self {
        case .dottedBackground, .neumorphicDigit, .neumorphicPills, .flameInGlass, .flame, .sdfLiquid, .photoRipple2,
             .photoRipple, .refractiveText, .bubbleTextRipple:
            return true
        default:
            return false
        }
    }

    var maxWidth: CGFloat? {
        switch self {
        case .bubbleCard, .creditCard3D, .verticalCardDeck, .blurFocusLoading,
             .photoRipple, .photoRipple2, .refractiveText, .bubbleTextRipple, .dottedBackground,
             .neumorphicDigit, .neumorphicPills, .flameInGlass, .flame, .sdfLiquid:
            return .infinity
        default:
            return .infinity
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .bubbleCard, .creditCard3D, .verticalCardDeck, .blurFocusLoading,
             .photoRipple, .photoRipple2, .refractiveText, .bubbleTextRipple, .dottedBackground,
             .neumorphicDigit, .neumorphicPills, .flameInGlass, .flame, .sdfLiquid:
            return 0
        case .searchPillRest:
            return StudioLayout.horizontalPadding
        case .sampleGlassPill, .talkPill:
            return 0
        }
    }
}

// MARK: - Helpers

private func studioCatalogDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    _ second: Int = 0
) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second
    ))!
}

#Preview("Studio") {
    ComponentStudioView()
}

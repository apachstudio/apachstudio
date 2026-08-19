import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Spec model
//
// Declarative control sheet every studio component registers via
// `StudioItem.specSheet`. Values live in `ComponentSpecState` and are
// passed into the component view as typed structs.

struct ComponentSpecControl: Identifiable {
    enum Kind: Equatable {
        case slider(ClosedRange<Double>, format: String)
        case toggle
        /// Color picker — backed by three value keys: `id`+"R"/"G"/"B".
        case color
    }

    let id: String
    let label: String
    let kind: Kind
}

struct ComponentSpecCategory: Identifiable {
    let id: String
    let label: String
    let controls: [ComponentSpecControl]
}

struct ComponentSpecSheet {
    let categories: [ComponentSpecCategory]
    let defaults: [String: Double]

    @MainActor
    func value(_ key: String, in state: ComponentSpecState) -> Double {
        state.values[key] ?? defaults[key] ?? 0
    }
}

// MARK: - Presets

struct StudioComponentPreset: Identifiable, Equatable, Codable {
    let id: String
    let label: String
    let values: [String: Double]

    static let defaultID = "default"

    var isBuiltInDefault: Bool { id == Self.defaultID }

    static func pinned(label: String, values: [String: Double]) -> StudioComponentPreset {
        StudioComponentPreset(
            id: "pinned-\(UUID().uuidString)",
            label: label,
            values: values
        )
    }
}

// MARK: - Persistence

/// Persists user-pinned presets per component to `UserDefaults`, so a pinned
/// "pill" survives app launches until the user deletes it.
enum PinnedPresetStore {
    private static func key(_ storageKey: String) -> String { "pinnedPresets.\(storageKey)" }

    static func load(_ storageKey: String) -> [StudioComponentPreset] {
        guard let data = UserDefaults.standard.data(forKey: key(storageKey)),
              let presets = try? JSONDecoder().decode([StudioComponentPreset].self, from: data)
        else { return [] }
        return presets
    }

    static func save(_ presets: [StudioComponentPreset], for storageKey: String) {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: key(storageKey))
        }
    }
}

// MARK: - Live values

@MainActor
@Observable
final class ComponentSpecState {
    var values: [String: Double]

    init(defaults: [String: Double]) {
        values = defaults
    }

    func applyPreset(_ preset: StudioComponentPreset, sheet: ComponentSpecSheet) {
        var next = sheet.defaults
        for (key, _) in sheet.defaults {
            guard let raw = preset.values[key], raw.isFinite else { continue }
            next[key] = raw
        }
        values = next
    }

    func resetToDefaults(sheet: ComponentSpecSheet) {
        values = sheet.defaults
    }

    func snapshot(from sheet: ComponentSpecSheet) -> [String: Double] {
        var snap: [String: Double] = [:]
        for key in sheet.defaults.keys {
            snap[key] = values[key] ?? sheet.defaults[key] ?? 0
        }
        return snap
    }

    func differsFromDefaults(sheet: ComponentSpecSheet) -> Bool {
        sheet.defaults.contains { key, defaultValue in
            abs((values[key] ?? defaultValue) - defaultValue) > 0.0001
        }
    }

    func makePinnedPreset(label: String, sheet: ComponentSpecSheet) -> StudioComponentPreset {
        .pinned(label: label, values: snapshot(from: sheet))
    }

    func double(_ key: String, default defaultValue: Double) -> Double {
        values[key] ?? defaultValue
    }

    func bool(_ key: String, default defaultValue: Bool) -> Bool {
        (values[key] ?? (defaultValue ? 1 : 0)) >= 0.5
    }

    func binding(_ key: String, default defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { self.values[key] ?? defaultValue },
            set: { self.values[key] = $0 }
        )
    }

    func boolBinding(_ key: String, default defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: { (self.values[key] ?? (defaultValue ? 1 : 0)) >= 0.5 },
            set: { self.values[key] = $0 ? 1 : 0 }
        )
    }
}

// MARK: - Shared studio layout metrics

struct StudioStageHeadline: View {
    let title: String
    var isCompact: Bool = false
    var color: Color = .black

    var body: some View {
        Text(displayTitle)
            .font(AppFont.display(isCompact ? 30 : 40))
            .kerning(-0.8)
            .foregroundStyle(color)
            .background(Color.clear)
            .environment(\.colorScheme, .light)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: 300, alignment: .leading)
    }

    private var displayTitle: String {
        let words = title.split(separator: " ", omittingEmptySubsequences: true)
        guard words.count > 1 else { return title }
        return String(words[0]) + "\n" + words.dropFirst().joined(separator: " ")
    }
}

/// Layout constants shared across studio component stages.
enum StudioLayout {
    /// Gap from the navigation bar's bottom edge (where the "Back" chevron
    /// sits) to the top of a stage component. Because stage content lays out
    /// inside the NavigationStack safe area, its top already aligns to the nav
    /// bar bottom, so a single `.padding(.top, belowNavBar)` puts the component
    /// exactly this far below the back button — no magic numbers.
    static let belowNavBar: CGFloat = 16

    /// Gap from the bottom of the stage H1 title to the top of the card below.
    /// Tuned to land the card at y≈282 with the 40pt title (Figma 103:3914).
    static let titleToCardSpacing: CGFloat = 36

    /// Horizontal inset for stage content — matches the standard iOS nav bar
    /// leading inset so titles and cards align with the back button.
    static let horizontalPadding: CGFloat = 24

    /// Drop shadow opacity for floating action buttons (FABs).
    static let fabShadowOpacity: Double = 0.05
    /// Stroke (rim) opacity for floating action buttons (FABs).
    static let fabStrokeOpacity: Double = 0.05
}

// MARK: - Shared Liquid Glass surfaces

struct SpecToolboxGlass: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
        }
    }
}

struct SpecToolboxPillBg: View {
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().fill(Color.white.opacity(0.70)))
    }
}

// MARK: - Shared FAB (matches Satelite Cards)

struct StudioCircleFAB: View {
    let symbol: String
    let isActive: Bool
    var glyphColor: Color = Aurora.iconInk
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        // 44×44 white Liquid-Glass circle (Figma node 103:3914). Active state
        // (panel/code open) fills solid black with a white glyph.
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isActive ? Color.white : glyphColor)
                .frame(width: 44, height: 44)
                .background {
                    let shape = Circle()
                    if isActive {
                        shape.fill(Color.black.opacity(0.85))
                    } else {
                        // `.clear` (not `.regular`) — more transparent liquid
                        // glass with no defined rim/border.
                        shape.fill(.clear).glassEffect(.clear.interactive(), in: shape)
                    }
                }
                .overlay {
                    Circle().strokeBorder(Aurora.ink.opacity(StudioLayout.fabStrokeOpacity), lineWidth: 1)
                }
                .contentShape(Circle())
                .shadow(color: .black.opacity(StudioLayout.fabShadowOpacity), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preset chip row (matches Satelite Cards MotionControlBar)

struct StudioPresetChipRow: View {
    let defaultPreset: StudioComponentPreset
    let builtInPresets: [StudioComponentPreset]
    let pinnedPresets: [StudioComponentPreset]
    @Binding var selectedID: String
    @Binding var isExpanded: Bool
    @Binding var showCode: Bool
    let defaultIsModified: Bool
    let onSelect: (StudioComponentPreset) -> Void
    let onAddPin: () -> Void
    let onResetDefault: () -> Void
    let onDelete: (StudioComponentPreset) -> Void

    @Namespace private var pillSpace

    private let presetSwitchAnim: Animation =
        .spring(response: 0.42, dampingFraction: 0.82)
    private let expandAnim: Animation =
        .spring(response: 0.45, dampingFraction: 0.85)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(builtInPresets) { preset in
                    chip(
                        for: preset,
                        isDefault: preset.id == defaultPreset.id
                    )
                }
                ForEach(pinnedPresets) { preset in
                    chip(for: preset, isDefault: false)
                }
                addPinChip
            }
        }
    }

    private var addPinChip: some View {
        Image(systemName: "plus")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Aurora.ink.opacity(0.55))
            .frame(minWidth: 36)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background { SpecToolboxPillBg().opacity(0.35) }
            .contentShape(Capsule())
            .onTapGesture {
                withAnimation(presetSwitchAnim) { onAddPin() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Save current configuration")
            .accessibilityHint("Pins the current slider values as a new preset")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func chip(for preset: StudioComponentPreset, isDefault: Bool) -> some View {
        let isSelected = selectedID == preset.id

        HStack(spacing: 4) {
            Text(preset.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Aurora.ink : Aurora.ink.opacity(0.62))
                .lineLimit(1)
                .truncationMode(.tail)

            if isDefault, defaultIsModified, isSelected {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Aurora.ink.opacity(0.45))
            }

            // Pinned presets show a delete affordance when selected.
            if !isDefault, isSelected {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Aurora.ink.opacity(0.55))
                    .padding(.leading, 1)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(presetSwitchAnim) { onDelete(preset) }
                    }
                    .accessibilityLabel("Delete preset \(preset.label)")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                SpecToolboxPillBg()
                    .matchedGeometryEffect(id: "pill", in: pillSpace)
            } else {
                SpecToolboxPillBg().opacity(0.5)
            }
        }
        .contentShape(Capsule())
        .onTapGesture(count: 2) {
            withAnimation(expandAnim) { isExpanded.toggle() }
        }
        .onTapGesture(count: 1) {
            withAnimation(presetSwitchAnim) {
                selectedID = preset.id
                showCode = false
            }
            onSelect(preset)
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            guard isDefault, defaultIsModified else { return }
            withAnimation(presetSwitchAnim) { onResetDefault() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(preset.label)
        .accessibilityHint(isDefault && defaultIsModified
            ? "Single tap selects, double tap opens controls, long press resets to original"
            : "Single tap selects, double tap opens controls")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Unified control bar (preset chips + customize panel + code view)

struct StudioPresetControlBar: View {
    let defaultPreset: StudioComponentPreset
    let builtInPresets: [StudioComponentPreset]
    let pinnedPresets: [StudioComponentPreset]
    let sheet: ComponentSpecSheet
    @Bindable var state: ComponentSpecState
    @Binding var selectedPresetID: String
    @Binding var isExpanded: Bool
    @Binding var showCode: Bool
    let onCollapse: () -> Void
    let onAddPin: () -> Void
    let onResetDefault: () -> Void
    let onDeletePin: (StudioComponentPreset) -> Void
    let codeGenerator: () -> String

    @State private var categoryID: String = ""
    @State private var didCopy: Bool = false
    @Namespace private var categorySpace

    private let expandAnim: Animation = .spring(response: 0.45, dampingFraction: 0.85)
    private let presetSwitchAnim: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    private let surfaceCornerRadius: CGFloat = 32
    private let innerCornerRadius: CGFloat = 18
    private let inkSoft: Color = Color.black.opacity(0.08)

    private var categories: [ComponentSpecCategory] { sheet.categories }

    private var activeCategory: ComponentSpecCategory {
        categories.first { $0.id == categoryID } ?? categories[0]
    }

    var body: some View {
        VStack(spacing: 12) {
            StudioPresetChipRow(
                defaultPreset: defaultPreset,
                builtInPresets: builtInPresets,
                pinnedPresets: pinnedPresets,
                selectedID: $selectedPresetID,
                isExpanded: $isExpanded,
                showCode: $showCode,
                defaultIsModified: state.differsFromDefaults(sheet: sheet),
                onSelect: { preset in
                    state.applyPreset(preset, sheet: sheet)
                },
                onAddPin: onAddPin,
                onResetDefault: onResetDefault,
                onDelete: onDeletePin
            )

            expandedPanel
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            SpecToolboxGlass(cornerRadius: surfaceCornerRadius)
        }
        .clipShape(RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Component controls")
        .onAppear {
            if categoryID.isEmpty, let first = categories.first {
                categoryID = first.id
            }
        }
    }

    private var expandedPanel: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 12) {
                if showCode {
                    codeContent
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    copyAffordance
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    if categories.count > 1 {
                        categorySwitcher
                    }
                    VStack(spacing: 10) {
                        ForEach(activeCategory.controls) { control in
                            controlView(control)
                        }
                    }
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxHeight: 150)
    }

    private var categorySwitcher: some View {
        HStack(spacing: 4) {
            ForEach(categories) { category in
                categoryChip(category)
            }
        }
        .padding(3)
        .background(Capsule().fill(inkSoft))
    }

    @ViewBuilder
    private func categoryChip(_ category: ComponentSpecCategory) -> some View {
        let isOn = category.id == categoryID
        Button {
            withAnimation(presetSwitchAnim) {
                categoryID = category.id
                showCode = false
            }
        } label: {
            Text(category.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Aurora.ink : Aurora.ink.opacity(0.55))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background {
                    if isOn {
                        SpecToolboxPillBg()
                            .matchedGeometryEffect(id: "category-pill", in: categorySpace)
                    } else {
                        SpecToolboxPillBg().opacity(0.5)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func controlView(_ control: ComponentSpecControl) -> some View {
        switch control.kind {
        case .toggle:
            HStack(spacing: 8) {
                paramLabel(control.label)
                Toggle("", isOn: state.boolBinding(
                    control.id,
                    default: (sheet.defaults[control.id] ?? 0) >= 0.5
                ))
                .labelsHidden()
                .tint(Color.black.opacity(0.20))
                Spacer()
                Text(state.bool(control.id, default: (sheet.defaults[control.id] ?? 0) >= 0.5) ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Aurora.ink.opacity(0.7))
                    .frame(width: 50, alignment: .trailing)
            }

        case .slider(let range, let format):
            HStack(spacing: 8) {
                paramLabel(control.label)
                Slider(
                    value: state.binding(
                        control.id,
                        default: sheet.defaults[control.id] ?? range.lowerBound
                    ),
                    in: range
                )
                .tint(Color.black.opacity(0.20))
                Text(String(
                    format: format,
                    state.double(control.id, default: sheet.defaults[control.id] ?? range.lowerBound)
                ))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(Aurora.ink.opacity(0.70))
                .frame(width: 50, alignment: .trailing)
            }

        case .color:
            HStack(spacing: 8) {
                paramLabel(control.label)
                Spacer(minLength: 0)
                ColorPicker("", selection: colorBinding(control.id), supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    /// Binds a `.color` control's `id`+"R"/"G"/"B" value keys to a `Color`.
    private func colorBinding(_ prefix: String) -> Binding<Color> {
        Binding(
            get: {
                Color(
                    red: state.double("\(prefix)R", default: 1),
                    green: state.double("\(prefix)G", default: 1),
                    blue: state.double("\(prefix)B", default: 1)
                )
            },
            set: { newColor in
                #if canImport(UIKit)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(newColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                state.values["\(prefix)R"] = Double(r)
                state.values["\(prefix)G"] = Double(g)
                state.values["\(prefix)B"] = Double(b)
                #endif
            }
        )
    }

    @ViewBuilder
    private func paramLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Aurora.ink.opacity(0.55))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: 70, alignment: .leading)
    }

    private var copyAffordance: some View {
        Button {
            performCopy()
        } label: {
            Text(didCopy ? "Copied" : "Copy SwiftUI code")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Aurora.ink)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .background { SpecToolboxPillBg() }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy SwiftUI code")
    }

    private var codeContent: some View {
        Text(codeGenerator())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Aurora.ink.opacity(0.88))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .textSelection(.enabled)
            .background {
                RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
    }

    private func performCopy() {
        #if canImport(UIKit)
        UIPasteboard.general.string = codeGenerator()
        #endif
        withAnimation(presetSwitchAnim) { didCopy = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(presetSwitchAnim) { didCopy = false }
        }
    }
}

// MARK: - Unified stage (draggable canvas + toolbar + FABs)

struct UnifiedStudioStage<Content: View>: View {
    let item: StudioItem
    let sheet: ComponentSpecSheet
    @Bindable var state: ComponentSpecState
    let showToolbar: Bool
    @ViewBuilder var content: () -> Content

    @State private var selectedPresetID: String
    @State private var pinnedPresets: [StudioComponentPreset]
    @State private var controlBarExpanded = false
    @State private var showCode = false
    @State private var expandedStateBeforeCode = false

    private var defaultPreset: StudioComponentPreset {
        item.presets.first ?? StudioComponentPreset(
            id: StudioComponentPreset.defaultID,
            label: "Default",
            values: [:]
        )
    }

    private var builtInPresets: [StudioComponentPreset] {
        item.presets.isEmpty ? [defaultPreset] : item.presets
    }

    private var allPresets: [StudioComponentPreset] {
        builtInPresets + pinnedPresets
    }

    private let toolboxMorphAnim: Animation =
        .spring(response: 0.55, dampingFraction: 0.78)

    private var isEditingControls: Bool {
        showToolbar && (controlBarExpanded || showCode)
    }

    private var usesNativeStageScrolling: Bool {
        item == .verticalCardDeck
    }

    private var usesCenteredStageContent: Bool {
        item == .searchPillRest || item == .sampleGlassPill || item == .talkPill
    }

    private var showsStageHeadline: Bool {
        showToolbar && !item.usesShaderChrome && !usesNativeStageScrolling && !usesCenteredStageContent
    }

    init(
        item: StudioItem,
        sheet: ComponentSpecSheet,
        state: ComponentSpecState,
        showToolbar: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.item = item
        self.sheet = sheet
        self.state = state
        self.showToolbar = showToolbar
        self.content = content
        _selectedPresetID = State(initialValue: StudioComponentPreset.defaultID)
        // Restore user-pinned presets persisted from previous sessions.
        _pinnedPresets = State(initialValue: PinnedPresetStore.load(item.storageKey))
    }

    var body: some View {
        stageScrollContent
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture { dismissToolbarIfNeeded() }
            .overlay(alignment: .bottom) {
                if showToolbar {
                    toolbarDock
                }
            }
    }

    private var toolbarDock: some View {
        VStack(spacing: 16) {
            if controlBarExpanded || showCode {
                StudioPresetControlBar(
                    defaultPreset: defaultPreset,
                    builtInPresets: builtInPresets,
                    pinnedPresets: pinnedPresets,
                    sheet: sheet,
                    state: state,
                    selectedPresetID: $selectedPresetID,
                    isExpanded: $controlBarExpanded,
                    showCode: $showCode,
                    onCollapse: collapseControlBar,
                    onAddPin: pinCurrentConfiguration,
                    onResetDefault: resetDefaultPreset,
                    onDeletePin: deletePinnedPreset
                ) {
                    item.swiftCodeSnippet(
                        state: state,
                        presetLabel: allPresets.first { $0.id == selectedPresetID }?.label ?? "Custom"
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                if item == .dottedBackground && !(controlBarExpanded || showCode) {
                    quickPresetPills
                } else {
                    Spacer()
                }

                customizeFAB
                toolsFAB
            }
        }
        .padding(.horizontal, StudioLayout.horizontalPadding)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
    }

    /// Scrolls stage content when the specs panel is open so the card stays
    /// visible above the floating toolbar.
    @ViewBuilder
    private var stageScrollContent: some View {
        if usesNativeStageScrolling {
            content()
        } else if usesCenteredStageContent {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                stagePageContent
                    .padding(.bottom, specsPanelBottomInset)
            }
        }
    }

    private var stagePageContent: some View {
        VStack(alignment: .leading, spacing: isEditingControls ? 14 : StudioLayout.titleToCardSpacing) {
            if showsStageHeadline {
                StudioStageHeadline(title: item.title, isCompact: isEditingControls)
                    .padding(.horizontal, StudioLayout.horizontalPadding)
                    .padding(.top, isEditingControls ? 4 : StudioLayout.belowNavBar)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var specsPanelBottomInset: CGFloat {
        if showCode { return 620 }
        if controlBarExpanded { return 520 }
        return 80
    }

    /// Always-visible horizontal pill row (built-in + pinned presets) to
    /// the left of the FABs. Tapping a pill applies that preset instantly
    /// without opening the customize panel.
    private var quickPresetPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allPresets) { preset in
                    let isSelected = selectedPresetID == preset.id
                    Text(preset.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Aurora.ink : Aurora.ink.opacity(0.62))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background {
                            if isSelected {
                                SpecToolboxPillBg()
                            } else {
                                SpecToolboxPillBg().opacity(0.5)
                            }
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            withAnimation(toolboxMorphAnim) {
                                selectedPresetID = preset.id
                                state.applyPreset(preset, sheet: sheet)
                            }
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Preset \(preset.label)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fabGlyphColor: Color {
        item.prefersDarkStageChrome ? Color.white.opacity(0.92) : Aurora.iconInk
    }

    private var toolsFAB: some View {
        StudioCircleFAB(
            symbol: "wrench.and.screwdriver.fill",
            isActive: showCode,
            glyphColor: fabGlyphColor,
            accessibilityLabel: showCode ? "Close generated code" : "Open generated code"
        ) {
            if showCode {
                dismissCodeView()
            } else {
                withAnimation(toolboxMorphAnim) {
                    expandedStateBeforeCode = controlBarExpanded
                    controlBarExpanded = true
                    showCode = true
                }
            }
        }
    }

    private var customizeFAB: some View {
        let isActive = controlBarExpanded && !showCode
        return StudioCircleFAB(
            symbol: "slider.horizontal.3",
            isActive: isActive,
            glyphColor: fabGlyphColor,
            accessibilityLabel: isActive ? "Close customize panel" : "Open customize panel"
        ) {
            withAnimation(toolboxMorphAnim) {
                if showCode {
                    showCode = false
                    controlBarExpanded = expandedStateBeforeCode
                } else {
                    controlBarExpanded.toggle()
                }
            }
        }
    }

    private func dismissCodeView() {
        withAnimation(toolboxMorphAnim) {
            showCode = false
            controlBarExpanded = expandedStateBeforeCode
        }
    }

    private func collapseControlBar() {
        withAnimation(toolboxMorphAnim) {
            showCode = false
            controlBarExpanded = false
        }
    }

    private func dismissToolbarIfNeeded() {
        guard controlBarExpanded || showCode else { return }
        collapseControlBar()
    }

    private func pinCurrentConfiguration() {
        let label = "Pinned \(pinnedPresets.count + 1)"
        let preset = state.makePinnedPreset(label: label, sheet: sheet)
        pinnedPresets.append(preset)
        selectedPresetID = preset.id
        // Persist so the new pill survives app launches.
        PinnedPresetStore.save(pinnedPresets, for: item.storageKey)
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func deletePinnedPreset(_ preset: StudioComponentPreset) {
        pinnedPresets.removeAll { $0.id == preset.id }
        // Persist the deletion permanently.
        PinnedPresetStore.save(pinnedPresets, for: item.storageKey)
        if selectedPresetID == preset.id {
            selectedPresetID = defaultPreset.id
            state.applyPreset(defaultPreset, sheet: sheet)
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
    }

    private func resetDefaultPreset() {
        state.resetToDefaults(sheet: sheet)
        selectedPresetID = defaultPreset.id
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

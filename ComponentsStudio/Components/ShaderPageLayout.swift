import SwiftUI

/// Shared chrome for shader component stages: bold H1 title (left-aligned with
/// the card) and a rounded card below using `Theme.Radius.card`.
struct ShaderPageLayout<Content: View, Accessory: View>: View {
    let title: String
    var aspectRatio: CGFloat? = nil
    let accessory: Accessory
    @ViewBuilder var card: () -> Content

    @Environment(\.dismiss) private var dismiss

    private let cardShape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)

    init(
        title: String,
        aspectRatio: CGFloat? = nil,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder card: @escaping () -> Content
    ) {
        self.title = title
        self.aspectRatio = aspectRatio
        self.accessory = accessory()
        self.card = card
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navRow
                .padding(.bottom, 24)
            VStack(alignment: .leading, spacing: StudioLayout.titleToCardSpacing) {
                titleView
                accessory
                Group {
                    if let aspectRatio {
                        card()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                    } else {
                        card()
                    }
                }
                .clipShape(cardShape)
            }
        }
        .padding(.horizontal, StudioLayout.horizontalPadding)
        .padding(.top, StudioLayout.belowNavBar)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Custom nav row: Liquid-Glass circular back button (Figma node 103:3914).
    /// The breadcrumb tag is positioned by the stage so it matches the home.
    private var navRow: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Aurora.iconInk)
                    .frame(width: 44, height: 44)
                    .background {
                        let shape = Circle()
                        shape.fill(.clear).glassEffect(.regular.interactive(), in: shape)
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()
        }
    }

    private var titleLines: [String] {
        let words = title.split(separator: " ").map(String.init)
        guard words.count > 1 else { return [title] }
        let mid = (words.count + 1) / 2
        return [
            words[..<mid].joined(separator: " "),
            words[mid...].joined(separator: " ")
        ]
    }

    private var titleView: some View {
        // SF Pro Display Bold, 40pt, split across two lines like the design
        // ("Dotted" / "Background") — Figma node 103:3914.
        VStack(alignment: .leading, spacing: -4) {
            ForEach(titleLines, id: \.self) { line in
                Text(line)
                    .font(AppFont.display(40))
                    .kerning(-0.4)
                    .foregroundStyle(Aurora.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension ShaderPageLayout where Accessory == EmptyView {
    init(
        title: String,
        aspectRatio: CGFloat? = nil,
        @ViewBuilder card: @escaping () -> Content
    ) {
        self.init(title: title, aspectRatio: aspectRatio, accessory: { EmptyView() }, card: card)
    }
}

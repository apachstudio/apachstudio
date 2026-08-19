import SwiftUI

/// Shared chrome for shader component stages: bold H1 title (left-aligned with
/// the card) and a rounded card below using `Theme.Radius.card`.
struct ShaderPageLayout<Content: View, Accessory: View>: View {
    let title: String
    var aspectRatio: CGFloat? = nil
    var titleColor: Color = .black
    var chromeColor: Color = Aurora.iconInk
    let accessory: Accessory
    @ViewBuilder var card: () -> Content

    @Environment(\.dismiss) private var dismiss

    private let cardShape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)

    init(
        title: String,
        aspectRatio: CGFloat? = nil,
        titleColor: Color = .black,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder card: @escaping () -> Content
    ) {
        self.title = title
        self.aspectRatio = aspectRatio
        self.titleColor = titleColor
        self.accessory = accessory()
        self.card = card
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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

    private var titleView: some View {
        StudioStageHeadline(title: title, color: titleColor)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension ShaderPageLayout where Accessory == EmptyView {
    init(
        title: String,
        aspectRatio: CGFloat? = nil,
        titleColor: Color = .black,
        @ViewBuilder card: @escaping () -> Content
    ) {
        self.init(title: title, aspectRatio: aspectRatio, titleColor: titleColor, accessory: { EmptyView() }, card: card)
    }
}

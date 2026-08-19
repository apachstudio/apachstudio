import SwiftUI

/// Touch-driven dot grid with glow, attraction, and repulsion modes.
struct DottedBackgroundView: View {
    var title: String = StudioItem.dottedBackground.title
    var specs: DottedBackgroundSpecs = DottedBackgroundSpecs(
        ComponentSpecState(defaults: StudioItem.dottedBackground.specDefaults),
        sheet: StudioItem.dottedBackground.specSheet!
    )
    /// When false, renders only the card content (no page chrome) so an
    /// Xcode preview can show the component full-bleed.
    var chrome: Bool = true

    @State private var touchPosition: CGPoint = .zero
    @State private var intensity: CGFloat = 0

    var body: some View {
        if chrome {
            ShaderPageLayout(title: title, aspectRatio: 0.72) { cardBody }
        } else {
            cardBody
        }
    }

    @ViewBuilder
    private var cardBody: some View {
            GeometryReader { geo in
                let size = geo.size

                Color.black
                    .colorEffect(
                        ShaderLibrary.dottedBackground(
                            .float2(Float(size.width), Float(size.height)),
                            .float2(Float(touchPosition.x), Float(touchPosition.y)),
                            .float(Float(specs.mode)),
                            .float(Float(intensity)),
                            .float(Float(specs.gridDensity)),
                            .float(Float(specs.influenceRadius)),
                            .float(Float(specs.maxDisplacement)),
                            .float4(Float(specs.bgR), Float(specs.bgG), Float(specs.bgB), 0),
                            .float4(Float(specs.bg2R), Float(specs.bg2G), Float(specs.bg2B), 0),
                            .float4(Float(specs.dotR), Float(specs.dotG), Float(specs.dotB), 0),
                            .float4(Float(specs.accentR), Float(specs.accentG), Float(specs.accentB), 0),
                            .float4(Float(specs.glowR), Float(specs.glowG), Float(specs.glowB), 0),
                            .float4(Float(specs.spotR), Float(specs.spotG), Float(specs.spotB), 0),
                            .float4(
                                Float(specs.glowAmount),
                                Float(specs.accentMix),
                                Float(specs.dotSizeMin),
                                Float(specs.dotSizeMax)
                            ),
                            .float4(
                                Float(specs.fisheyeAmount),
                                Float(specs.dotShape),
                                0,
                                0
                            )
                        )
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                touchPosition = value.location
                                withAnimation(.easeOut(duration: 0.15)) {
                                    intensity = 1
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.5)) {
                                    intensity = 0
                                }
                            }
                    )
                    .onAppear {
                        touchPosition = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    }
            }
    }
}

#Preview {
    ZStack {
        Aurora.canvas.ignoresSafeArea()
        DottedBackgroundView()
    }
}

// Card-only: just the component, full-bleed, on its own background.
#Preview("Dotted Background · card", traits: .sizeThatFitsLayout) {
    DottedBackgroundView(chrome: false)
        .frame(width: 430, height: 430)
}

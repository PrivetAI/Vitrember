import SwiftUI

/// The splash. Shown while the launch check runs, and held over the web panel until the
/// page commits its first frame so the user never stares at a black rectangle.
struct VitremberLoadingScreen: View {
    @State private var breathing = false

    var body: some View {
        ZStack {
            VitremberPalette.night
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 22) {
                ZStack {
                    Ellipse()
                        .fill(RadialGradient(colors: [VitremberPalette.ember.opacity(breathing ? 0.44 : 0.16),
                                                      VitremberPalette.molten.opacity(breathing ? 0.18 : 0.06),
                                                      Color.clear],
                                             center: .center, startRadius: 0, endRadius: 82))
                        .frame(width: 168, height: 132)

                    FurnaceGlyph()
                        .fill(VitremberPalette.brick, style: FillStyle(eoFill: true))
                        .frame(width: 108, height: 104)

                    FurnaceGlyph()
                        .stroke(VitremberPalette.brickEdge, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                        .frame(width: 108, height: 104)

                    GatherGlyph()
                        .fill(LinearGradient(colors: [VitremberPalette.ember, VitremberPalette.molten],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 62, height: 60)
                        .offset(y: 2)
                        .opacity(breathing ? 1.0 : 0.62)
                }
                .frame(width: 168, height: 132)
                .animation(Animation.easeInOut(duration: 1.15).repeatForever(autoreverses: true),
                           value: breathing)

                VStack(spacing: 5) {
                    Text("VITREMBER")
                        .font(VitremberType.label(17))
                        .kerning(3.2)
                        .foregroundColor(VitremberPalette.ivory)
                    Text("Bringing the furnace up to heat")
                        .font(VitremberType.body(12))
                        .foregroundColor(VitremberPalette.muted)
                }
            }
        }
        .onAppear { breathing = true }
    }
}

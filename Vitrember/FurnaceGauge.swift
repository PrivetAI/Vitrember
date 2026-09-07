import SwiftUI

/// One working window drawn onto the heat scale.
struct GaugeBand: Identifiable {
    let id: Int
    let band: VitremberBand
    let tint: Color
    let label: String
}

/// The linear pyrometer across the top of the workshop.
///
/// Geometry is driven entirely by the `width` and `height` the PARENT passes in — the
/// view never asks a drawing closure how big it is, so it cannot end up scaled against
/// the wrong box.
struct HeatScale: View {
    let temperature: Double
    let bands: [GaugeBand]
    let width: CGFloat
    let height: CGFloat

    private var floorT: Double { VesselCatalog.gaugeFloor }
    private var ceilT: Double { VesselCatalog.gaugeCeiling }

    private func x(_ value: Double) -> CGFloat {
        let clamped = min(max(value, floorT), ceilT)
        return CGFloat((clamped - floorT) / (ceilT - floorT)) * width
    }

    /// Height reserved for the needle head above the track, and for the scale labels below.
    private let headHeight: CGFloat = 8
    private let footHeight: CGFloat = 13

    private var trackHeight: CGFloat {
        max(height - headHeight - footHeight, 12)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Needle head, in its own strip so nothing ever draws outside the frame.
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(width: width, height: headHeight)
                Triangle()
                    .fill(VitremberPalette.ivory)
                    .frame(width: 10, height: 7)
                    .offset(x: min(max(x(temperature) - 5, 0), max(width - 10, 0)), y: 1)
            }
            .frame(width: width, height: headHeight, alignment: .topLeading)

            // The track itself.
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(LinearGradient(colors: [VitremberPalette.chill.opacity(0.32),
                                                  VitremberPalette.molten.opacity(0.26),
                                                  VitremberPalette.scorch.opacity(0.40)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: width, height: trackHeight)

                // Working windows, one per loaded bench.
                ForEach(bands) { entry in
                    let lo = x(entry.band.low)
                    let hi = x(entry.band.high)
                    let coreLo = x(entry.band.coreLow)
                    let coreHi = x(entry.band.coreHigh)
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(entry.tint.opacity(0.24))
                            .frame(width: max(hi - lo, 2), height: trackHeight)
                            .offset(x: lo)
                        Rectangle()
                            .fill(entry.tint.opacity(0.58))
                            .frame(width: max(coreHi - coreLo, 2), height: trackHeight)
                            .offset(x: coreLo)
                        Rectangle()
                            .fill(entry.tint.opacity(0.90))
                            .frame(width: 1.5, height: trackHeight)
                            .offset(x: lo)
                        Rectangle()
                            .fill(entry.tint.opacity(0.90))
                            .frame(width: 1.5, height: trackHeight)
                            .offset(x: max(hi - 1.5, 0))
                    }
                }

                // The needle line.
                Rectangle()
                    .fill(VitremberPalette.ivory)
                    .frame(width: 2, height: trackHeight)
                    .offset(x: min(max(x(temperature) - 1, 0), max(width - 2, 0)))
            }
            .frame(width: width, height: trackHeight, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .stroke(VitremberPalette.seam.opacity(0.85), lineWidth: 1)
            )

            // Scale labels.
            HStack(spacing: 0) {
                Text(VitremberFormat.degrees(floorT))
                Spacer(minLength: 0)
                Text(VitremberFormat.degrees((floorT + ceilT) / 2))
                Spacer(minLength: 0)
                Text(VitremberFormat.degrees(ceilT))
            }
            .font(VitremberType.readout(9, .regular))
            .foregroundColor(VitremberPalette.faint)
            .frame(width: width, height: footHeight, alignment: .bottom)
        }
        .frame(width: width, height: height, alignment: .top)
    }
}

/// A plain triangle, used as the needle head and elsewhere.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The furnace itself. `glow` runs 0 (cold) to 1 (at the top of the scale) and is passed
/// in as a plain `Double`, so the arch really does brighten as the needle moves.
struct FurnaceHearth: View {
    let glow: Double
    let width: CGFloat
    let height: CGFloat
    let pumping: Bool

    private var level: Double { min(max(glow, 0), 1) }

    var body: some View {
        ZStack {
            // Heat spilling out of the mouth.
            Ellipse()
                .fill(RadialGradient(colors: [VitremberPalette.ember.opacity(0.50 * level + 0.05),
                                              VitremberPalette.molten.opacity(0.22 * level),
                                              Color.clear],
                                     center: .center,
                                     startRadius: 0,
                                     endRadius: max(width * 0.46, 1)))
                .frame(width: width * 1.02, height: height * 1.02)

            FurnaceGlyph()
                .fill(VitremberPalette.brick, style: FillStyle(eoFill: true))
                .frame(width: width * 0.86, height: height * 0.92)

            FurnaceGlyph()
                .stroke(VitremberPalette.brickEdge, style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                .frame(width: width * 0.86, height: height * 0.92)

            // The gather glowing in the mouth.
            GatherGlyph()
                .fill(LinearGradient(colors: [VitremberPalette.ember.opacity(0.35 + 0.65 * level),
                                              VitremberPalette.molten.opacity(0.30 + 0.60 * level)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: width * 0.50, height: height * 0.56)
                .offset(y: height * 0.02)

            // A pale flare while the treadle is down, so the control has a visible effect.
            if pumping {
                Ellipse()
                    .fill(VitremberPalette.ember.opacity(0.22))
                    .frame(width: width * 0.62, height: height * 0.50)
                    .offset(y: height * 0.02)
            }
        }
        .frame(width: width, height: height)
    }
}

/// The treadle. A `Button` whose label is only artwork has no tap area at all, so the
/// label carries an explicit `contentShape` — and the control is deliberately built from
/// a press gesture rather than a `Button`, because it must respond to press AND release.
///
/// This view is always placed OUTSIDE any `ScrollView`: a scroll view delays touches by
/// about 150 ms and cancels them on the slightest drift, which would wreck a held control.
struct TreadleControl: View {
    let pumping: Bool
    let width: CGFloat
    let height: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(height / 2, 34), style: .continuous)
                .fill(pumping
                      ? LinearGradient(colors: [VitremberPalette.ember, VitremberPalette.molten],
                                       startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [VitremberPalette.molten, VitremberPalette.molten.opacity(0.78)],
                                       startPoint: .top, endPoint: .bottom))

            RoundedRectangle(cornerRadius: min(height / 2, 34), style: .continuous)
                .stroke(VitremberPalette.ember.opacity(pumping ? 0.95 : 0.45), lineWidth: 1.5)

            HStack(spacing: 10) {
                BellowsGlyph()
                    .fill(VitremberPalette.night.opacity(0.82))
                    .frame(width: height * 0.52, height: height * 0.42)
                Text(pumping ? "PUMPING" : "HOLD THE BELLOWS")
                    .font(VitremberType.label(min(height * 0.26, 15)))
                    .kerning(1.4)
                    .foregroundColor(VitremberPalette.night.opacity(0.88))
            }
        }
        .frame(width: width, height: height)
        // The tap target is the whole plate, declared on the content itself.
        .contentShape(RoundedRectangle(cornerRadius: min(height / 2, 34), style: .continuous))
        .scaleEffect(pumping ? 0.975 : 1.0)
        .animation(.easeOut(duration: 0.10), value: pumping)
        .gesture(
            // Zero-distance drag: fires the instant the finger lands and again when it
            // lifts, which a Button cannot do.
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pumping { onPress() } }
                .onEnded { _ in onRelease() }
        )
        .accessibilityLabel(Text("Bellows treadle"))
        .accessibilityHint(Text("Press and hold to raise the furnace temperature"))
    }
}

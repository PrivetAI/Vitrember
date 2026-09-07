import SwiftUI

/// A point on a vessel's turned profile: `y` down the piece, `half` the half-width there.
/// Both are fractions of the drawing box, so a profile scales to any size.
struct ProfilePoint {
    let y: CGFloat
    let half: CGFloat
    init(_ y: CGFloat, _ half: CGFloat) { self.y = y; self.half = half }
}

enum VesselProfiles {

    static func profile(_ vesselID: Int) -> [ProfilePoint] {
        switch vesselID {
        case 0: // Glass Bead — a wound sphere on the mandrel
            return [ProfilePoint(0.28, 0.04), ProfilePoint(0.34, 0.06), ProfilePoint(0.38, 0.19),
                    ProfilePoint(0.44, 0.25), ProfilePoint(0.52, 0.26), ProfilePoint(0.60, 0.23),
                    ProfilePoint(0.66, 0.09), ProfilePoint(0.72, 0.04)]
        case 1: // Oil Phial — long neck, round belly
            return [ProfilePoint(0.14, 0.055), ProfilePoint(0.22, 0.070), ProfilePoint(0.32, 0.075),
                    ProfilePoint(0.42, 0.115), ProfilePoint(0.54, 0.205), ProfilePoint(0.66, 0.245),
                    ProfilePoint(0.76, 0.235), ProfilePoint(0.83, 0.185), ProfilePoint(0.87, 0.145)]
        case 2: // Ribbed Tumbler — straight sided, slightly tapered
            return [ProfilePoint(0.22, 0.205), ProfilePoint(0.34, 0.205), ProfilePoint(0.50, 0.197),
                    ProfilePoint(0.66, 0.184), ProfilePoint(0.80, 0.168), ProfilePoint(0.86, 0.162)]
        case 3: // Stemmed Goblet — bowl, stem, spreading foot
            return [ProfilePoint(0.13, 0.215), ProfilePoint(0.20, 0.222), ProfilePoint(0.30, 0.198),
                    ProfilePoint(0.39, 0.120), ProfilePoint(0.45, 0.048), ProfilePoint(0.56, 0.038),
                    ProfilePoint(0.67, 0.038), ProfilePoint(0.74, 0.062), ProfilePoint(0.81, 0.160),
                    ProfilePoint(0.86, 0.225)]
        case 4: // Cut Decanter — stopper, shoulder, heavy base
            return [ProfilePoint(0.08, 0.062), ProfilePoint(0.12, 0.105), ProfilePoint(0.17, 0.062),
                    ProfilePoint(0.24, 0.052), ProfilePoint(0.32, 0.058), ProfilePoint(0.41, 0.140),
                    ProfilePoint(0.52, 0.245), ProfilePoint(0.64, 0.283), ProfilePoint(0.76, 0.272),
                    ProfilePoint(0.84, 0.220), ProfilePoint(0.88, 0.190)]
        case 5: // Cased Vase — waisted, two layers of glass
            return [ProfilePoint(0.11, 0.138), ProfilePoint(0.18, 0.118), ProfilePoint(0.29, 0.098),
                    ProfilePoint(0.40, 0.132), ProfilePoint(0.53, 0.222), ProfilePoint(0.65, 0.262),
                    ProfilePoint(0.77, 0.218), ProfilePoint(0.85, 0.152), ProfilePoint(0.89, 0.132)]
        case 6: // Ribbed Lantern — capped cylinder with a flared skirt
            return [ProfilePoint(0.08, 0.045), ProfilePoint(0.13, 0.105), ProfilePoint(0.19, 0.108),
                    ProfilePoint(0.24, 0.205), ProfilePoint(0.33, 0.232), ProfilePoint(0.62, 0.232),
                    ProfilePoint(0.72, 0.212), ProfilePoint(0.80, 0.238), ProfilePoint(0.86, 0.238),
                    ProfilePoint(0.90, 0.196)]
        default:
            return []
        }
    }

    /// Number of vertical ribs to score onto the piece, 0 for none.
    static func ribs(_ vesselID: Int) -> Int {
        switch vesselID {
        case 2: return 5
        case 4: return 4
        case 6: return 5
        default: return 0
        }
    }
}

/// The turned outline of a vessel. The chandelier arm is not a turned form, so it
/// gets its own path.
struct VesselSilhouette: Shape {
    let vesselID: Int

    func path(in rect: CGRect) -> Path {
        if vesselID >= 7 { return chandelierArm(in: rect) }
        let points = VesselProfiles.profile(vesselID)
        guard points.count >= 3 else { return Path() }

        func right(_ p: ProfilePoint) -> CGPoint {
            CGPoint(x: rect.midX + rect.width * p.half, y: rect.minY + rect.height * p.y)
        }
        func left(_ p: ProfilePoint) -> CGPoint {
            CGPoint(x: rect.midX - rect.width * p.half, y: rect.minY + rect.height * p.y)
        }

        var path = Path()
        let rightSide = points.map(right)
        let leftSide = points.reversed().map(left)
        path.move(to: rightSide[0])
        appendSmooth(&path, through: rightSide)
        path.addLine(to: leftSide[0])
        appendSmooth(&path, through: leftSide)
        path.closeSubpath()
        return path
    }

    /// Quadratic smoothing through a run of profile points, so the walls of the
    /// piece curve rather than reading as a chain of segments.
    private func appendSmooth(_ path: inout Path, through points: [CGPoint]) {
        guard points.count > 2 else {
            for point in points.dropFirst() { path.addLine(to: point) }
            return
        }
        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        path.addLine(to: points[points.count - 1])
    }

    /// The chandelier arm: a swept scroll ending in a bobeche and candle cup.
    private func chandelierArm(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var spine = Path()
        spine.move(to: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.86))
        spine.addCurve(to: CGPoint(x: rect.minX + w * 0.62, y: rect.minY + h * 0.40),
                       control1: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.58),
                       control2: CGPoint(x: rect.minX + w * 0.38, y: rect.minY + h * 0.36))
        spine.addCurve(to: CGPoint(x: rect.minX + w * 0.80, y: rect.minY + h * 0.30),
                       control1: CGPoint(x: rect.minX + w * 0.74, y: rect.minY + h * 0.44),
                       control2: CGPoint(x: rect.minX + w * 0.82, y: rect.minY + h * 0.38))
        var path = spine.strokedPath(StrokeStyle(lineWidth: max(w * 0.085, 1.5),
                                                 lineCap: .round, lineJoin: .round))
        // Bobeche — the drip pan.
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.60, y: rect.minY + h * 0.22,
                                   width: w * 0.40, height: h * 0.11))
        // Candle cup.
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.72, y: rect.minY + h * 0.06,
                                       width: w * 0.16, height: h * 0.18),
                            cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        // Counterweight knop at the socket end.
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.02, y: rect.minY + h * 0.78,
                                   width: w * 0.18, height: h * 0.18))
        return path
    }
}

/// The vertical scoring on ribbed pieces.
struct VesselRibs: Shape {
    let vesselID: Int

    func path(in rect: CGRect) -> Path {
        let count = VesselProfiles.ribs(vesselID)
        guard count > 0 else { return Path() }
        var path = Path()
        let top = rect.minY + rect.height * 0.32
        let bottom = rect.minY + rect.height * 0.76
        for index in 0..<count {
            let t = (CGFloat(index) + 0.5) / CGFloat(count)
            let x = rect.minX + rect.width * (0.30 + 0.40 * t)
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
        return path
    }
}

/// A finished or in-progress piece, drawn as glass.
///
/// `heat` runs 0 (cold, finished glass) to 1 (at working temperature). Cold pieces read
/// as sea-glass; hot ones glow. The colour is passed IN as a plain value so the view
/// redraws whenever the furnace moves.
struct VesselArtView: View {
    let vesselID: Int
    var heat: Double = 0
    var tint: Color = VitremberPalette.seaGlass
    var lineWidth: CGFloat = 1.6

    private var bodyFill: LinearGradient {
        let warm = VitremberPalette.blend(VitremberPalette.seaGlassDim, tint, min(max(heat, 0), 1))
        return LinearGradient(
            colors: [warm.opacity(0.30 + 0.45 * min(max(heat, 0), 1)), warm.opacity(0.14)],
            startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            VesselSilhouette(vesselID: vesselID)
                .fill(bodyFill)
            VesselRibs(vesselID: vesselID)
                .stroke(tint.opacity(0.30), lineWidth: max(lineWidth * 0.5, 0.6))
            VesselSilhouette(vesselID: vesselID)
                .stroke(tint.opacity(0.92),
                        style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
        }
        .compositingGroup()
        // Accessibility text is fine; the visual is entirely custom.
        .accessibilityLabel(Text(VesselCatalog.kind(vesselID).name))
    }
}

/// A small square swatch used in lists, sized by the caller.
struct VesselChip: View {
    let vesselID: Int
    var side: CGFloat = 40
    var tint: Color = VitremberPalette.seaGlass

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                .fill(VitremberPalette.night.opacity(0.55))
            VesselArtView(vesselID: vesselID, heat: 0, tint: tint, lineWidth: max(side * 0.035, 1))
                .padding(side * 0.14)
        }
        .frame(width: side, height: side)
    }
}

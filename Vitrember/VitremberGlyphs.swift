import SwiftUI

// Every icon in Vitrember is a hand-built `Shape`. No SF Symbols, no system
// imagery, no emoji anywhere in the interface.

/// The furnace mouth: a brick arch with an opening.
struct FurnaceGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let footY = rect.minY + h * 0.88
        // Outer arch
        path.move(to: CGPoint(x: rect.minX + w * 0.08, y: footY))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.48))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + h * 0.48),
                    radius: w * 0.42,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + w * 0.92, y: footY))
        path.closeSubpath()
        // Mouth
        var mouth = Path()
        mouth.move(to: CGPoint(x: rect.minX + w * 0.26, y: footY))
        mouth.addLine(to: CGPoint(x: rect.minX + w * 0.26, y: rect.minY + h * 0.50))
        mouth.addArc(center: CGPoint(x: rect.midX, y: rect.minY + h * 0.50),
                     radius: w * 0.24,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        mouth.addLine(to: CGPoint(x: rect.minX + w * 0.74, y: footY))
        mouth.closeSubpath()
        path.addPath(mouth)
        return path
    }
}

/// The glowing gather inside the furnace mouth — used as a filled counterpart.
struct GatherGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) * 0.30
        let centre = CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY - rect.height * 0.02)
        path.addEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        // Blowpipe running out to the lower left.
        var pipe = Path()
        pipe.move(to: CGPoint(x: centre.x - r * 0.55, y: centre.y + r * 0.35))
        pipe.addLine(to: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.maxY - rect.height * 0.02))
        path.addPath(pipe.strokedPath(StrokeStyle(lineWidth: max(rect.width * 0.075, 1.2),
                                                  lineCap: .round)))
        return path
    }
}

/// A workbench: a table top on two legs with a tool rail.
struct BenchGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let top = rect.minY + h * 0.40
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.06, y: top,
                                       width: w * 0.88, height: h * 0.13),
                            cornerSize: CGSize(width: h * 0.05, height: h * 0.05))
        path.addRect(CGRect(x: rect.minX + w * 0.16, y: top + h * 0.13,
                            width: w * 0.10, height: h * 0.40))
        path.addRect(CGRect(x: rect.minX + w * 0.74, y: top + h * 0.13,
                            width: w * 0.10, height: h * 0.40))
        // Two tools standing on the bench.
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.26, y: rect.minY + h * 0.14,
                                       width: w * 0.07, height: h * 0.26),
                            cornerSize: CGSize(width: w * 0.035, height: w * 0.035))
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.60, y: rect.minY + h * 0.20,
                                       width: w * 0.07, height: h * 0.20),
                            cornerSize: CGSize(width: w * 0.035, height: w * 0.035))
        return path
    }
}

/// A display shelf: two boards with pieces standing on them.
struct ShelfGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        for row in 0..<2 {
            let y = rect.minY + h * (0.46 + 0.36 * CGFloat(row))
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.06, y: y,
                                           width: w * 0.88, height: h * 0.08),
                                cornerSize: CGSize(width: h * 0.04, height: h * 0.04))
        }
        // Three pieces on the upper board.
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.16, y: rect.minY + h * 0.22,
                                   width: w * 0.18, height: h * 0.24))
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.42, y: rect.minY + h * 0.14,
                                       width: w * 0.14, height: h * 0.32),
                            cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
        path.addEllipse(in: CGRect(x: rect.minX + w * 0.66, y: rect.minY + h * 0.26,
                                   width: w * 0.16, height: h * 0.20))
        return path
    }
}

/// An open reference book.
struct AlmanacGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let spineX = rect.midX
        let top = rect.minY + h * 0.22
        let bottom = rect.maxY - h * 0.16
        // Left leaf
        path.move(to: CGPoint(x: rect.minX + w * 0.06, y: top + h * 0.06))
        path.addQuadCurve(to: CGPoint(x: spineX, y: top),
                          control: CGPoint(x: rect.minX + w * 0.26, y: top - h * 0.06))
        path.addLine(to: CGPoint(x: spineX, y: bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.06, y: bottom - h * 0.05),
                          control: CGPoint(x: rect.minX + w * 0.26, y: bottom + h * 0.03))
        path.closeSubpath()
        // Right leaf
        path.move(to: CGPoint(x: rect.maxX - w * 0.06, y: top + h * 0.06))
        path.addQuadCurve(to: CGPoint(x: spineX, y: top),
                          control: CGPoint(x: rect.maxX - w * 0.26, y: top - h * 0.06))
        path.addLine(to: CGPoint(x: spineX, y: bottom))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - w * 0.06, y: bottom - h * 0.05),
                          control: CGPoint(x: rect.maxX - w * 0.26, y: bottom + h * 0.03))
        path.closeSubpath()
        return path
    }
}

/// A ledger page with ruled lines.
struct LedgerGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.14, y: rect.minY + h * 0.10,
                                       width: w * 0.72, height: h * 0.80),
                            cornerSize: CGSize(width: w * 0.07, height: w * 0.07))
        for row in 0..<3 {
            let y = rect.minY + h * (0.30 + 0.18 * CGFloat(row))
            let width = row == 2 ? w * 0.28 : w * 0.44
            path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.24, y: y,
                                           width: width, height: h * 0.06),
                                cornerSize: CGSize(width: h * 0.03, height: h * 0.03))
        }
        return path
    }
}

/// The coin used for money readouts — a milled disc with a bead motif.
struct CoinGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let box = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        var path = Path()
        path.addEllipse(in: box)
        path.addEllipse(in: box.insetBy(dx: side * 0.30, dy: side * 0.30))
        return path
    }
}

/// A Hallmark: the stamped maker's mark punched into finished work.
struct HallmarkGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.10, y: rect.minY + h * 0.30))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.10, y: rect.minY + h * 0.62))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - h * 0.06))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.62))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.30))
        path.closeSubpath()
        return path
    }
}

/// A bellows: the thing the treadle drives.
struct BellowsGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: rect.minX + w * 0.10, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.56, y: rect.minY + h * 0.16),
                          control: CGPoint(x: rect.minX + w * 0.14, y: rect.minY + h * 0.14))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.62, y: rect.midY - h * 0.09),
                          control: CGPoint(x: rect.minX + w * 0.66, y: rect.minY + h * 0.26))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.06, y: rect.midY - h * 0.05))
        path.addLine(to: CGPoint(x: rect.maxX - w * 0.06, y: rect.midY + h * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.62, y: rect.midY + h * 0.09))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.56, y: rect.maxY - h * 0.16),
                          control: CGPoint(x: rect.minX + w * 0.66, y: rect.maxY - h * 0.26))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w * 0.10, y: rect.midY),
                          control: CGPoint(x: rect.minX + w * 0.14, y: rect.maxY - h * 0.14))
        path.closeSubpath()
        return path
    }
}

/// A tick, for completed records.
struct TickGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.midY + rect.height * 0.02))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.minY + rect.height * 0.24))
        return path
    }
}

/// A padlock body, for content still to unlock.
struct LockGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.addRoundedRect(in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + h * 0.44,
                                       width: w * 0.64, height: h * 0.42),
                            cornerSize: CGSize(width: w * 0.10, height: w * 0.10))
        var shackle = Path()
        shackle.addArc(center: CGPoint(x: rect.midX, y: rect.minY + h * 0.44),
                       radius: w * 0.22,
                       startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addPath(shackle.strokedPath(StrokeStyle(lineWidth: max(w * 0.10, 1.0), lineCap: .round)))
        return path
    }
}

/// A right-pointing chevron for rows that lead somewhere.
struct ChevronGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.30, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.maxY - rect.height * 0.18))
        return path
    }
}

/// A downward caret used by the vessel picker.
struct CaretGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.34))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.30))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.34))
        return path
    }
}

/// A small X used to close overlays.
struct CloseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = min(rect.width, rect.height) * 0.26
        let box = rect.insetBy(dx: inset, dy: inset)
        path.move(to: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.maxY))
        path.move(to: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.minX, y: box.maxY))
        return path
    }
}

/// Small composed badge used to prefix money figures.
struct CoinBadge: View {
    var size: CGFloat = 13
    var tint: Color = VitremberPalette.ember
    var body: some View {
        CoinGlyph()
            .fill(tint, style: FillStyle(eoFill: true))
            .frame(width: size, height: size)
    }
}

/// Small composed badge for Hallmarks.
struct HallmarkBadge: View {
    var size: CGFloat = 13
    var tint: Color = VitremberPalette.seaGlass
    var body: some View {
        HallmarkGlyph()
            .stroke(tint, style: StrokeStyle(lineWidth: max(size * 0.11, 1), lineJoin: .round))
            .frame(width: size, height: size)
    }
}

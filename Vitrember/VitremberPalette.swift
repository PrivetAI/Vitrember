import SwiftUI

/// Every colour in Vitrember is declared here as a literal sRGB value.
/// Nothing is derived from the system palette, so the workshop looks identical
/// whether the device is in light or dark mode.
enum VitremberPalette {

    private static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    // Structure ---------------------------------------------------------
    /// Deepest background, behind everything.
    static let night = hex(0x08181C)
    /// The teal of the furnace room, matching the app icon field.
    static let shell = hex(0x0E2C33)
    /// Raised card surface.
    static let plate = hex(0x143840)
    /// Card surface one step brighter, for selected / active rows.
    static let plateHot = hex(0x1B4A54)
    /// Hairline that separates plates.
    static let seam = hex(0x24606B)
    /// Fire-brick charcoal, used for the furnace body.
    static let brick = hex(0x22282B)
    static let brickEdge = hex(0x333B3F)

    // Heat ---------------------------------------------------------------
    /// Working heat — the colour of glass that can be shaped.
    static let molten = hex(0xFF8C1A)
    /// The hottest readable highlight.
    static let ember = hex(0xFFC42E)
    /// Below the working band: the piece is stiffening.
    static let chill = hex(0x6FA8D6)
    /// Above the working band: the piece is slumping.
    static let scorch = hex(0xE8503C)

    // Glass --------------------------------------------------------------
    /// Cooled, finished glass.
    static let seaGlass = hex(0x8FDCC0)
    /// A softer version for fills.
    static let seaGlassDim = hex(0x4E8C7C)

    // Type ---------------------------------------------------------------
    static let ivory = hex(0xF3EADB)
    static let muted = hex(0x93AEB4)
    static let faint = hex(0x5E7C83)

    // Quality ladder -----------------------------------------------------
    static let flawed = hex(0x8B8175)
    static let sound = hex(0x8FDCC0)
    static let fine = hex(0x5FBBE8)
    static let masterwork = hex(0xFFC42E)

    /// Colour a temperature takes on the gauge, given the piece's working band.
    static func heatTint(_ temperature: Double, band: VitremberBand?) -> Color {
        guard let band = band else {
            // No piece on the bench: purely a function of absolute heat.
            let t = min(max((temperature - 700) / 500, 0), 1)
            return blend(chill, molten, t)
        }
        if temperature < band.low { return chill }
        if temperature > band.high { return scorch }
        return band.contains(core: temperature) ? ember : molten
    }

    static func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let k = min(max(t, 0), 1)
        let ca = UIColor(a)
        let cb = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ca.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1) + (Double(r2) - Double(r1)) * k,
            green: Double(g1) + (Double(g2) - Double(g1)) * k,
            blue: Double(b1) + (Double(b2) - Double(b1)) * k
        )
    }
}

/// Type ramp. Readouts are monospaced so the numbers do not jitter as they change —
/// the workshop is meant to read like an instrument panel.
enum VitremberType {
    static func readout(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    /// Small tracked-out uppercase label used for section headers.
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
}

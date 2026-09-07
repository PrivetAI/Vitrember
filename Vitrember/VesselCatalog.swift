import Foundation

/// The temperature window a piece can actually be worked in.
/// `core` is the narrower middle stripe: time spent there is what earns a high tier.
struct VitremberBand {
    let low: Double
    let high: Double
    /// Fraction of the band width occupied by the core stripe (0...1), centred.
    let coreFraction: Double

    var width: Double { high - low }
    var centre: Double { (low + high) / 2 }
    var coreLow: Double { centre - width * coreFraction / 2 }
    var coreHigh: Double { centre + width * coreFraction / 2 }

    func contains(_ t: Double) -> Bool { t >= low && t <= high }
    func contains(core t: Double) -> Bool { t >= coreLow && t <= coreHigh }

    /// Where a temperature sits across the band, 0 at `low` and 1 at `high`.
    /// Clamped, so it is safe to drive a bar with.
    func position(_ t: Double) -> Double {
        guard width > 0 else { return 0.5 }
        return min(max((t - low) / width, 0), 1)
    }
}

/// How well the piece was held. Drives the sale price, hard.
enum GlassGrade: Int, CaseIterable, Codable {
    case flawed = 0
    case sound = 1
    case fine = 2
    case masterwork = 3

    var title: String {
        switch self {
        case .flawed: return "Flawed"
        case .sound: return "Sound"
        case .fine: return "Fine"
        case .masterwork: return "Masterwork"
        }
    }

    /// Price multiplier. Deliberately steep — the whole point of hands-on play.
    var priceFactor: Double {
        switch self {
        case .flawed: return 0.35
        case .sound: return 1.0
        case .fine: return 2.4
        case .masterwork: return 6.0
        }
    }

    /// Share of working time that must be spent inside the core stripe to reach this grade.
    /// Precision runs 0.55 (never in core) to 1.00 (always in core).
    static func from(precision: Double) -> GlassGrade {
        if precision >= 0.930 { return .masterwork }
        if precision >= 0.800 { return .fine }
        if precision >= 0.660 { return .sound }
        return .flawed
    }
}

/// One kind of thing the workshop can make.
struct VesselKind: Identifiable {
    let id: Int
    let name: String
    /// Seconds of *in-band* time needed to finish the piece.
    let workSeconds: Double
    /// Centre of the working window, in degrees.
    let targetTemperature: Double
    /// Raw width of the working window before any upgrade widens it.
    let baseBandWidth: Double
    /// Sale price of a Sound example, before reputation and hallmarks.
    let basePrice: Double
    /// Lifetime coins the workshop must have earned before this kind unlocks.
    let unlockLifetime: Double
    /// One-line note shown in the Almanac.
    let note: String
}

enum VesselCatalog {

    static let all: [VesselKind] = [
        VesselKind(id: 0, name: "Glass Bead",
                   workSeconds: 4.0, targetTemperature: 1020, baseBandWidth: 260,
                   basePrice: 10, unlockLifetime: 0,
                   note: "A wound bead. Forgiving enough to learn the treadle on."),
        VesselKind(id: 1, name: "Oil Phial",
                   workSeconds: 7.0, targetTemperature: 1045, baseBandWidth: 200,
                   basePrice: 46, unlockLifetime: 900,
                   note: "Thin walls. Lets go of its heat faster than it looks."),
        VesselKind(id: 2, name: "Ribbed Tumbler",
                   workSeconds: 10.0, targetTemperature: 1070, baseBandWidth: 160,
                   basePrice: 172, unlockLifetime: 9_000,
                   note: "The ribs only take if the gather stays even throughout."),
        VesselKind(id: 3, name: "Stemmed Goblet",
                   workSeconds: 14.0, targetTemperature: 1090, baseBandWidth: 120,
                   basePrice: 630, unlockLifetime: 90_000,
                   note: "The stem is pulled last, and it is the first thing to sag."),
        VesselKind(id: 4, name: "Cut Decanter",
                   workSeconds: 19.0, targetTemperature: 1105, baseBandWidth: 92,
                   basePrice: 2_250, unlockLifetime: 850_000,
                   note: "Heavy walls hold heat, so an overshoot takes a long time to undo."),
        VesselKind(id: 5, name: "Cased Vase",
                   workSeconds: 25.0, targetTemperature: 1120, baseBandWidth: 74,
                   basePrice: 7_800, unlockLifetime: 7_500_000,
                   note: "Two colours of glass, one window. Neither forgives the other."),
        VesselKind(id: 6, name: "Ribbed Lantern",
                   workSeconds: 32.0, targetTemperature: 1135, baseBandWidth: 60,
                   basePrice: 26_000, unlockLifetime: 65_000_000,
                   note: "Long enough that a single lapse of attention is felt in the price."),
        VesselKind(id: 7, name: "Chandelier Arm",
                   workSeconds: 40.0, targetTemperature: 1150, baseBandWidth: 50,
                   basePrice: 86_000, unlockLifetime: 550_000_000,
                   note: "Forty seconds inside fifty degrees. This is what the upgrades are for.")
    ]

    static func kind(_ id: Int) -> VesselKind {
        all[min(max(id, 0), all.count - 1)]
    }

    /// Coins burned to gather a fresh parison. Small, but real — a cracked piece is a loss.
    /// The bead is free so a broke workshop can never be stuck.
    static func gatherCost(_ kind: VesselKind) -> Double {
        kind.id == 0 ? 0 : kind.basePrice * 0.06
    }

    /// Lowest temperature any band reaches, used to size the gauge.
    static let gaugeFloor: Double = 700
    static let gaugeCeiling: Double = 1260
}

import Foundation

/// Everything the workshop can buy.
///
/// Design rule for this game: almost nothing here multiplies money. Upgrades change the
/// *shape of the problem* — how fast the furnace loses heat, how coarse the treadle is,
/// how wide the working window is. Only `standing` touches price, and it is hard-capped
/// at five levels, so nothing can compound into a runaway.
enum VitremberUpgrade: Int, CaseIterable, Identifiable, Codable {
    case lining
    case governor
    case marver
    case gaffersEye
    case lehr
    case extraBench
    case apprentice
    case training
    case fuelStore
    case standing

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .lining:      return "Kiln Lining"
        case .governor:    return "Treadle Governor"
        case .marver:      return "Marver Plate"
        case .gaffersEye:  return "Gaffer's Eye"
        case .lehr:        return "Annealing Lehr"
        case .extraBench:  return "Extra Bench"
        case .apprentice:  return "Apprentice"
        case .training:    return "Apprentice Training"
        case .fuelStore:   return "Fuel Store"
        case .standing:    return "Guild Standing"
        }
    }

    var blurb: String {
        switch self {
        case .lining:
            return "Denser refractory brick. The furnace sheds heat more slowly, so you have longer between strokes."
        case .governor:
            return "A geared treadle. Each stroke lifts the heat by LESS, which is what makes a narrow window holdable."
        case .marver:
            return "A truer steel table. Every vessel's working window gets wider — the whole catalogue becomes more forgiving."
        case .gaffersEye:
            return "Practised judgement. The core of each window — the stripe that earns Fine and Masterwork — grows."
        case .lehr:
            return "A slow-cooling oven. A cracked piece is recovered instead of lost, and the salvage is proportional to how far it had got \u{2014} so it protects work already done rather than paying for failure."
        case .extraBench:
            return "A second and then a third bench. More pieces at once — but all of them share ONE furnace temperature."
        case .apprentice:
            return "Apprentices work unattended, day and night. They hold the window but never the core, so they only ever make Sound glass."
        case .training:
            return "Drill on the treadle. Every apprentice works faster. It does not improve what they can make."
        case .fuelStore:
            return "Banked fuel. The apprentices keep working for longer after you close the shop."
        case .standing:
            return "Reputation with the guild halls. Every piece sells for more. Capped at five — the guild only recognises so much."
        }
    }

    /// Header the row sits under on the Bench screen.
    var group: String {
        switch self {
        case .lining, .governor, .marver, .gaffersEye: return "The Furnace"
        case .lehr, .extraBench:                       return "The Shop Floor"
        case .apprentice, .training, .fuelStore:       return "Apprentices"
        case .standing:                                return "The Guild"
        }
    }

    var maxLevel: Int {
        switch self {
        case .lining:     return 12
        case .governor:   return 10
        case .marver:     return 8
        case .gaffersEye: return 6
        case .lehr:       return 4
        case .extraBench: return 2
        case .apprentice: return 8
        case .training:   return 10
        case .fuelStore:  return 6
        case .standing:   return 5
        }
    }

    private var baseCost: Double {
        switch self {
        case .lining:     return 60
        case .governor:   return 140
        case .marver:     return 900
        case .gaffersEye: return 4_200
        case .lehr:       return 2_600
        case .extraBench: return 6_000
        case .apprentice: return 320
        case .training:   return 1_500
        case .fuelStore:  return 3_500
        case .standing:   return 25_000
        }
    }

    private var growth: Double {
        switch self {
        case .lining:     return 1.90
        case .governor:   return 2.05
        case .marver:     return 2.30
        case .gaffersEye: return 2.70
        case .lehr:       return 3.00
        case .extraBench: return 14.00
        case .apprentice: return 2.35
        case .training:   return 2.15
        case .fuelStore:  return 2.60
        case .standing:   return 4.20
        }
    }

    /// Coins to go from `level` to `level + 1`.
    func cost(atLevel level: Int) -> Double {
        baseCost * pow(growth, Double(level))
    }

    /// Human-readable statement of what the NEXT level does.
    func nextEffect(atLevel level: Int) -> String {
        guard level < maxLevel else { return "Fully fitted." }
        switch self {
        case .lining:     return "Heat loss \u{2212}4%"
        case .governor:   return "Stroke \u{2212}6\u{00B0}, finer control"
        case .marver:     return "Every window +5% wider"
        case .gaffersEye: return "Core stripe +4% of the window"
        case .lehr:
            return level == 0 ? "Recover cracked pieces for part of their value"
                              : "Faster recovery, better salvage"
        case .extraBench: return level == 0 ? "A second bench" : "A third bench"
        case .apprentice: return "One more apprentice"
        case .training:   return "Apprentices +7% faster"
        case .fuelStore:  return "Offline work +2 hours"
        case .standing:   return "All sales +12%"
        }
    }

    /// What the CURRENT level already gives, for the "owned" line.
    func currentEffect(atLevel level: Int) -> String {
        switch self {
        case .lining:
            return "Heat loss \u{00D7}" + String(format: "%.2f", pow(0.96, Double(level)))
        case .governor:
            return "Stroke " + String(format: "%.0f", VitremberTuning.strokeHeat(governor: level)) + "\u{00B0}"
        case .marver:
            return "Windows \u{00D7}" + String(format: "%.2f", pow(1.05, Double(level)))
        case .gaffersEye:
            return "Core " + VitremberFormat.percent(VitremberTuning.coreFraction(gaffersEye: level))
        case .lehr:
            return level == 0 ? "Not built"
                              : "Salvage " + VitremberFormat.percent(VitremberTuning.lehrSalvage(level: level))
        case .extraBench:
            return "\(1 + level) bench" + (level == 0 ? "" : "es")
        case .apprentice:
            return "\(level) working"
        case .training:
            return "Speed \u{00D7}" + String(format: "%.2f", 1.0 + 0.07 * Double(level))
        case .fuelStore:
            return VitremberFormat.duration(VitremberTuning.offlineCapSeconds(fuelStore: level)) + " banked"
        case .standing:
            return "Sales +" + VitremberFormat.percent(0.12 * Double(level))
        }
    }
}

/// Every tuning constant in one place, so the headless economy check and the game
/// read from exactly the same numbers.
enum VitremberTuning {

    // --- Furnace ---------------------------------------------------------
    /// Degrees the furnace sheds per second with no lining at all.
    static let baseDecay: Double = 26.0
    /// Degrees one treadle stroke adds, ungeared.
    static let baseStroke: Double = 38.0
    /// Minimum seconds between strokes. Holding the treadle repeats at exactly this
    /// cadence, so hammering the button faster than this buys nothing — the skill is
    /// knowing when to STOP, not how fast you can tap.
    static let strokeCooldown: Double = 0.55
    /// Where a cold furnace settles if nobody works it.
    static let idleFloor: Double = 700.0
    /// Furnace temperature at the start of a fresh run.
    static let startTemperature: Double = 900.0

    static func decay(lining: Int) -> Double { baseDecay * pow(0.96, Double(lining)) }
    static func strokeHeat(governor: Int) -> Double { baseStroke * pow(0.94, Double(governor)) }
    static func bandScale(marver: Int) -> Double { pow(1.05, Double(marver)) }
    static func coreFraction(gaffersEye: Int) -> Double { 0.34 + 0.04 * Double(gaffersEye) }

    // --- Piece behaviour -------------------------------------------------
    /// Seconds below the working window before the piece cracks.
    static let crackSeconds: Double = 5.0
    /// How fast a chilled piece recovers once it is back in the window,
    /// as a fraction of the chill rate.
    static let chillRecoveryRate: Double = 0.5
    /// Seconds above the window that cost one grade of quality.
    static let slumpSeconds: Double = 3.2
    /// Slump units at which the piece is capped at Flawed and can fall no further.
    /// Overheating never ENDS a piece — it only costs grade, and the piece must still be
    /// completed normally. Letting a ruined piece finish early would make a deliberate
    /// overheat pay better per second than honest work on the long vessels.
    static let slumpCollapse: Double = 3.0
    /// Quality credit per second while inside the core stripe / merely inside the window.
    static let coreCredit: Double = 1.0
    static let bandCredit: Double = 0.55

    // --- Apprentices -----------------------------------------------------
    /// Apprentices work at this fraction of your own pace before training.
    static let apprenticeBaseSpeed: Double = 0.55
    static func apprenticeSpeed(training: Int) -> Double {
        apprenticeBaseSpeed * (1.0 + 0.07 * Double(training))
    }
    /// An apprentice bench holds the window but never the core, so it is
    /// permanently Sound. Automation buys volume, never mastery.
    static let apprenticeGrade: GlassGrade = .sound

    // --- Lehr ------------------------------------------------------------
    static func lehrSeconds(level: Int) -> Double {
        level <= 0 ? 0 : max(24.0 - 4.0 * Double(level - 1), 8.0)
    }
    /// Fraction of a Sound sale a salvaged piece fetches AT FULL PROGRESS. The actual
    /// payout is multiplied by how far the piece had got, so a deliberately cracked
    /// fresh gather recovers essentially nothing. Even at full progress this stays below
    /// the Flawed factor of 0.35, so cracking can never beat finishing.
    static func lehrSalvage(level: Int) -> Double {
        level <= 0 ? 0 : 0.18 + 0.04 * Double(level - 1)
    }

    // --- Offline ---------------------------------------------------------
    static func offlineCapSeconds(fuelStore: Int) -> Double {
        (4.0 + 2.0 * Double(fuelStore)) * 3600.0
    }

    // --- Money -----------------------------------------------------------
    static func standingMultiplier(_ level: Int) -> Double { 1.0 + 0.12 * Double(level) }
    static func hallmarkMultiplier(_ hallmarks: Int) -> Double { 1.0 + 0.05 * Double(hallmarks) }

    // --- Relighting the furnace (prestige) -------------------------------
    /// Coins a single run must earn before the furnace may be relit.
    ///
    /// The bar RISES with the Hallmarks already held. A fixed bar is farmable: once
    /// income outruns it, a player relights every few seconds and the meta currency
    /// compounds without limit. Because the award below is flat rather than a function
    /// of absolute earnings, each relight instead costs about three times as long as
    /// the last, and the Hallmark count grows with the LOGARITHM of time played.
    static func relightThreshold(hallmarks: Int) -> Double {
        750_000 * pow(4.0, Double(max(hallmarks, 0)) / 5.0)
    }

    /// Hallmarks a relight would award: a flat base, a bonus for banking well past the
    /// bar rather than the instant it is cleared, and a capped kicker for masterworks so
    /// hands-on play pays in the meta currency too.
    static func hallmarksFor(lifetime: Double, masterworks: Int, hallmarks: Int) -> Int {
        let bar = relightThreshold(hallmarks: hallmarks)
        guard lifetime >= bar else { return 0 }
        let base = 4.0
        let push = log10(max(lifetime / bar, 1.0)) * 3.0
        let craft = min(Double(masterworks) / 40.0, 6.0)
        return max(1, Int((base + push + craft).rounded(.down)))
    }
}

/// Permanent perks unlocked by total Hallmarks. These survive every relight.
struct StandingOrder {
    let hallmarks: Int
    let title: String
    let detail: String
}

enum StandingOrders {
    static let all: [StandingOrder] = [
        StandingOrder(hallmarks: 3, title: "Lehr Kept Warm",
                      detail: "Every new run starts with the Annealing Lehr already built."),
        StandingOrder(hallmarks: 8, title: "A Hand Retained",
                      detail: "A second apprentice stays on after a relight."),
        StandingOrder(hallmarks: 15, title: "Brick Reserved",
                      detail: "Kiln Lining starts each run at level 3."),
        StandingOrder(hallmarks: 25, title: "Shop Retained",
                      detail: "Three apprentices stay on, and the Treadle Governor starts at level 2."),
        StandingOrder(hallmarks: 40, title: "Table Reserved",
                      detail: "The Marver Plate starts each run at level 2.")
    ]

    static func startingLevels(hallmarks: Int) -> [VitremberUpgrade: Int] {
        var levels: [VitremberUpgrade: Int] = [:]
        if hallmarks >= 3 { levels[.lehr] = 1 }
        if hallmarks >= 8 { levels[.apprentice] = 2 }
        if hallmarks >= 15 { levels[.lining] = 3 }
        if hallmarks >= 25 {
            levels[.apprentice] = 3
            levels[.governor] = 2
        }
        if hallmarks >= 40 { levels[.marver] = 2 }
        return levels
    }

    static let ranks: [(threshold: Int, name: String)] = [
        (0, "Apprentice"),
        (5, "Journeyman"),
        (15, "Gaffer"),
        (35, "Master Gaffer"),
        (70, "Guild Warden"),
        (120, "Kilnmaster")
    ]

    static func rank(for hallmarks: Int) -> String {
        var name = ranks[0].name
        for entry in ranks where hallmarks >= entry.threshold { name = entry.name }
        return name
    }
}

import Foundation

/// A piece in progress on one of your own benches.
struct BenchPiece: Codable {
    var vesselID: Int = 0
    /// 0...1, advances only while the furnace is inside the piece's working window.
    var progress: Double = 0
    /// Quality credit banked so far, in "seconds of core-grade work".
    var qualityCredit: Double = 0
    /// 0...1. Reaches 1 and the piece cracks.
    var chill: Double = 0
    /// Whole units cost one grade each; `slumpCollapse` units deform the piece outright.
    var slump: Double = 0

    init() {}
    init(vesselID: Int) { self.vesselID = vesselID }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vesselID      = try c.decodeIfPresent(Int.self,    forKey: .vesselID)      ?? 0
        progress      = try c.decodeIfPresent(Double.self, forKey: .progress)      ?? 0
        qualityCredit = try c.decodeIfPresent(Double.self, forKey: .qualityCredit) ?? 0
        chill         = try c.decodeIfPresent(Double.self, forKey: .chill)         ?? 0
        slump         = try c.decodeIfPresent(Double.self, forKey: .slump)         ?? 0
    }
}

/// A cracked piece waiting in the annealing oven.
struct LehrItem: Codable, Identifiable {
    var id: Int = 0
    var vesselID: Int = 0
    var remaining: Double = 0
    /// How far the piece had got before it cracked. Salvage is proportional to this, so
    /// deliberately cracking a fresh gather recovers essentially nothing — the lehr
    /// protects work already done, it is not an alternative way to earn.
    var progress: Double = 0

    init(id: Int = 0, vesselID: Int = 0, remaining: Double = 0, progress: Double = 0) {
        self.id = id
        self.vesselID = vesselID
        self.remaining = remaining
        self.progress = progress
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decodeIfPresent(Int.self,    forKey: .id)        ?? 0
        vesselID  = try c.decodeIfPresent(Int.self,    forKey: .vesselID)  ?? 0
        remaining = try c.decodeIfPresent(Double.self, forKey: .remaining) ?? 0
        progress  = try c.decodeIfPresent(Double.self, forKey: .progress)  ?? 0
    }
}

/// The permanent tally for one vessel kind. Survives every relight — the collection
/// is the one thing you keep.
struct VesselRecord: Codable {
    /// Counts indexed by `GlassGrade.rawValue`.
    var byGrade: [Int] = [0, 0, 0, 0]
    var cracked: Int = 0
    var slumped: Int = 0
    var bestPrecision: Double = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var grades = try c.decodeIfPresent([Int].self, forKey: .byGrade) ?? [0, 0, 0, 0]
        while grades.count < 4 { grades.append(0) }
        byGrade       = Array(grades.prefix(4))
        cracked       = try c.decodeIfPresent(Int.self,    forKey: .cracked)       ?? 0
        slumped       = try c.decodeIfPresent(Int.self,    forKey: .slumped)       ?? 0
        bestPrecision = try c.decodeIfPresent(Double.self, forKey: .bestPrecision) ?? 0
    }

    var total: Int { byGrade.reduce(0, +) }

    var bestGrade: GlassGrade? {
        for index in stride(from: 3, through: 0, by: -1) where byGrade[index] > 0 {
            return GlassGrade(rawValue: index)
        }
        return nil
    }
}

/// The whole persisted state of the workshop.
///
/// EVERY field decodes through `decodeIfPresent ?? default`. New fields can therefore be
/// added in a later version without the synthesised decoder throwing on the missing key
/// and silently wiping a player's progress.
struct VitremberSave: Codable {

    // Money -----------------------------------------------------------------
    var coins: Double = 25
    /// Coins earned since the last relight. Drives the relight award.
    var runEarnings: Double = 0
    /// Coins earned across every run.
    var allTimeEarnings: Double = 0
    /// Split of `allTimeEarnings` by where it came from, for the honest HUD.
    var handEarnings: Double = 0
    var apprenticeEarnings: Double = 0

    // Meta ------------------------------------------------------------------
    var hallmarks: Int = 0
    var relights: Int = 0

    // Upgrades --------------------------------------------------------------
    /// Keyed by `VitremberUpgrade.rawValue` rendered as a string.
    var upgradeLevels: [String: Int] = [:]

    // Benches ---------------------------------------------------------------
    /// Vessel chosen on each of the (up to three) benches.
    var benchVessel: [Int] = [0, 0, 0]
    /// `nil` entries are empty benches. Always three long.
    var benchPieces: [BenchPiece?] = [nil, nil, nil]

    // Furnace ---------------------------------------------------------------
    var temperature: Double = VitremberTuning.startTemperature

    // Apprentices -----------------------------------------------------------
    /// Seconds of apprentice work banked toward the next finished piece.
    var apprenticeProgress: Double = 0

    // Annealing lehr --------------------------------------------------------
    var lehrQueue: [LehrItem] = []
    var lehrNextID: Int = 1

    // Records ---------------------------------------------------------------
    /// One entry per `VesselCatalog.all` index.
    var records: [VesselRecord] = []
    var masterworksThisRun: Int = 0
    var masterworksAllTime: Int = 0
    var piecesFinished: Int = 0
    var piecesCracked: Int = 0
    var piecesSalvaged: Int = 0
    var bestSinglePrice: Double = 0

    // Milestones ------------------------------------------------------------
    var milestonesDone: [Int] = []

    // Lifecycle -------------------------------------------------------------
    /// Stamped ONLY when the scene actually goes to `.background`. `.inactive` fires on
    /// the way in and on the way out, so stamping there zeroes every offline credit.
    var lastActive: Double = Date().timeIntervalSince1970
    /// Set once the player has dismissed the opening explanation.
    var briefed: Bool = false

    // Preferences -----------------------------------------------------------
    /// Re-gather automatically when a bench empties, but only while the furnace is
    /// still near working heat — so it never quietly drains coins after you put the
    /// phone down.
    var autoGather: Bool = true
    var haptics: Bool = true

    init() {
        records = VesselCatalog.all.map { _ in VesselRecord() }
        // The shop opens with one apprentice already on the floor. Without them a player
        // who never touches the treadle earns nothing at all and can never afford the
        // first hire, so the idle half of the game would never start.
        upgradeLevels[String(VitremberUpgrade.apprentice.rawValue)] = 1
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        coins              = try c.decodeIfPresent(Double.self, forKey: .coins)              ?? 25
        runEarnings        = try c.decodeIfPresent(Double.self, forKey: .runEarnings)        ?? 0
        allTimeEarnings    = try c.decodeIfPresent(Double.self, forKey: .allTimeEarnings)    ?? 0
        handEarnings       = try c.decodeIfPresent(Double.self, forKey: .handEarnings)       ?? 0
        apprenticeEarnings = try c.decodeIfPresent(Double.self, forKey: .apprenticeEarnings) ?? 0

        hallmarks = try c.decodeIfPresent(Int.self, forKey: .hallmarks) ?? 0
        relights  = try c.decodeIfPresent(Int.self, forKey: .relights)  ?? 0

        upgradeLevels = try c.decodeIfPresent([String: Int].self, forKey: .upgradeLevels) ?? [:]

        var vessels = try c.decodeIfPresent([Int].self, forKey: .benchVessel) ?? [0, 0, 0]
        while vessels.count < 3 { vessels.append(0) }
        benchVessel = Array(vessels.prefix(3))

        var pieces = try c.decodeIfPresent([BenchPiece?].self, forKey: .benchPieces) ?? [nil, nil, nil]
        while pieces.count < 3 { pieces.append(nil) }
        benchPieces = Array(pieces.prefix(3))

        temperature = try c.decodeIfPresent(Double.self, forKey: .temperature) ?? VitremberTuning.startTemperature

        apprenticeProgress = try c.decodeIfPresent(Double.self, forKey: .apprenticeProgress) ?? 0

        lehrQueue  = try c.decodeIfPresent([LehrItem].self, forKey: .lehrQueue) ?? []
        lehrNextID = try c.decodeIfPresent(Int.self, forKey: .lehrNextID) ?? 1

        var loaded = try c.decodeIfPresent([VesselRecord].self, forKey: .records) ?? []
        while loaded.count < VesselCatalog.all.count { loaded.append(VesselRecord()) }
        records = Array(loaded.prefix(VesselCatalog.all.count))

        masterworksThisRun = try c.decodeIfPresent(Int.self, forKey: .masterworksThisRun) ?? 0
        masterworksAllTime = try c.decodeIfPresent(Int.self, forKey: .masterworksAllTime) ?? 0
        piecesFinished     = try c.decodeIfPresent(Int.self, forKey: .piecesFinished)     ?? 0
        piecesCracked      = try c.decodeIfPresent(Int.self, forKey: .piecesCracked)      ?? 0
        piecesSalvaged     = try c.decodeIfPresent(Int.self, forKey: .piecesSalvaged)     ?? 0
        bestSinglePrice    = try c.decodeIfPresent(Double.self, forKey: .bestSinglePrice) ?? 0

        milestonesDone = try c.decodeIfPresent([Int].self, forKey: .milestonesDone) ?? []

        lastActive = try c.decodeIfPresent(Double.self, forKey: .lastActive) ?? Date().timeIntervalSince1970
        briefed    = try c.decodeIfPresent(Bool.self,   forKey: .briefed)    ?? false

        autoGather = try c.decodeIfPresent(Bool.self, forKey: .autoGather) ?? true
        haptics    = try c.decodeIfPresent(Bool.self, forKey: .haptics)    ?? true
    }

    // Convenience ------------------------------------------------------------
    func level(_ upgrade: VitremberUpgrade) -> Int {
        upgradeLevels[String(upgrade.rawValue)] ?? 0
    }

    mutating func setLevel(_ upgrade: VitremberUpgrade, _ value: Int) {
        upgradeLevels[String(upgrade.rawValue)] = value
    }
}

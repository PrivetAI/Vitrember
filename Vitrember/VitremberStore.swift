import SwiftUI
import UIKit

/// A short labelled note that rises off the bench. Every one says WHAT it is —
/// heat is never drawn as money, and money always names the piece that earned it.
struct VitremberFloater: Identifiable {
    enum Kind { case heat, sale, crack, salvage, note }
    let id: UUID = UUID()
    let text: String
    let kind: Kind
    /// Which bench it belongs to; -1 means the furnace itself.
    let lane: Int
    var life: Double
    let span: Double
}

/// What the apprentices got done while the shop was shut.
struct ApprenticeLog: Identifiable {
    let id = UUID()
    let away: Double
    let credited: Double
    let coins: Double
    let pieces: Int
    let vesselName: String
    let cracked: Int
    let capped: Bool
}

/// The workshop.
final class VitremberStore: ObservableObject {

    @Published var save = VitremberSave()
    @Published var floaters: [VitremberFloater] = []
    @Published var apprenticeLog: ApprenticeLog?
    /// Rolling estimate of what YOUR hands are earning, coins per second.
    @Published private(set) var handRate: Double = 0
    /// True while the treadle is held down.
    @Published private(set) var pumping = false

    private static let storageKey = "vitrember.workshop.v1"

    private var ticker: Timer?
    private var lastTick = Date()
    private var strokeClock: Double = 0
    private var milestoneClock: Double = 0
    private var autosaveClock: Double = 0
    private var started = false
    /// Silences haptics while the offline catch-up replays, so returning to the app
    /// does not fire a burst of taps for things that happened hours ago.
    private var replayingTimeAway = false

    /// Time constant of the hand-earnings estimate, in seconds.
    private let handRateTau: Double = 30.0

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        load()
        applyTimeAway()
        lastTick = Date()
        let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        // .common so the furnace keeps burning while a list is being scrolled.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
        started = false
    }

    /// Called ONLY from `.background`. `.inactive` fires on the way into the background
    /// and again on the way out, so stamping the clock there would zero every offline
    /// credit the moment the player came back.
    func enterBackground() {
        save.lastActive = Date().timeIntervalSince1970
        pumping = false
        persist()
    }

    func returnToForeground() {
        applyTimeAway()
        lastTick = Date()
    }

    // MARK: - Derived numbers

    func level(_ upgrade: VitremberUpgrade) -> Int { save.level(upgrade) }

    var benchCount: Int { 1 + level(.extraBench) }

    var decayPerSecond: Double { VitremberTuning.decay(lining: level(.lining)) }
    var strokeHeat: Double { VitremberTuning.strokeHeat(governor: level(.governor)) }

    func band(for vessel: VesselKind) -> VitremberBand {
        let width = vessel.baseBandWidth * VitremberTuning.bandScale(marver: level(.marver))
        return VitremberBand(low: vessel.targetTemperature - width / 2,
                        high: vessel.targetTemperature + width / 2,
                        coreFraction: VitremberTuning.coreFraction(gaffersEye: level(.gaffersEye)))
    }

    func band(bench: Int) -> VitremberBand? {
        guard bench < save.benchPieces.count, let piece = save.benchPieces[bench] else { return nil }
        return band(for: VesselCatalog.kind(piece.vesselID))
    }

    var priceMultiplier: Double {
        VitremberTuning.standingMultiplier(level(.standing)) * VitremberTuning.hallmarkMultiplier(save.hallmarks)
    }

    func salePrice(_ vessel: VesselKind, _ grade: GlassGrade) -> Double {
        vessel.basePrice * grade.priceFactor * priceMultiplier
    }

    func isUnlocked(_ vessel: VesselKind) -> Bool {
        save.allTimeEarnings >= vessel.unlockLifetime
    }

    var unlockedVessels: [VesselKind] { VesselCatalog.all.filter { isUnlocked($0) } }

    /// Apprentices always take the finest vessel the shop has unlocked; because coins
    /// per second rises with every tier, that is always their best option, so there is
    /// no hidden trap in leaving them alone.
    var apprenticeVessel: VesselKind { unlockedVessels.last ?? VesselCatalog.all[0] }

    var apprenticeCount: Int { level(.apprentice) }

    /// Finished apprentice pieces per second.
    var apprenticePieceRate: Double {
        guard apprenticeCount > 0 else { return 0 }
        let speed = VitremberTuning.apprenticeSpeed(training: level(.training))
        return Double(apprenticeCount) * speed / apprenticeVessel.workSeconds
    }

    /// Coins per second the apprentices bring in. Exact, not smoothed.
    var idleRate: Double {
        apprenticePieceRate * salePrice(apprenticeVessel, VitremberTuning.apprenticeGrade)
    }

    var offlineCapSeconds: Double { VitremberTuning.offlineCapSeconds(fuelStore: level(.fuelStore)) }

    var lehrBuilt: Bool { level(.lehr) > 0 }

    /// The bar this run has to clear. It rises with the Hallmarks already held.
    var relightBar: Double { VitremberTuning.relightThreshold(hallmarks: save.hallmarks) }

    var pendingHallmarks: Int {
        VitremberTuning.hallmarksFor(lifetime: save.runEarnings,
                                masterworks: save.masterworksThisRun,
                                hallmarks: save.hallmarks)
    }

    var canRelight: Bool { save.runEarnings >= relightBar }

    var rankTitle: String { StandingOrders.rank(for: save.hallmarks) }

    func cost(_ upgrade: VitremberUpgrade) -> Double {
        upgrade.cost(atLevel: level(upgrade))
    }

    func canAfford(_ upgrade: VitremberUpgrade) -> Bool {
        level(upgrade) < upgrade.maxLevel && save.coins >= cost(upgrade)
    }

    // MARK: - Player actions

    func beginPump() {
        guard !pumping else { return }
        pumping = true
        // The first stroke lands immediately so a tap always does something.
        stroke()
    }

    func endPump() {
        pumping = false
    }

    private func stroke() {
        strokeClock = 0
        save.temperature = min(save.temperature + strokeHeat, VesselCatalog.gaugeCeiling)
        push(VitremberFloater(text: "+" + VitremberFormat.degrees(strokeHeat), kind: .heat, lane: -1,
                         life: 0.75, span: 0.75))
        tap(.light)
    }

    func selectVessel(bench: Int, vesselID: Int) {
        guard bench >= 0, bench < save.benchVessel.count else { return }
        guard isUnlocked(VesselCatalog.kind(vesselID)) else { return }
        save.benchVessel[bench] = vesselID
        // Swapping the plan on an empty bench is free; a loaded bench keeps its piece.
    }

    @discardableResult
    func gather(bench: Int) -> Bool {
        guard bench >= 0, bench < benchCount, bench < save.benchPieces.count else { return false }
        guard save.benchPieces[bench] == nil else { return false }
        let vesselID = min(max(save.benchVessel[bench], 0), VesselCatalog.all.count - 1)
        let vessel = VesselCatalog.kind(vesselID)
        guard isUnlocked(vessel) else { return false }
        let fee = VesselCatalog.gatherCost(vessel)
        guard save.coins >= fee else { return false }
        save.coins -= fee
        save.benchPieces[bench] = BenchPiece(vesselID: vesselID)
        tap(.medium)
        return true
    }

    func discard(bench: Int) {
        guard bench >= 0, bench < save.benchPieces.count, save.benchPieces[bench] != nil else { return }
        save.benchPieces[bench] = nil
        push(VitremberFloater(text: "Returned to the pot", kind: .note, lane: bench, life: 1.2, span: 1.2))
    }

    @discardableResult
    func buy(_ upgrade: VitremberUpgrade) -> Bool {
        let current = level(upgrade)
        guard current < upgrade.maxLevel else { return false }
        let price = upgrade.cost(atLevel: current)
        guard save.coins >= price else { return false }
        save.coins -= price
        save.setLevel(upgrade, current + 1)
        if upgrade == .extraBench {
            // Make sure the new bench has a legal plan on it.
            let highest = apprenticeVessel.id
            let index = current + 1
            if index < save.benchVessel.count, !isUnlocked(VesselCatalog.kind(save.benchVessel[index])) {
                save.benchVessel[index] = highest
            }
        }
        tap(.medium)
        checkMilestones()
        persist()
        return true
    }

    /// Bank the furnace, take the Hallmarks, start the shop again.
    func relight() {
        guard canRelight else { return }
        let awarded = pendingHallmarks
        var fresh = VitremberSave()

        // Carried across the relight: the meta currency, the collection, the history.
        fresh.hallmarks = save.hallmarks + awarded
        fresh.relights = save.relights + 1
        fresh.allTimeEarnings = save.allTimeEarnings
        fresh.handEarnings = save.handEarnings
        fresh.apprenticeEarnings = save.apprenticeEarnings
        fresh.records = save.records
        fresh.masterworksAllTime = save.masterworksAllTime
        fresh.piecesFinished = save.piecesFinished
        fresh.piecesCracked = save.piecesCracked
        fresh.piecesSalvaged = save.piecesSalvaged
        fresh.bestSinglePrice = save.bestSinglePrice
        fresh.milestonesDone = save.milestonesDone
        fresh.briefed = save.briefed
        fresh.autoGather = save.autoGather
        fresh.haptics = save.haptics
        fresh.lastActive = Date().timeIntervalSince1970

        // Standing orders — the permanent perks the Hallmarks have bought.
        for (upgrade, startLevel) in StandingOrders.startingLevels(hallmarks: fresh.hallmarks) {
            fresh.setLevel(upgrade, startLevel)
        }

        save = fresh
        // Vessel unlocks survive the relight, so put the finest one back on the benches
        // instead of dropping the player back to beads.
        let resume = apprenticeVessel.id
        save.benchVessel = [resume, resume, resume]
        floaters.removeAll()
        handRate = 0
        pumping = false
        push(VitremberFloater(text: "Furnace relit \u{00B7} +\(awarded) Hallmark" + (awarded == 1 ? "" : "s"),
                         kind: .note, lane: -1, life: 2.6, span: 2.6))
        tap(.heavy)
        checkMilestones()
        persist()
    }

    /// Wipe everything, including Hallmarks. Only reachable from Settings behind a confirm.
    func eraseEverything() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        save = VitremberSave()
        floaters.removeAll()
        handRate = 0
        pumping = false
        persist()
    }

    // MARK: - Simulation

    private func step() {
        let now = Date()
        var dt = now.timeIntervalSince(lastTick)
        lastTick = now
        // A backgrounded app can hand back a huge delta; offline credit is handled
        // separately, so clamp the live step.
        dt = min(max(dt, 0), 0.5)
        guard dt > 0 else { return }
        advance(dt)
    }

    private func advance(_ dt: Double) {
        // Treadle: holding repeats strokes at a fixed cadence, so hammering the button
        // faster than the cadence buys nothing. The skill is knowing when to stop.
        if pumping {
            strokeClock += dt
            if strokeClock >= VitremberTuning.strokeCooldown { stroke() }
        }

        // The furnace always sheds heat.
        if save.temperature > VitremberTuning.idleFloor {
            save.temperature = max(VitremberTuning.idleFloor, save.temperature - decayPerSecond * dt)
        }

        advanceBenches(dt)
        advanceApprentices(dt)
        advanceLehr(dt)

        // Rolling estimate of hand income: sales push it up, time bleeds it down.
        handRate = max(0, handRate - handRate * dt / handRateTau)

        // Floaters.
        if !floaters.isEmpty {
            for index in floaters.indices { floaters[index].life -= dt }
            floaters.removeAll { $0.life <= 0 }
        }

        milestoneClock += dt
        if milestoneClock >= 0.5 {
            milestoneClock = 0
            checkMilestones()
        }

        autosaveClock += dt
        if autosaveClock >= 12 {
            autosaveClock = 0
            persist()
        }
    }

    private func advanceBenches(_ dt: Double) {
        let count = min(benchCount, save.benchPieces.count)
        for index in 0..<count {
            guard let existing = save.benchPieces[index] else {
                autoReload(bench: index)
                continue
            }
            var piece = existing
            let vessel = VesselCatalog.kind(piece.vesselID)
            let window = band(for: vessel)
            let temperature = save.temperature

            if temperature < window.low {
                piece.chill += dt / VitremberTuning.crackSeconds
                if piece.chill >= 1 {
                    crack(bench: index, piece: piece)
                    continue
                }
            } else {
                // Back in (or above) the window: the piece recovers from the cold.
                piece.chill = max(0, piece.chill - dt * VitremberTuning.chillRecoveryRate / VitremberTuning.crackSeconds)

                if temperature > window.high {
                    // Overheating never advances the piece and never ends it early. It
                    // only costs grade. Making a ruined piece finish IMMEDIATELY would
                    // mean a deliberate overheat paid better per second than honest
                    // work on the long vessels — failure must never out-earn success.
                    piece.slump = min(piece.slump + dt / VitremberTuning.slumpSeconds,
                                      VitremberTuning.slumpCollapse)
                } else {
                    let credit = window.contains(core: temperature)
                        ? VitremberTuning.coreCredit : VitremberTuning.bandCredit
                    piece.qualityCredit += credit * dt
                    piece.progress += dt / vessel.workSeconds
                    if piece.progress >= 1 {
                        finish(bench: index, piece: piece)
                        continue
                    }
                }
            }
            save.benchPieces[index] = piece
        }
    }

    /// Reload an empty bench, but only while the shop is plainly still being worked —
    /// the furnace must be within a stroke or two of the window. Once it has cooled
    /// past that, gathering stops on its own instead of quietly spending coins.
    private func autoReload(bench: Int) {
        guard save.autoGather else { return }
        let vesselID = min(max(save.benchVessel[bench], 0), VesselCatalog.all.count - 1)
        let vessel = VesselCatalog.kind(vesselID)
        guard isUnlocked(vessel) else { return }
        let window = band(for: vessel)
        guard save.temperature >= window.low - strokeHeat * 2 else { return }
        gather(bench: bench)
    }

    private func finish(bench: Int, piece: BenchPiece) {
        let vessel = VesselCatalog.kind(piece.vesselID)
        let precision = min(1.0, piece.qualityCredit / max(vessel.workSeconds, 0.001))
        var grade = GlassGrade.from(precision: precision)
        let deformed = piece.slump >= 1

        // Every whole unit of slump costs one grade.
        let cap = 3 - Int(piece.slump.rounded(.down))
        if cap < grade.rawValue {
            grade = GlassGrade(rawValue: max(0, cap)) ?? .flawed
        }

        let payout = salePrice(vessel, grade)
        credit(payout, fromHand: true)
        save.bestSinglePrice = max(save.bestSinglePrice, payout)
        save.piecesFinished += 1
        if grade == .masterwork {
            save.masterworksThisRun += 1
            save.masterworksAllTime += 1
        }

        if piece.vesselID < save.records.count {
            save.records[piece.vesselID].byGrade[grade.rawValue] += 1
            save.records[piece.vesselID].bestPrecision =
                max(save.records[piece.vesselID].bestPrecision, precision)
            if deformed { save.records[piece.vesselID].slumped += 1 }
        }

        save.benchPieces[bench] = nil
        let label = deformed
            ? "Slumped \u{00B7} \(vessel.name)  +\(VitremberFormat.coins(payout))"
            : "\(grade.title) \(vessel.name)  +\(VitremberFormat.coins(payout))"
        push(VitremberFloater(text: label, kind: .sale, lane: bench, life: 1.7, span: 1.7))
        tap(grade == .masterwork ? .heavy : .light)
    }

    private func crack(bench: Int, piece: BenchPiece) {
        let vessel = VesselCatalog.kind(piece.vesselID)
        save.benchPieces[bench] = nil
        save.piecesCracked += 1
        if piece.vesselID < save.records.count { save.records[piece.vesselID].cracked += 1 }

        if lehrBuilt {
            let item = LehrItem(id: save.lehrNextID,
                                vesselID: piece.vesselID,
                                remaining: VitremberTuning.lehrSeconds(level: level(.lehr)),
                                progress: min(max(piece.progress, 0), 1))
            save.lehrNextID += 1
            save.lehrQueue.append(item)
            push(VitremberFloater(text: "Cracked \u{00B7} \(vessel.name) to the lehr",
                             kind: .crack, lane: bench, life: 1.8, span: 1.8))
        } else {
            push(VitremberFloater(text: "Cracked \u{00B7} \(vessel.name) lost",
                             kind: .crack, lane: bench, life: 1.8, span: 1.8))
        }
        tap(.heavy)
    }

    private func advanceApprentices(_ dt: Double) {
        guard apprenticeCount > 0 else { return }
        let vessel = apprenticeVessel
        save.apprenticeProgress += apprenticePieceRate * dt
        guard save.apprenticeProgress >= 1 else { return }
        let finished = Int(save.apprenticeProgress.rounded(.down))
        save.apprenticeProgress -= Double(finished)
        let unit = salePrice(vessel, VitremberTuning.apprenticeGrade)
        credit(unit * Double(finished), fromHand: false)
        save.piecesFinished += finished
        if vessel.id < save.records.count {
            save.records[vessel.id].byGrade[VitremberTuning.apprenticeGrade.rawValue] += finished
        }
    }

    private func advanceLehr(_ dt: Double) {
        guard !save.lehrQueue.isEmpty else { return }
        let salvage = VitremberTuning.lehrSalvage(level: level(.lehr))
        var payout: Double = 0
        var recovered = 0
        var remaining: [LehrItem] = []
        remaining.reserveCapacity(save.lehrQueue.count)
        for var item in save.lehrQueue {
            item.remaining -= dt
            if item.remaining <= 0 {
                let vessel = VesselCatalog.kind(item.vesselID)
                // Proportional to the work that was already in the piece.
                payout += vessel.basePrice * salvage * item.progress * priceMultiplier
                recovered += 1
            } else {
                remaining.append(item)
            }
        }
        if recovered > 0 {
            save.lehrQueue = remaining
            save.piecesSalvaged += recovered
            credit(payout, fromHand: false)
            push(VitremberFloater(text: "Lehr \u{00B7} \(recovered) salvaged  +\(VitremberFormat.coins(payout))",
                             kind: .salvage, lane: -1, life: 1.6, span: 1.6))
        } else {
            save.lehrQueue = remaining
        }
    }

    private func credit(_ amount: Double, fromHand: Bool) {
        guard amount > 0, amount.isFinite else { return }
        save.coins += amount
        save.runEarnings += amount
        save.allTimeEarnings += amount
        if fromHand {
            save.handEarnings += amount
            handRate += amount / handRateTau
        } else {
            save.apprenticeEarnings += amount
        }
    }

    // MARK: - Time away

    private func applyTimeAway() {
        let now = Date().timeIntervalSince1970
        let away = max(0, now - save.lastActive)
        save.lastActive = now
        guard away > 2 else { return }
        replayingTimeAway = true
        defer { replayingTimeAway = false }

        // 1. Apprentices worked, up to the banked fuel.
        let credited = min(away, offlineCapSeconds)
        let vessel = apprenticeVessel
        var coins: Double = 0
        var pieces = 0
        if apprenticeCount > 0 {
            let produced = apprenticePieceRate * credited + save.apprenticeProgress
            pieces = Int(produced.rounded(.down))
            save.apprenticeProgress = produced - Double(pieces)
            if pieces > 0 {
                coins = Double(pieces) * salePrice(vessel, VitremberTuning.apprenticeGrade)
                credit(coins, fromHand: false)
                save.piecesFinished += pieces
                if vessel.id < save.records.count {
                    save.records[vessel.id].byGrade[VitremberTuning.apprenticeGrade.rawValue] += pieces
                }
            }
        }

        // 2. The furnace cooled the whole time — no cap on that.
        save.temperature = max(VitremberTuning.idleFloor, save.temperature - decayPerSecond * away)

        // 3. Anything left on your own benches went cold.
        var cracked = 0
        let benches = min(benchCount, save.benchPieces.count)
        for index in 0..<benches {
            guard var piece = save.benchPieces[index] else { continue }
            let window = band(for: VesselCatalog.kind(piece.vesselID))
            guard save.temperature < window.low else { continue }
            piece.chill += min(away, VitremberTuning.crackSeconds * 4) / VitremberTuning.crackSeconds
            if piece.chill >= 1 {
                crack(bench: index, piece: piece)
                cracked += 1
            } else {
                save.benchPieces[index] = piece
            }
        }
        // The crack notices belong to the closed shop, not to this moment on screen.
        floaters.removeAll()

        // 4. The lehr kept cooling its queue.
        if !save.lehrQueue.isEmpty {
            advanceLehr(away)
        }

        if away > 60 && (coins > 0 || cracked > 0) {
            apprenticeLog = ApprenticeLog(away: away,
                                          credited: credited,
                                          coins: coins,
                                          pieces: pieces,
                                          vesselName: vessel.name,
                                          cracked: cracked,
                                          capped: away > offlineCapSeconds)
        }
        checkMilestones()
    }

    // MARK: - Milestones

    private func checkMilestones() {
        var done = Set(save.milestonesDone)
        var reward: Double = 0
        var newest: String?
        for milestone in MilestoneCatalog.all where !done.contains(milestone.id) {
            if milestone.test(save) {
                done.insert(milestone.id)
                reward += milestone.reward
                newest = milestone.title
            }
        }
        guard let title = newest else { return }
        save.milestonesDone = done.sorted()
        if reward > 0 { credit(reward, fromHand: false) }
        push(VitremberFloater(text: "Record set \u{00B7} \(title)  +\(VitremberFormat.coins(reward))",
                         kind: .note, lane: -1, life: 2.4, span: 2.4))
    }

    func isMilestoneDone(_ milestone: VitremberMilestone) -> Bool {
        save.milestonesDone.contains(milestone.id)
    }

    // MARK: - Floaters & feedback

    private func push(_ floater: VitremberFloater) {
        // Heat notes are frequent; keep only the newest one so they never stack up.
        if floater.kind == .heat {
            floaters.removeAll { $0.kind == .heat }
        }
        floaters.append(floater)
        if floaters.count > 7 { floaters.removeFirst(floaters.count - 7) }
    }

    private func tap(_ strength: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard save.haptics, !replayingTimeAway else { return }
        UIImpactFeedbackGenerator(style: strength).impactOccurred()
    }

    // MARK: - Storage

    func persist() {
        guard let data = try? JSONEncoder().encode(save) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode(VitremberSave.self, from: data) else { return }
        save = decoded
        // A save written by an older build may be short a bench slot or a record.
        while save.benchVessel.count < 3 { save.benchVessel.append(0) }
        while save.benchPieces.count < 3 { save.benchPieces.append(nil) }
        while save.records.count < VesselCatalog.all.count { save.records.append(VesselRecord()) }
    }
}

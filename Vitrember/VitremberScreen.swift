import SwiftUI

/// The hot shop. This is the only screen with a timing-critical control on it, and the
/// treadle is deliberately kept OUT of every scroll view: a `ScrollView` delays touches
/// by around 150 ms and cancels them on the slightest drift, which would make a held
/// control feel broken.
struct VitremberScreen: View {
    @ObservedObject var store: VitremberStore
    let metrics: VitremberMetrics
    let present: (VitremberSheet) -> Void

    private var hearthHeight: CGFloat {
        if metrics.isTiny { return 74 }
        if metrics.isShort { return 88 }
        return 124
    }

    private var scaleHeight: CGFloat { metrics.isShort ? 40 : 46 }
    private var treadleHeight: CGFloat { metrics.isTiny ? 46 : (metrics.isShort ? 52 : 58) }

    /// Working windows for every loaded bench, drawn onto the one shared scale.
    private var gaugeBands: [GaugeBand] {
        var result: [GaugeBand] = []
        for index in 0..<min(store.benchCount, store.save.benchPieces.count) {
            guard let piece = store.save.benchPieces[index] else { continue }
            let vessel = VesselCatalog.kind(piece.vesselID)
            result.append(GaugeBand(id: index,
                                    band: store.band(for: vessel),
                                    tint: benchTint(index),
                                    label: vessel.name))
        }
        return result
    }

    private func benchTint(_ index: Int) -> Color {
        switch index {
        case 0: return VitremberPalette.molten
        case 1: return VitremberPalette.seaGlass
        default: return VitremberPalette.fine
        }
    }

    var body: some View {
        Group {
            if metrics.splitLayout {
                HStack(alignment: .top, spacing: metrics.gutter) {
                    furnaceColumn(width: (metrics.size.width - metrics.gutter * 3) * 0.46)
                    benchColumn(width: (metrics.size.width - metrics.gutter * 3) * 0.54)
                }
                .padding(.horizontal, metrics.gutter)
                .padding(.top, 8)
            } else {
                VStack(spacing: metrics.isShort ? 8 : 11) {
                    furnaceColumn(width: metrics.innerWidth)
                    benchColumn(width: metrics.innerWidth)
                }
                .frame(width: metrics.contentWidth)
                .padding(.horizontal, metrics.gutter)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - The furnace half

    private func furnaceColumn(width: CGFloat) -> some View {
        VStack(spacing: metrics.isShort ? 7 : 10) {

            // Temperature readout.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(VitremberFormat.degrees(store.save.temperature))
                    .font(VitremberType.readout(metrics.isShort ? 26 : 31, .bold))
                    .foregroundColor(VitremberPalette.heatTint(store.save.temperature,
                                                          band: store.band(bench: firstLoadedBench ?? 0)))
                Text(statusLine)
                    .font(VitremberType.body(metrics.bodySize - 1, .medium))
                    .foregroundColor(VitremberPalette.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\u{2212}" + VitremberFormat.degrees(store.decayPerSecond) + "/s")
                    .font(VitremberType.readout(10, .medium))
                    .foregroundColor(VitremberPalette.chill)
            }
            .frame(width: width, alignment: .leading)

            // The pyrometer. Explicit width and height from the parent — the scale never
            // asks a drawing closure how large it is.
            HeatScale(temperature: store.save.temperature,
                      bands: gaugeBands,
                      width: width,
                      height: scaleHeight)

            // The furnace, with the floaters rising off it.
            ZStack {
                FurnaceHearth(glow: glowLevel,
                              width: min(width, hearthHeight * 2.1),
                              height: hearthHeight,
                              pumping: store.pumping)
                FloaterLane(floaters: store.floaters.filter { $0.lane < 0 }, width: width)
            }
            .frame(width: width, height: hearthHeight)

            TreadleControl(pumping: store.pumping,
                           width: width,
                           height: treadleHeight,
                           onPress: { store.beginPump() },
                           onRelease: { store.endPump() })
        }
        .frame(width: width)
    }

    private var glowLevel: Double {
        let span = VesselCatalog.gaugeCeiling - VesselCatalog.gaugeFloor
        return (store.save.temperature - VesselCatalog.gaugeFloor) / span
    }

    private var statusLine: String {
        guard let band = store.band(bench: firstLoadedBench ?? 0) else {
            return "No piece on the bench."
        }
        let t = store.save.temperature
        if t < band.low { return "Too cold \u{2014} the piece is stiffening." }
        if t > band.high { return "Too hot \u{2014} the piece is slumping." }
        if band.contains(core: t) { return "In the core. This is Masterwork heat." }
        return "In the window, off the core."
    }

    private var firstLoadedBench: Int? {
        for index in 0..<min(store.benchCount, store.save.benchPieces.count)
        where store.save.benchPieces[index] != nil {
            return index
        }
        return nil
    }

    // MARK: - The bench half

    private func benchColumn(width: CGFloat) -> some View {
        VStack(spacing: 7) {
            // The benches scroll; the treadle above them does not.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(0..<max(store.benchCount, 1), id: \.self) { index in
                        BenchCard(store: store,
                                  bench: index,
                                  tint: benchTint(index),
                                  width: width,
                                  metrics: metrics,
                                  present: present)
                    }
                    if store.benchCount < 3 {
                        lockedBenchHint(width: width)
                    }
                }
                .padding(.bottom, 6)
                .frame(width: width)
            }
            // A flexible child in a no-scroll parent collapses to nothing on a short
            // screen, so it gets a floor as well as a ceiling.
            .frame(minWidth: width, maxWidth: width,
                   minHeight: metrics.isTiny ? 104 : (metrics.isShort ? 132 : 150),
                   maxHeight: .infinity, alignment: .top)

            ApprenticeStrip(store: store, width: width, metrics: metrics)
        }
        .frame(width: width)
    }

    private func lockedBenchHint(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            LockGlyph()
                .fill(VitremberPalette.faint)
                .frame(width: 14, height: 14)
            Text(store.benchCount == 1
                 ? "A second bench is fitted from the Bench tab."
                 : "A third bench is fitted from the Bench tab.")
                .font(VitremberType.body(11))
                .foregroundColor(VitremberPalette.faint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(VitremberPalette.seam.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

/// One bench: the piece on it, how far along it is, and how well it is being held.
///
/// Every value the card draws with is passed in as a plain number. Handing the card a
/// reference to the model instead would leave its identity unchanged as the piece heats
/// and cools, and SwiftUI would skip the redraw entirely.
struct BenchCard: View {
    @ObservedObject var store: VitremberStore
    let bench: Int
    let tint: Color
    let width: CGFloat
    let metrics: VitremberMetrics
    let present: (VitremberSheet) -> Void

    private var piece: BenchPiece? {
        bench < store.save.benchPieces.count ? store.save.benchPieces[bench] : nil
    }

    private var plannedVessel: VesselKind {
        VesselCatalog.kind(bench < store.save.benchVessel.count ? store.save.benchVessel[bench] : 0)
    }

    private var innerWidth: CGFloat {
        // Every horizontal inset between the card's own width and this child has to be
        // subtracted, not only the outermost one, or the content runs off the edge.
        max(width - 12 * 2 - 52 - 10, 60)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {

            // The piece, drawn at the heat it is actually sitting at.
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VitremberPalette.night.opacity(0.5))
                VesselArtView(vesselID: (piece?.vesselID ?? plannedVessel.id),
                              heat: pieceHeat,
                              tint: pieceTint,
                              lineWidth: 1.4)
                    .padding(7)
                    .opacity(piece == nil ? 0.30 : 1.0)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(piece == nil ? plannedVessel.name : VesselCatalog.kind(piece!.vesselID).name)
                        .font(VitremberType.body(metrics.bodySize, .semibold))
                        .foregroundColor(VitremberPalette.ivory)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let piece = piece {
                        Text(gradeCaption(piece))
                            .font(VitremberType.label(9.5))
                            .kerning(0.7)
                            .foregroundColor(GradePip.colour(projectedGrade(piece)))
                    } else {
                        Text("EMPTY")
                            .font(VitremberType.label(9.5))
                            .kerning(0.7)
                            .foregroundColor(VitremberPalette.faint)
                    }
                }

                if let piece = piece {
                    MeterBar(value: piece.progress, width: innerWidth, height: 6, tint: tint)
                    HStack(spacing: 8) {
                        Text(VitremberFormat.percent(piece.progress) + " shaped")
                            .font(VitremberType.readout(10, .medium))
                            .foregroundColor(VitremberPalette.muted)
                        if piece.chill > 0.02 {
                            Text("CRACKING " + VitremberFormat.percent(piece.chill))
                                .font(VitremberType.label(9))
                                .foregroundColor(VitremberPalette.chill)
                        } else if piece.slump > 0.02 {
                            Text("SLUMPED \u{2212}" + String(Int(piece.slump.rounded(.down))) + " grade")
                                .font(VitremberType.label(9))
                                .foregroundColor(VitremberPalette.scorch)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(spacing: 7) {
                        Button(action: { present(.vessels(bench)) }) {
                            HStack(spacing: 5) {
                                Text("CHANGE")
                                    .font(VitremberType.label(10))
                                    .kerning(0.8)
                                CaretGlyph()
                                    .stroke(VitremberPalette.muted, style: StrokeStyle(lineWidth: 1.4,
                                                                                  lineCap: .round,
                                                                                  lineJoin: .round))
                                    .frame(width: 9, height: 7)
                            }
                            .foregroundColor(VitremberPalette.muted)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(VitremberPalette.night.opacity(0.45))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())

                        // A separate sibling button — never nested inside the one above,
                        // because a button inside another button's label never fires.
                        Button(action: { store.gather(bench: bench) }) {
                            Text(gatherTitle)
                                .font(VitremberType.label(10))
                                .kerning(0.8)
                                .foregroundColor(VitremberPalette.night)
                                .padding(.horizontal, 11)
                                .frame(height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(VitremberPalette.molten)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VitremberPalette.plate)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(piece == nil ? VitremberPalette.seam.opacity(0.5) : tint.opacity(0.5),
                        lineWidth: 1)
        )
        .overlay(
            FloaterLane(floaters: store.floaters.filter { $0.lane == bench }, width: width)
        )
    }

    private var gatherTitle: String {
        let fee = VesselCatalog.gatherCost(plannedVessel)
        return fee <= 0 ? "GATHER" : "GATHER \u{00B7} " + VitremberFormat.coins(fee)
    }

    private var pieceHeat: Double {
        guard let piece = piece else { return 0 }
        let band = store.band(for: VesselCatalog.kind(piece.vesselID))
        return band.position(store.save.temperature)
    }

    private var pieceTint: Color {
        guard let piece = piece else { return VitremberPalette.seaGlassDim }
        return VitremberPalette.heatTint(store.save.temperature,
                                    band: store.band(for: VesselCatalog.kind(piece.vesselID)))
    }

    private func projectedGrade(_ piece: BenchPiece) -> GlassGrade {
        guard piece.progress > 0.02 else { return .sound }
        let vessel = VesselCatalog.kind(piece.vesselID)
        let elapsed = piece.progress * vessel.workSeconds
        let precision = min(1.0, piece.qualityCredit / max(elapsed, 0.001))
        var grade = GlassGrade.from(precision: precision)
        let cap = 3 - Int(piece.slump.rounded(.down))
        if cap < grade.rawValue { grade = GlassGrade(rawValue: max(0, cap)) ?? .flawed }
        return grade
    }

    private func gradeCaption(_ piece: BenchPiece) -> String {
        "ON FOR " + projectedGrade(piece).title.uppercased()
    }
}

/// Rising labels. Every one names what it is — heat notes read as degrees, sales name the
/// piece that earned them. Nothing here is an unlabelled gold number.
struct FloaterLane: View {
    let floaters: [VitremberFloater]
    let width: CGFloat

    var body: some View {
        ZStack {
            ForEach(floaters) { floater in
                let progress = 1.0 - min(max(floater.life / floater.span, 0), 1)
                Text(floater.text)
                    .font(VitremberType.readout(11, .bold))
                    .foregroundColor(colour(floater.kind))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(VitremberPalette.night.opacity(0.78))
                    )
                    .offset(y: -18 - CGFloat(progress) * 24)
                    .opacity(1.0 - progress * progress)
            }
        }
        .frame(width: width)
        .allowsHitTesting(false)
    }

    private func colour(_ kind: VitremberFloater.Kind) -> Color {
        switch kind {
        case .heat: return VitremberPalette.molten
        case .sale: return VitremberPalette.ember
        case .crack: return VitremberPalette.chill
        case .salvage: return VitremberPalette.seaGlass
        case .note: return VitremberPalette.ivory
        }
    }
}

/// A compact line telling you exactly what the unattended half of the shop is doing.
struct ApprenticeStrip: View {
    @ObservedObject var store: VitremberStore
    let width: CGFloat
    let metrics: VitremberMetrics

    var body: some View {
        HStack(spacing: 9) {
            VesselChip(vesselID: store.apprenticeVessel.id, side: 30,
                       tint: VitremberPalette.seaGlassDim)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.apprenticeCount == 0
                     ? "No apprentices yet"
                     : "\(store.apprenticeCount) apprentice\(store.apprenticeCount == 1 ? "" : "s") \u{00B7} \(store.apprenticeVessel.name)")
                    .font(VitremberType.body(11, .semibold))
                    .foregroundColor(VitremberPalette.ivory)
                    .lineLimit(1)
                Text(store.apprenticeCount == 0
                     ? "Hire from the Bench tab \u{2014} they work while the shop is shut."
                     : "Sound grade only \u{00B7} " + VitremberFormat.rate(store.idleRate))
                    .font(VitremberType.body(10))
                    .foregroundColor(VitremberPalette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !store.save.lehrQueue.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("LEHR")
                        .font(VitremberType.label(8.5))
                        .kerning(0.8)
                        .foregroundColor(VitremberPalette.faint)
                    Text("\(store.save.lehrQueue.count)")
                        .font(VitremberType.readout(13, .bold))
                        .foregroundColor(VitremberPalette.seaGlass)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(VitremberPalette.shell)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(VitremberPalette.seam.opacity(0.45), lineWidth: 1)
        )
    }
}

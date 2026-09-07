import SwiftUI

/// The display shelf. Every piece the workshop has ever finished is tallied here, and
/// the tally survives relighting — the collection is the one thing you keep.
struct ShelfScreen: View {
    @ObservedObject var store: VitremberStore
    let metrics: VitremberMetrics

    private var totals: [Int] {
        var out = [0, 0, 0, 0]
        for record in store.save.records {
            for index in 0..<min(4, record.byGrade.count) { out[index] += record.byGrade[index] }
        }
        return out
    }

    var body: some View {
        VitremberScroll(metrics: metrics) {
            ScreenHeading(title: "The Shelf",
                          caption: "What has come off the benches, by grade. Apprentice work counts, and it is always Sound.",
                          metrics: metrics)

            VitremberCard(padding: metrics.cardPadding) {
                VStack(alignment: .leading, spacing: 9) {
                    SectionHeader(text: "Everything made")
                    HStack(spacing: 0) {
                        ForEach(GlassGrade.allCases, id: \.rawValue) { grade in
                            VStack(spacing: 4) {
                                GradePip(grade: grade, side: 11)
                                Text(VitremberFormat.count(totals[grade.rawValue]))
                                    .font(VitremberType.readout(15, .bold))
                                    .foregroundColor(VitremberPalette.ivory)
                                Text(grade.title.uppercased())
                                    .font(VitremberType.label(8))
                                    .kerning(0.6)
                                    .foregroundColor(VitremberPalette.faint)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Rectangle()
                        .fill(VitremberPalette.seam.opacity(0.4))
                        .frame(height: 1)
                    FigureRow(label: "Cracked and lost",
                              value: VitremberFormat.count(store.save.piecesCracked),
                              tint: VitremberPalette.chill, size: metrics.bodySize)
                    FigureRow(label: "Recovered from the lehr",
                              value: VitremberFormat.count(store.save.piecesSalvaged),
                              tint: VitremberPalette.seaGlass, size: metrics.bodySize)
                    FigureRow(label: "Best single sale",
                              value: VitremberFormat.coins(store.save.bestSinglePrice),
                              tint: VitremberPalette.ember, size: metrics.bodySize)
                }
            }

            SectionHeader(text: "By vessel")
                .padding(.top, 4)

            ForEach(VesselCatalog.all) { vessel in
                ShelfRow(store: store, vessel: vessel, metrics: metrics)
            }
        }
    }
}

struct ShelfRow: View {
    @ObservedObject var store: VitremberStore
    let vessel: VesselKind
    let metrics: VitremberMetrics

    private var record: VesselRecord {
        vessel.id < store.save.records.count ? store.save.records[vessel.id] : VesselRecord()
    }

    private var unlocked: Bool { store.isUnlocked(vessel) }

    private var chipTint: Color {
        guard let best = record.bestGrade else { return VitremberPalette.seaGlassDim }
        return GradePip.colour(best)
    }

    var body: some View {
        VitremberCard(padding: metrics.cardPadding) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    VesselChip(vesselID: vessel.id, side: 54,
                               tint: unlocked ? chipTint : VitremberPalette.faint)
                        .opacity(unlocked ? 1 : 0.35)
                    if !unlocked {
                        LockGlyph()
                            .fill(VitremberPalette.muted)
                            .frame(width: 17, height: 17)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(vessel.name)
                            .font(VitremberType.body(metrics.bodySize + 1, .semibold))
                            .foregroundColor(unlocked ? VitremberPalette.ivory : VitremberPalette.muted)
                        Spacer(minLength: 0)
                        if let best = record.bestGrade {
                            HStack(spacing: 4) {
                                GradePip(grade: best, side: 9)
                                Text("BEST " + best.title.uppercased())
                                    .font(VitremberType.label(8.5))
                                    .kerning(0.6)
                                    .foregroundColor(GradePip.colour(best))
                            }
                        }
                    }

                    if unlocked {
                        HStack(spacing: 0) {
                            ForEach(GlassGrade.allCases, id: \.rawValue) { grade in
                                HStack(spacing: 4) {
                                    GradePip(grade: grade, side: 8)
                                    Text(VitremberFormat.count(record.byGrade[grade.rawValue]))
                                        .font(VitremberType.readout(11, .semibold))
                                        .foregroundColor(VitremberPalette.ivory)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        HStack(spacing: 12) {
                            Text("Cracked " + VitremberFormat.count(record.cracked))
                                .font(VitremberType.readout(10))
                                .foregroundColor(VitremberPalette.chill)
                            Text("Slumped " + VitremberFormat.count(record.slumped))
                                .font(VitremberType.readout(10))
                                .foregroundColor(VitremberPalette.scorch)
                            Spacer(minLength: 0)
                            if record.bestPrecision > 0 {
                                Text("Best hold " + VitremberFormat.percent(record.bestPrecision))
                                    .font(VitremberType.readout(10))
                                    .foregroundColor(VitremberPalette.muted)
                            }
                        }
                    } else {
                        Text("Unlocks at " + VitremberFormat.coins(vessel.unlockLifetime) + " earned all-time")
                            .font(VitremberType.body(metrics.bodySize - 1))
                            .foregroundColor(VitremberPalette.faint)
                        MeterBar(value: store.save.allTimeEarnings / max(vessel.unlockLifetime, 1),
                                 width: max(metrics.innerWidth - metrics.cardPadding * 2 - 54 - 11, 60),
                                 height: 5,
                                 tint: VitremberPalette.seaGlassDim)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

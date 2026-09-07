import SwiftUI

/// The shop's reference book: how the work actually behaves, and the numbers for every
/// vessel at the workshop's current fittings.
struct AlmanacScreen: View {
    @ObservedObject var store: VitremberStore
    let metrics: VitremberMetrics

    var body: some View {
        VitremberScroll(metrics: metrics) {
            ScreenHeading(title: "The Almanac",
                          caption: "Everything the trade expects you to know, and the current figures for every vessel.",
                          metrics: metrics)

            note(title: "Heat is not money",
                 body: "The treadle never pays you. It only moves the furnace temperature. Coins arrive when a piece is finished and sold \u{2014} and how much it fetches depends entirely on where the temperature sat while you were working it.")

            note(title: "The working window",
                 body: "Each vessel can only be shaped inside a temperature window. Outside it, the piece makes no progress at all. Bigger, finer vessels have narrower windows and longer working times \u{2014} that is the whole difficulty curve.")

            note(title: "The core",
                 body: "Inside every window is a narrower core stripe, currently \(VitremberFormat.percent(VitremberTuning.coreFraction(gaffersEye: store.level(.gaffersEye)))) of its width. Time spent in the core earns full quality credit; time merely inside the window earns \(String(format: "%.0f", VitremberTuning.bandCredit * 100))%. Grade is decided by that ratio when the piece finishes.")

            gradeTable()

            note(title: "Too cold: the piece cracks",
                 body: "Below the window the piece stiffens. \(String(format: "%.0f", VitremberTuning.crackSeconds)) continuous seconds under the line and it cracks and is gone. An Annealing Lehr recovers cracked pieces, but the salvage is proportional to how far the piece had got \u{2014} it protects work already done, and a crack is always worse than the worst finished piece.")

            note(title: "Too hot: the piece slumps",
                 body: "Above the window nothing progresses at all and the form starts to sag. Every \(String(format: "%.1f", VitremberTuning.slumpSeconds)) seconds over the line costs one whole grade, down to a floor of Flawed. Overheating never ends a piece early either \u{2014} it still has to be finished properly, so there is no version of this that is a shortcut.")

            note(title: "Apprentices buy volume, never mastery",
                 body: "Apprentices hold the window but never the core, so their work is Sound and only ever Sound. They keep going while the shop is shut, up to \(VitremberFormat.duration(store.offlineCapSeconds)) of banked fuel. Your own hands are the only way a Fine or a Masterwork ever leaves this shop.")

            note(title: "More benches, one furnace",
                 body: "A second and third bench let you shape more than one piece at a time, but all of them share ONE temperature. Two vessels whose windows barely overlap are genuinely hard to run together \u{2014} that is the cost of the extra bench, and it is meant to be.")

            note(title: "Relighting",
                 body: "Once the run has earned \(VitremberFormat.coins(store.relightBar)) you may bank the furnace and start again. You keep your Hallmarks, the shelf and the records; everything else goes back to brick. Each Hallmark adds 5% to every sale for good \u{2014} and the bar for the NEXT relight rises with them, so banking the instant you are able is never the shortcut it looks like.")

            SectionHeader(text: "Vessel reference")
                .padding(.top, 6)
            Text("Windows shown at your current Marver Plate and Gaffer's Eye. Prices include Guild Standing and Hallmarks.")
                .font(VitremberType.body(metrics.bodySize - 2))
                .foregroundColor(VitremberPalette.faint)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(VesselCatalog.all) { vessel in
                vesselRow(vessel)
            }
        }
    }

    private func note(title: String, body text: String) -> some View {
        VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(VitremberType.body(metrics.bodySize + 1, .semibold))
                    .foregroundColor(VitremberPalette.ember)
                Text(text)
                    .font(VitremberType.body(metrics.bodySize))
                    .foregroundColor(VitremberPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    private func gradeTable() -> some View {
        VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(text: "The four grades")
                ForEach(GlassGrade.allCases.reversed(), id: \.rawValue) { grade in
                    HStack(spacing: 9) {
                        GradePip(grade: grade, side: 10)
                        Text(grade.title)
                            .font(VitremberType.body(metrics.bodySize, .semibold))
                            .foregroundColor(GradePip.colour(grade))
                            .frame(width: 88, alignment: .leading)
                        Text(requirement(grade))
                            .font(VitremberType.readout(10.5))
                            .foregroundColor(VitremberPalette.muted)
                        Spacer(minLength: 0)
                        Text("\u{00D7}" + String(format: "%.2f", grade.priceFactor))
                            .font(VitremberType.readout(11.5, .bold))
                            .foregroundColor(VitremberPalette.ivory)
                    }
                }
            }
        }
    }

    private func requirement(_ grade: GlassGrade) -> String {
        switch grade {
        case .masterwork: return "93%+ credit"
        case .fine:       return "80% credit"
        case .sound:      return "66% credit"
        case .flawed:     return "below 66%"
        }
    }

    private func vesselRow(_ vessel: VesselKind) -> some View {
        let band = store.band(for: vessel)
        let unlocked = store.isUnlocked(vessel)
        return VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    VesselChip(vesselID: vessel.id, side: 34,
                               tint: unlocked ? VitremberPalette.seaGlass : VitremberPalette.faint)
                        .opacity(unlocked ? 1 : 0.4)
                    Text(vessel.name)
                        .font(VitremberType.body(metrics.bodySize + 1, .semibold))
                        .foregroundColor(unlocked ? VitremberPalette.ivory : VitremberPalette.muted)
                    Spacer(minLength: 0)
                    if !unlocked {
                        LockGlyph()
                            .fill(VitremberPalette.faint)
                            .frame(width: 13, height: 13)
                    }
                }
                Text(vessel.note)
                    .font(VitremberType.body(metrics.bodySize - 1))
                    .foregroundColor(VitremberPalette.faint)
                    .fixedSize(horizontal: false, vertical: true)

                HeatScale(temperature: store.save.temperature,
                          bands: [GaugeBand(id: vessel.id, band: band,
                                            tint: VitremberPalette.molten, label: vessel.name)],
                          width: max(metrics.innerWidth - metrics.cardPadding * 2, 100),
                          height: 34)

                HStack(spacing: 0) {
                    stat("WINDOW", VitremberFormat.degrees(band.low) + "\u{2013}" + VitremberFormat.degrees(band.high))
                    stat("CORE", VitremberFormat.degrees(band.coreHigh - band.coreLow) + " wide")
                    stat("WORK", String(format: "%.0fs", vessel.workSeconds))
                }
                HStack(spacing: 0) {
                    stat("SOUND", VitremberFormat.coins(store.salePrice(vessel, .sound)))
                    stat("MASTERWORK", VitremberFormat.coins(store.salePrice(vessel, .masterwork)))
                    stat("GATHER", VitremberFormat.coins(VesselCatalog.gatherCost(vessel)))
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(VitremberType.label(8))
                .kerning(0.6)
                .foregroundColor(VitremberPalette.faint)
            Text(value)
                .font(VitremberType.readout(11, .semibold))
                .foregroundColor(VitremberPalette.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

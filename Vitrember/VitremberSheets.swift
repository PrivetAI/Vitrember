import SwiftUI

/// Shared chrome for every modal in the app. Sheets are inset from the top by the
/// system, so they need no status-bar handling of their own.
struct SheetFrame<Content: View>: View {
    let title: String
    var onClose: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VitremberPalette.night.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text(title)
                        .font(VitremberType.body(17, .bold))
                        .foregroundColor(VitremberPalette.ivory)
                    Spacer(minLength: 0)
                    if let onClose = onClose {
                        Button(action: onClose) {
                            CloseGlyph()
                                .stroke(VitremberPalette.muted,
                                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                .frame(width: 26, height: 26)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel(Text("Close"))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Rectangle().fill(VitremberPalette.seam.opacity(0.5)).frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 13) {
                        content()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// The first-run explanation. Without it the treadle reads as an ordinary tap button,
/// which is exactly the wrong expectation to set.
struct BriefSheet: View {
    let onDone: () -> Void

    var body: some View {
        SheetFrame(title: "Opening the shop") {
            FurnaceHearth(glow: 0.72, width: 190, height: 108, pumping: false)
                .frame(maxWidth: .infinity, alignment: .center)

            paragraph("This is a glassblowing workshop, and the only thing your finger does is work the bellows.")
            paragraph("The furnace loses heat continuously. Holding the treadle raises it. Glass can only be shaped inside a temperature window \u{2014} and inside that window is a narrower core stripe.")

            bullet(tint: VitremberPalette.chill,
                   title: "Below the window",
                   text: "The piece stiffens and, after five seconds, cracks. It is gone.")
            bullet(tint: VitremberPalette.scorch,
                   title: "Above the window",
                   text: "Nothing progresses at all and the form sags. Every few seconds over the line costs a whole grade, and the piece still has to be finished properly.")
            bullet(tint: VitremberPalette.molten,
                   title: "Inside the window",
                   text: "The piece advances. How much of that time you spend in the core decides whether it sells as Flawed, Sound, Fine or a Masterwork \u{2014} and a Masterwork is worth six times a Sound one.")

            paragraph("Apprentices work unattended, day and night, but they only ever make Sound glass. Volume comes from them. Mastery only ever comes from your hands.")

            PillButton(title: "OPEN THE SHOP", height: 46, action: onDone)
                .padding(.top, 4)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(VitremberType.body(13))
            .foregroundColor(VitremberPalette.muted)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bullet(tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VitremberType.body(12.5, .semibold))
                    .foregroundColor(tint)
                Text(text)
                    .font(VitremberType.body(12))
                    .foregroundColor(VitremberPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// What happened while the shop was shut.
struct ApprenticeLogSheet: View {
    let log: ApprenticeLog?
    let onDone: () -> Void

    var body: some View {
        SheetFrame(title: "The apprentice log") {
            if let log = log {
                Text("The shop was shut for " + VitremberFormat.duration(log.away) + ".")
                    .font(VitremberType.body(13))
                    .foregroundColor(VitremberPalette.muted)

                VitremberCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        FigureRow(label: "Credited work",
                                  value: VitremberFormat.duration(log.credited),
                                  tint: VitremberPalette.seaGlass)
                        FigureRow(label: "Pieces finished",
                                  value: VitremberFormat.count(log.pieces) + " \u{00D7} " + log.vesselName,
                                  tint: VitremberPalette.ivory)
                        FigureRow(label: "Grade",
                                  value: "Sound, as always",
                                  tint: VitremberPalette.sound)
                        Rectangle().fill(VitremberPalette.seam.opacity(0.4)).frame(height: 1)
                        FigureRow(label: "Taken in",
                                  value: VitremberFormat.coins(log.coins),
                                  tint: VitremberPalette.ember, size: 15)
                    }
                }

                if log.capped {
                    Text("The banked fuel ran out before you came back. A larger Fuel Store keeps them working longer.")
                        .font(VitremberType.body(12))
                        .foregroundColor(VitremberPalette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if log.cracked > 0 {
                    Text("\(log.cracked) piece\(log.cracked == 1 ? "" : "s") left on your own bench went cold and cracked.")
                        .font(VitremberType.body(12))
                        .foregroundColor(VitremberPalette.chill)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Nothing to report.")
                    .font(VitremberType.body(13))
                    .foregroundColor(VitremberPalette.muted)
            }

            PillButton(title: "BACK TO THE BENCH", height: 44, action: onDone)
                .padding(.top, 4)
        }
    }
}

/// Confirming a relight, with the consequences spelled out.
struct RelightSheet: View {
    @ObservedObject var store: VitremberStore
    let onChoice: (Bool) -> Void

    var body: some View {
        SheetFrame(title: "Relight the furnace", onClose: { onChoice(false) }) {
            Text("The furnace is banked and the shop reopens from cold.")
                .font(VitremberType.body(13))
                .foregroundColor(VitremberPalette.muted)

            VitremberCard(padding: 14, border: VitremberPalette.ember) {
                VStack(alignment: .leading, spacing: 8) {
                    FigureRow(label: "Earned this run",
                              value: VitremberFormat.coins(store.save.runEarnings))
                    FigureRow(label: "Masterworks this run",
                              value: VitremberFormat.count(store.save.masterworksThisRun),
                              tint: VitremberPalette.masterwork)
                    Rectangle().fill(VitremberPalette.seam.opacity(0.4)).frame(height: 1)
                    FigureRow(label: "Hallmarks awarded",
                              value: "+\(store.pendingHallmarks)",
                              tint: VitremberPalette.ember, size: 16)
                    FigureRow(label: "New sale multiplier",
                              value: "\u{00D7}" + String(format: "%.2f",
                                        VitremberTuning.hallmarkMultiplier(store.save.hallmarks + store.pendingHallmarks)),
                              tint: VitremberPalette.seaGlass)
                }
            }

            keepList(title: "You keep",
                     tint: VitremberPalette.seaGlass,
                     items: ["Every Hallmark, and the sale multiplier they carry",
                             "The shelf and every record on it",
                             "Shop records and standing orders"])

            keepList(title: "You lose",
                     tint: VitremberPalette.scorch,
                     items: ["All coins in hand",
                             "Every fitting on the bench, apart from standing orders",
                             "Apprentices, apart from any retained by a standing order",
                             "Anything still on a bench or in the lehr"])

            PillButton(title: "BANK THE FURNACE", height: 46) { onChoice(true) }
            GhostButton(title: "NOT YET") { onChoice(false) }
        }
    }

    private func keepList(title: String, tint: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionHeader(text: title, tint: tint)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(tint).frame(width: 4, height: 4).padding(.top, 6)
                    Text(item)
                        .font(VitremberType.body(12))
                        .foregroundColor(VitremberPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

/// The destructive reset, behind an explicit confirmation.
struct EraseSheet: View {
    let onChoice: (Bool) -> Void

    var body: some View {
        SheetFrame(title: "Erase all progress", onClose: { onChoice(false) }) {
            Text("This clears the whole workshop from this device: coins, fittings, apprentices, the shelf, every record, and every Hallmark. It cannot be undone, and nothing is stored anywhere else.")
                .font(VitremberType.body(13))
                .foregroundColor(VitremberPalette.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            PillButton(title: "ERASE EVERYTHING", fill: VitremberPalette.scorch,
                       textColor: VitremberPalette.ivory, height: 46) { onChoice(true) }
            GhostButton(title: "KEEP MY WORKSHOP") { onChoice(false) }
        }
    }
}

/// Choosing what to make next on a bench.
struct VesselPickerSheet: View {
    @ObservedObject var store: VitremberStore
    let bench: Int
    let onChoice: (Int?) -> Void

    /// Built as a plain string rather than inline, so the type checker is not asked to
    /// solve a long concatenation inside a view builder.
    private func summary(for vessel: VesselKind) -> String {
        let band = store.band(for: vessel)
        let window = VitremberFormat.degrees(band.low) + "\u{2013}" + VitremberFormat.degrees(band.high)
        let work = String(format: "%.0fs", vessel.workSeconds)
        let sound = VitremberFormat.coins(store.salePrice(vessel, .sound))
        return window + " \u{00B7} " + work + " \u{00B7} " + sound + " sound"
    }

    private func lockedNote(for vessel: VesselKind) -> String {
        "Unlocks at " + VitremberFormat.coins(vessel.unlockLifetime) + " all-time"
    }

    var body: some View {
        SheetFrame(title: "What to make", onClose: { onChoice(nil) }) {
            Text("All benches share ONE furnace temperature. Two vessels whose windows barely overlap are genuinely hard to run side by side.")
                .font(VitremberType.body(12.5))
                .foregroundColor(VitremberPalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(VesselCatalog.all) { vessel in
                let unlocked = store.isUnlocked(vessel)
                let chosen = bench < store.save.benchVessel.count
                    && store.save.benchVessel[bench] == vessel.id
                Button(action: { if unlocked { onChoice(vessel.id) } }) {
                    HStack(spacing: 11) {
                        VesselChip(vesselID: vessel.id, side: 44,
                                   tint: unlocked ? VitremberPalette.seaGlass : VitremberPalette.faint)
                            .opacity(unlocked ? 1 : 0.4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(vessel.name)
                                .font(VitremberType.body(13.5, .semibold))
                                .foregroundColor(unlocked ? VitremberPalette.ivory : VitremberPalette.muted)
                            if unlocked {
                                Text(summary(for: vessel))
                                    .font(VitremberType.readout(10.5))
                                    .foregroundColor(VitremberPalette.muted)
                            } else {
                                Text(lockedNote(for: vessel))
                                    .font(VitremberType.readout(10.5))
                                    .foregroundColor(VitremberPalette.faint)
                            }
                        }
                        Spacer(minLength: 0)
                        if chosen {
                            TickGlyph()
                                .stroke(VitremberPalette.molten,
                                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                                .frame(width: 16, height: 16)
                        } else if !unlocked {
                            LockGlyph()
                                .fill(VitremberPalette.faint)
                                .frame(width: 15, height: 15)
                        }
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VitremberPalette.plate)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(chosen ? VitremberPalette.molten.opacity(0.7)
                                           : VitremberPalette.seam.opacity(0.5), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!unlocked)
            }
        }
    }
}

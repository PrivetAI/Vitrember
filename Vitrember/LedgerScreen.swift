import SwiftUI

/// The books: where the money actually came from, the shop records, relighting, and
/// the settings.
struct LedgerScreen: View {
    @ObservedObject var store: VitremberStore
    let metrics: VitremberMetrics
    let present: (VitremberSheet) -> Void

    private var handShare: Double {
        let total = store.save.handEarnings + store.save.apprenticeEarnings
        return total > 0 ? store.save.handEarnings / total : 0
    }

    var body: some View {
        VitremberScroll(metrics: metrics) {
            ScreenHeading(title: "The Ledger",
                          caption: "Where the money came from, what the shop has on record, and when to bank the furnace.",
                          metrics: metrics)

            incomeCard()
            relightCard()
            milestonesCard()
            settingsCard()
            aboutCard()
        }
    }

    // MARK: - Income

    private func incomeCard() -> some View {
        let barWidth = max(metrics.innerWidth - metrics.cardPadding * 2, 100)
        return VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(text: "Where it came from")

                // The split, drawn so it cannot be misread.
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(VitremberPalette.seaGlassDim)
                        .frame(width: barWidth, height: 10)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(VitremberPalette.ember)
                        .frame(width: max(barWidth * CGFloat(handShare), handShare > 0 ? 10 : 0),
                               height: 10)
                }
                .frame(width: barWidth, height: 10, alignment: .leading)

                HStack(spacing: 14) {
                    legend(colour: VitremberPalette.ember, title: "Your hands",
                           value: VitremberFormat.coins(store.save.handEarnings))
                    legend(colour: VitremberPalette.seaGlassDim, title: "Apprentices",
                           value: VitremberFormat.coins(store.save.apprenticeEarnings))
                }

                Rectangle().fill(VitremberPalette.seam.opacity(0.4)).frame(height: 1)

                FigureRow(label: "Hands, right now",
                          value: VitremberFormat.rate(store.handRate),
                          tint: VitremberPalette.ember, size: metrics.bodySize)
                FigureRow(label: "Apprentices, right now",
                          value: VitremberFormat.rate(store.idleRate),
                          tint: VitremberPalette.seaGlass, size: metrics.bodySize)
                FigureRow(label: "Earned this run",
                          value: VitremberFormat.coins(store.save.runEarnings),
                          size: metrics.bodySize)
                FigureRow(label: "Earned all-time",
                          value: VitremberFormat.coins(store.save.allTimeEarnings),
                          size: metrics.bodySize)
                FigureRow(label: "Pieces finished",
                          value: VitremberFormat.count(store.save.piecesFinished),
                          size: metrics.bodySize)
                FigureRow(label: "Masterworks",
                          value: VitremberFormat.count(store.save.masterworksAllTime),
                          tint: VitremberPalette.masterwork, size: metrics.bodySize)
            }
        }
    }

    private func legend(colour: Color, title: String, value: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(colour)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(VitremberType.body(10))
                    .foregroundColor(VitremberPalette.muted)
                Text(value)
                    .font(VitremberType.readout(11.5, .semibold))
                    .foregroundColor(VitremberPalette.ivory)
            }
        }
    }

    // MARK: - Relight

    private func relightCard() -> some View {
        VitremberCard(padding: metrics.cardPadding,
                 border: store.canRelight ? VitremberPalette.ember : VitremberPalette.seam) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    HallmarkBadge(size: 14, tint: VitremberPalette.ember)
                    Text("Relight the Furnace")
                        .font(VitremberType.body(metrics.bodySize + 2, .semibold))
                        .foregroundColor(VitremberPalette.ivory)
                    Spacer(minLength: 0)
                    Text(store.rankTitle.uppercased())
                        .font(VitremberType.label(9))
                        .kerning(0.8)
                        .foregroundColor(VitremberPalette.seaGlass)
                }

                Text("Bank the furnace and open the shop again from cold. You keep the Hallmarks, the shelf and the records \u{2014} the fittings and the coins go.")
                    .font(VitremberType.body(metrics.bodySize - 1))
                    .foregroundColor(VitremberPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                FigureRow(label: "Hallmarks held",
                          value: String(store.save.hallmarks),
                          tint: VitremberPalette.seaGlass, size: metrics.bodySize)
                FigureRow(label: "Every sale, from them",
                          value: "\u{00D7}" + String(format: "%.2f", VitremberTuning.hallmarkMultiplier(store.save.hallmarks)),
                          tint: VitremberPalette.seaGlass, size: metrics.bodySize)
                FigureRow(label: "Relights so far",
                          value: String(store.save.relights),
                          size: metrics.bodySize)

                if store.canRelight {
                    FigureRow(label: "This relight would pay",
                              value: "+\(store.pendingHallmarks) Hallmark" + (store.pendingHallmarks == 1 ? "" : "s"),
                              tint: VitremberPalette.ember, size: metrics.bodySize)
                    PillButton(title: "RELIGHT THE FURNACE", enabled: true) {
                        present(.relight)
                    }
                } else {
                    let progress = store.save.runEarnings / store.relightBar
                    MeterBar(value: progress,
                             width: max(metrics.innerWidth - metrics.cardPadding * 2, 100),
                             height: 7,
                             tint: VitremberPalette.molten)
                    Text("Earn " + VitremberFormat.coins(store.relightBar) + " in a run to relight \u{00B7} "
                         + VitremberFormat.coins(store.save.runEarnings) + " so far")
                        .font(VitremberType.readout(10.5))
                        .foregroundColor(VitremberPalette.faint)
                }

                Rectangle().fill(VitremberPalette.seam.opacity(0.4)).frame(height: 1)
                SectionHeader(text: "Standing orders")
                ForEach(StandingOrders.all.indices, id: \.self) { index in
                    let order = StandingOrders.all[index]
                    let held = store.save.hallmarks >= order.hallmarks
                    HStack(alignment: .top, spacing: 8) {
                        if held {
                            TickGlyph()
                                .stroke(VitremberPalette.seaGlass,
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                .frame(width: 13, height: 13)
                        } else {
                            LockGlyph()
                                .fill(VitremberPalette.faint)
                                .frame(width: 13, height: 13)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(order.hallmarks) Hallmarks \u{00B7} \(order.title)")
                                .font(VitremberType.body(11, .semibold))
                                .foregroundColor(held ? VitremberPalette.ivory : VitremberPalette.muted)
                            Text(order.detail)
                                .font(VitremberType.body(10.5))
                                .foregroundColor(VitremberPalette.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: - Milestones

    private func milestonesCard() -> some View {
        let done = MilestoneCatalog.all.filter { store.isMilestoneDone($0) }.count
        return VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    SectionHeader(text: "Shop records")
                    Text("\(done)/\(MilestoneCatalog.all.count)")
                        .font(VitremberType.readout(11, .bold))
                        .foregroundColor(VitremberPalette.ember)
                }
                ForEach(MilestoneCatalog.all) { milestone in
                    let complete = store.isMilestoneDone(milestone)
                    HStack(alignment: .top, spacing: 9) {
                        Group {
                            if complete {
                                TickGlyph()
                                    .stroke(VitremberPalette.ember,
                                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            } else {
                                Circle()
                                    .stroke(VitremberPalette.faint.opacity(0.6), lineWidth: 1.4)
                            }
                        }
                        .frame(width: 14, height: 14)
                        .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(milestone.title)
                                .font(VitremberType.body(11.5, .semibold))
                                .foregroundColor(complete ? VitremberPalette.ivory : VitremberPalette.muted)
                            Text(milestone.detail)
                                .font(VitremberType.body(10.5))
                                .foregroundColor(VitremberPalette.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text("+" + VitremberFormat.coins(milestone.reward))
                            .font(VitremberType.readout(10.5, .semibold))
                            .foregroundColor(complete ? VitremberPalette.ember.opacity(0.5) : VitremberPalette.faint)
                    }
                }
            }
        }
    }

    // MARK: - Settings

    private func settingsCard() -> some View {
        VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 11) {
                SectionHeader(text: "Settings")

                toggleRow(title: "Re-gather automatically",
                          detail: "Reload an empty bench while the furnace is still near working heat.",
                          isOn: store.save.autoGather) {
                    store.save.autoGather.toggle()
                    store.persist()
                }

                toggleRow(title: "Haptics",
                          detail: "A small tap on each stroke, sale and crack.",
                          isOn: store.save.haptics) {
                    store.save.haptics.toggle()
                    store.persist()
                }

                Rectangle().fill(VitremberPalette.seam.opacity(0.4)).frame(height: 1)

                Button(action: { present(.privacy) }) {
                    HStack(spacing: 8) {
                        Text("Privacy Policy")
                            .font(VitremberType.body(metrics.bodySize, .medium))
                            .foregroundColor(VitremberPalette.ivory)
                        Spacer(minLength: 0)
                        ChevronGlyph()
                            .stroke(VitremberPalette.muted,
                                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                            .frame(width: 8, height: 12)
                    }
                    .frame(height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                GhostButton(title: "ERASE ALL PROGRESS", tint: VitremberPalette.scorch) {
                    present(.erase)
                }
            }
        }
    }

    private func toggleRow(title: String, detail: String, isOn: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(VitremberType.body(metrics.bodySize, .medium))
                        .foregroundColor(VitremberPalette.ivory)
                    Text(detail)
                        .font(VitremberType.body(10.5))
                        .foregroundColor(VitremberPalette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                // A hand-built switch — no system control anywhere in this app.
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? VitremberPalette.molten : VitremberPalette.night.opacity(0.7))
                        .frame(width: 42, height: 24)
                    Circle()
                        .fill(isOn ? VitremberPalette.night : VitremberPalette.muted)
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 3)
                }
                .frame(width: 42, height: 24)
                .overlay(
                    Capsule().stroke(VitremberPalette.seam.opacity(0.6), lineWidth: 1)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - About

    private func aboutCard() -> some View {
        VitremberCard(padding: metrics.cardPadding) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Vitrember")
                    .font(VitremberType.body(metrics.bodySize + 1, .semibold))
                    .foregroundColor(VitremberPalette.ivory)
                Text("Version 1.0 \u{00B7} English (US)")
                    .font(VitremberType.readout(10.5))
                    .foregroundColor(VitremberPalette.muted)
                Text("Everything is stored on this device. The workshop needs no account and sends nothing anywhere.")
                    .font(VitremberType.body(10.5))
                    .foregroundColor(VitremberPalette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

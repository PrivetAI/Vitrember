import SwiftUI

/// Where the shop is fitted out. Almost nothing here multiplies money — these purchases
/// change the shape of the problem the treadle is solving.
struct BenchScreen: View {
    @ObservedObject var store: VitremberStore
    let metrics: VitremberMetrics

    private let groups = ["The Furnace", "The Shop Floor", "Apprentices", "The Guild"]

    var body: some View {
        VitremberScroll(metrics: metrics) {
            ScreenHeading(title: "The Bench",
                          caption: "Fittings change how the furnace behaves. Only Guild Standing touches the price of a piece, and it stops at five.",
                          metrics: metrics)

            ForEach(groups, id: \.self) { group in
                SectionHeader(text: group)
                    .padding(.top, 4)
                ForEach(VitremberUpgrade.allCases.filter { $0.group == group }) { upgrade in
                    UpgradeRow(store: store, upgrade: upgrade, metrics: metrics)
                }
            }

            SectionHeader(text: "How the numbers move")
                .padding(.top, 6)
            VitremberCard(padding: metrics.cardPadding) {
                VStack(alignment: .leading, spacing: 7) {
                    FigureRow(label: "Furnace heat loss",
                              value: VitremberFormat.degrees(store.decayPerSecond) + "/s",
                              tint: VitremberPalette.chill, size: metrics.bodySize)
                    FigureRow(label: "One treadle stroke",
                              value: "+" + VitremberFormat.degrees(store.strokeHeat),
                              tint: VitremberPalette.molten, size: metrics.bodySize)
                    FigureRow(label: "Held flat out",
                              value: "+" + VitremberFormat.degrees(store.strokeHeat / VitremberTuning.strokeCooldown - store.decayPerSecond) + "/s",
                              tint: VitremberPalette.ember, size: metrics.bodySize)
                    FigureRow(label: "Every sale",
                              value: "\u{00D7}" + String(format: "%.2f", store.priceMultiplier),
                              tint: VitremberPalette.seaGlass, size: metrics.bodySize)
                    Text("Holding the treadle down repeats a stroke every \(String(format: "%.2f", VitremberTuning.strokeCooldown))s. Tapping faster than that adds nothing \u{2014} the skill is knowing when to stop.")
                        .font(VitremberType.body(metrics.bodySize - 2))
                        .foregroundColor(VitremberPalette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }
}

struct UpgradeRow: View {
    @ObservedObject var store: VitremberStore
    let upgrade: VitremberUpgrade
    let metrics: VitremberMetrics
    @State private var expanded = false

    private var level: Int { store.level(upgrade) }
    private var maxed: Bool { level >= upgrade.maxLevel }
    private var price: Double { upgrade.cost(atLevel: level) }
    private var affordable: Bool { !maxed && store.save.coins >= price }

    var body: some View {
        VitremberCard(padding: metrics.cardPadding,
                 tint: VitremberPalette.plate,
                 border: affordable ? VitremberPalette.molten : VitremberPalette.seam) {
            VStack(alignment: .leading, spacing: 9) {

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(upgrade.title)
                                .font(VitremberType.body(metrics.bodySize + 1, .semibold))
                                .foregroundColor(VitremberPalette.ivory)
                            Text(maxed ? "MAX" : "LV \(level)/\(upgrade.maxLevel)")
                                .font(VitremberType.readout(9.5, .bold))
                                .foregroundColor(maxed ? VitremberPalette.ember : VitremberPalette.faint)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(VitremberPalette.night.opacity(0.5))
                                )
                        }
                        Text(upgrade.currentEffect(atLevel: level))
                            .font(VitremberType.readout(10.5, .medium))
                            .foregroundColor(VitremberPalette.seaGlass)
                        if !maxed {
                            Text("Next: " + upgrade.nextEffect(atLevel: level))
                                .font(VitremberType.body(10.5))
                                .foregroundColor(VitremberPalette.muted)
                        }
                    }
                    Spacer(minLength: 4)

                    Button(action: { store.buy(upgrade) }) {
                        VStack(spacing: 1) {
                            if maxed {
                                Text("FITTED")
                                    .font(VitremberType.label(10.5))
                                    .kerning(0.8)
                            } else {
                                Text("FIT")
                                    .font(VitremberType.label(10.5))
                                    .kerning(0.8)
                                Text(VitremberFormat.coins(price))
                                    .font(VitremberType.readout(10, .semibold))
                            }
                        }
                        .foregroundColor(affordable ? VitremberPalette.night : VitremberPalette.faint)
                        .frame(width: 74, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(affordable ? VitremberPalette.molten : VitremberPalette.night.opacity(0.45))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(VitremberPalette.seam.opacity(affordable ? 0 : 0.55), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!affordable)
                }

                // A separate sibling button. Never nested in the one above.
                Button(action: { expanded.toggle() }) {
                    HStack(spacing: 5) {
                        Text(expanded ? "Less" : "What this changes")
                            .font(VitremberType.body(10.5, .medium))
                            .foregroundColor(VitremberPalette.faint)
                        CaretGlyph()
                            .stroke(VitremberPalette.faint,
                                    style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
                            .frame(width: 9, height: 6)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                if expanded {
                    Text(upgrade.blurb)
                        .font(VitremberType.body(metrics.bodySize - 1))
                        .foregroundColor(VitremberPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

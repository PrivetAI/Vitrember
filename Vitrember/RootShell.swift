import SwiftUI

/// Everything presented over the workshop. iOS 15 honours only the LAST `.sheet` attached
/// to a view, so the whole app routes through this one enum and one modifier.
enum VitremberSheet: Identifiable {
    case brief
    case apprentices
    case relight
    case erase
    case privacy
    case vessels(Int)

    var id: String {
        switch self {
        case .brief: return "brief"
        case .apprentices: return "apprentices"
        case .relight: return "relight"
        case .erase: return "erase"
        case .privacy: return "privacy"
        case .vessels(let bench): return "vessels-\(bench)"
        }
    }
}

struct RootShell: View {
    @ObservedObject var store: VitremberStore
    @State private var tab = 0
    @State private var sheet: VitremberSheet?

    var body: some View {
        GeometryReader { proxy in
            let metrics = VitremberMetrics(size: proxy.size)
            ZStack(alignment: .top) {

                VitremberPalette.night
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    VitremberHUD(coins: store.save.coins,
                            handRate: store.handRate,
                            idleRate: store.idleRate,
                            hallmarks: store.save.hallmarks,
                            rank: store.rankTitle,
                            metrics: metrics)

                    Rectangle()
                        .fill(VitremberPalette.seam.opacity(0.5))
                        .frame(height: 1)

                    // One screen at a time. Only the visible screen is in the view tree,
                    // so the 20 Hz furnace tick never redraws four dormant tabs.
                    Group {
                        switch tab {
                        case 0: VitremberScreen(store: store, metrics: metrics, present: present)
                        case 1: BenchScreen(store: store, metrics: metrics)
                        case 2: ShelfScreen(store: store, metrics: metrics)
                        case 3: AlmanacScreen(store: store, metrics: metrics)
                        default: LedgerScreen(store: store, metrics: metrics, present: present)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VitremberTabBar(selection: $tab, metrics: metrics)
                }
                // The content respects the safe area, so nothing scrolls under the clock.

                // LAST sibling in the stack: an opaque band exactly the height of the
                // status bar, pushed up over it. Anything drawn earlier stays beneath it.
                VitremberPalette.night
                    .frame(width: proxy.size.width, height: max(proxy.safeAreaInsets.top, 0))
                    .offset(y: -max(proxy.safeAreaInsets.top, 0))
            }
        }
        .sheet(item: $sheet) { which in
            sheetBody(which)
        }
        .onAppear {
            if !store.save.briefed {
                sheet = .brief
            } else if store.apprenticeLog != nil {
                sheet = .apprentices
            }
        }
        .onChange(of: store.apprenticeLog?.id) { value in
            guard value != nil, sheet == nil, store.save.briefed else { return }
            sheet = .apprentices
        }
    }

    private func present(_ which: VitremberSheet) {
        sheet = which
    }

    @ViewBuilder
    private func sheetBody(_ which: VitremberSheet) -> some View {
        switch which {
        case .brief:
            BriefSheet {
                store.save.briefed = true
                store.persist()
                sheet = nil
                // Swapping one sheet for another in the same runloop turn is unreliable
                // on iOS 15; let the first dismissal finish before presenting the log.
                if store.apprenticeLog != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        if store.apprenticeLog != nil { sheet = .apprentices }
                    }
                }
            }
        case .apprentices:
            ApprenticeLogSheet(log: store.apprenticeLog) {
                store.apprenticeLog = nil
                sheet = nil
            }
        case .relight:
            RelightSheet(store: store) { confirmed in
                if confirmed { store.relight() }
                sheet = nil
            }
        case .erase:
            EraseSheet { confirmed in
                if confirmed { store.eraseEverything() }
                sheet = nil
            }
        case .privacy:
            // No redirect check here — the panel opens the page directly.
            VitremberWebPanel(urlString: VitremberLinks.sourceLink)
                .edgesIgnoringSafeArea(.bottom)
        case .vessels(let bench):
            VesselPickerSheet(store: store, bench: bench) { chosen in
                if let chosen = chosen { store.selectVessel(bench: bench, vesselID: chosen) }
                sheet = nil
            }
        }
    }
}

/// The permanent readout. Hand income and apprentice income are shown SEPARATELY and
/// labelled, so nobody can conclude that pumping the bellows is what pays — it never is.
struct VitremberHUD: View {
    let coins: Double
    let handRate: Double
    let idleRate: Double
    let hallmarks: Int
    let rank: String
    let metrics: VitremberMetrics

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                CoinFigure(amount: coins, size: metrics.isShort ? 18 : 21)
                if hallmarks > 0 {
                    HStack(spacing: 4) {
                        HallmarkBadge(size: 10)
                        Text("\(hallmarks) \u{00B7} \(rank)")
                            .font(VitremberType.readout(10, .medium))
                            .foregroundColor(VitremberPalette.seaGlass)
                    }
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                rateLine(title: "YOUR HANDS", value: handRate, tint: VitremberPalette.ember)
                rateLine(title: "APPRENTICES", value: idleRate, tint: VitremberPalette.seaGlass)
            }
        }
        .padding(.horizontal, metrics.gutter)
        .padding(.vertical, metrics.isShort ? 7 : 10)
        .frame(maxWidth: .infinity)
        .background(VitremberPalette.shell)
    }

    private func rateLine(title: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(VitremberType.label(8.5))
                .kerning(0.9)
                .foregroundColor(VitremberPalette.faint)
            Text(VitremberFormat.rate(value))
                .font(VitremberType.readout(12, .semibold))
                .foregroundColor(tint)
                .frame(minWidth: 54, alignment: .trailing)
        }
    }
}

/// A hand-built tab bar. SwiftUI's `TabView` only renders `Image` + `Text` in a
/// `.tabItem`, so custom shape icons would simply not appear.
struct VitremberTabBar: View {
    @Binding var selection: Int
    let metrics: VitremberMetrics

    private let items: [(String, Int)] = [
        ("Kiln", 0), ("Bench", 1), ("Shelf", 2), ("Almanac", 3), ("Ledger", 4)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(VitremberPalette.seam.opacity(0.55))
                .frame(height: 1)
            HStack(spacing: 0) {
                ForEach(items, id: \.1) { item in
                    tabButton(title: item.0, index: item.1)
                }
            }
            .padding(.top, metrics.isTiny ? 4 : 7)
            .padding(.bottom, metrics.isTiny ? 2 : 4)
            .frame(maxWidth: .infinity)
            .background(VitremberPalette.shell)
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        let active = selection == index
        let tint = active ? VitremberPalette.molten : VitremberPalette.faint
        let side: CGFloat = metrics.isTiny ? 19 : 22
        return Button(action: { selection = index }) {
            VStack(spacing: 3) {
                tabIcon(index: index, side: side, tint: tint)
                    .frame(width: side, height: side)
                Text(title)
                    .font(VitremberType.label(metrics.isTiny ? 8.5 : 9.5))
                    .kerning(0.5)
                    .foregroundColor(tint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private func tabIcon(index: Int, side: CGFloat, tint: Color) -> some View {
        switch index {
        case 0: FurnaceGlyph().fill(tint, style: FillStyle(eoFill: true))
        case 1: BenchGlyph().fill(tint)
        case 2: ShelfGlyph().fill(tint)
        case 3: AlmanacGlyph().stroke(tint, style: StrokeStyle(lineWidth: max(side * 0.08, 1.3),
                                                               lineJoin: .round))
        default: LedgerGlyph().fill(tint, style: FillStyle(eoFill: true))
        }
    }
}

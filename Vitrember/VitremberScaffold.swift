import SwiftUI

/// Layout facts derived from the container the app is actually running in, so the same
/// screens work from a 375x667 iPhone SE through to an iPad in landscape.
struct VitremberMetrics {
    let size: CGSize

    /// Short screens (SE, iPhone 8, and iPad compatibility mode) get a tighter layout.
    var isShort: Bool { size.height < 700 }
    /// Very short: landscape on a phone.
    var isTiny: Bool { size.height < 460 }
    var isWide: Bool { size.width >= 700 }
    /// Landscape-shaped containers put the furnace beside the benches instead of above
    /// them, so the flexible column never gets squeezed to nothing.
    var splitLayout: Bool { size.width >= 680 && size.height < 640 }

    /// Content is capped and centred so it never becomes an unreadable ribbon on iPad.
    var contentWidth: CGFloat { min(size.width, isWide ? 640 : size.width) }
    var gutter: CGFloat { isWide ? 26 : 16 }
    /// Usable width once the outer gutters are removed.
    var innerWidth: CGFloat { max(contentWidth - gutter * 2, 120) }

    var cardPadding: CGFloat { isShort ? 11 : 14 }
    var cardSpacing: CGFloat { isShort ? 9 : 12 }
    var titleSize: CGFloat { isShort ? 17 : 19 }
    var bodySize: CGFloat { isShort ? 12 : 13 }

    /// Bottom padding every scroll container adds so the last row clears the tab bar.
    var scrollBottomInset: CGFloat { 26 }
}

/// A raised plate. Used for every grouped block in the app.
struct VitremberCard<Content: View>: View {
    var padding: CGFloat = 14
    var tint: Color = VitremberPalette.plate
    var border: Color = VitremberPalette.seam
    var borderWidth: CGFloat = 1
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(border.opacity(0.55), lineWidth: borderWidth)
            )
    }
}

/// Tracked-out uppercase section label.
struct SectionHeader: View {
    let text: String
    var tint: Color = VitremberPalette.muted
    var size: CGFloat = 11

    var body: some View {
        Text(text.uppercased())
            .font(VitremberType.label(size))
            .kerning(1.6)
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The one button style in the app. Never nested inside another button.
struct PillButton: View {
    let title: String
    var subtitle: String? = nil
    var enabled: Bool = true
    var fill: Color = VitremberPalette.molten
    var textColor: Color = VitremberPalette.night
    var height: CGFloat = 42
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            VStack(spacing: 1) {
                Text(title)
                    .font(VitremberType.label(13))
                    .kerning(1.0)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(VitremberType.readout(10, .medium))
                        .opacity(0.78)
                }
            }
            .foregroundColor(enabled ? textColor : VitremberPalette.faint)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(enabled ? fill : VitremberPalette.plateHot.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(enabled ? fill.opacity(0.0) : VitremberPalette.seam.opacity(0.5), lineWidth: 1)
            )
            // A label made only of shapes and text still needs an explicit hit area.
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
    }
}

/// A quieter button for secondary actions.
struct GhostButton: View {
    let title: String
    var enabled: Bool = true
    var tint: Color = VitremberPalette.muted
    var height: CGFloat = 34
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            Text(title)
                .font(VitremberType.label(12))
                .kerning(0.9)
                .foregroundColor(enabled ? tint : VitremberPalette.faint)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VitremberPalette.night.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(VitremberPalette.seam.opacity(0.65), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
    }
}

/// A horizontal fill meter drawn from plain rectangles.
struct MeterBar: View {
    /// 0...1
    let value: Double
    let width: CGFloat
    var height: CGFloat = 7
    var tint: Color = VitremberPalette.molten
    var track: Color = VitremberPalette.night

    var body: some View {
        let filled = CGFloat(min(max(value, 0), 1)) * width
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(track.opacity(0.65))
                .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(tint)
                .frame(width: max(filled, filled > 0 ? height : 0), height: height)
        }
        .frame(width: width, height: height, alignment: .leading)
    }
}

/// Label on the left, monospaced figure on the right.
struct FigureRow: View {
    let label: String
    let value: String
    var tint: Color = VitremberPalette.ivory
    var size: CGFloat = 13

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(VitremberType.body(size))
                .foregroundColor(VitremberPalette.muted)
            Spacer(minLength: 6)
            Text(value)
                .font(VitremberType.readout(size, .semibold))
                .foregroundColor(tint)
        }
    }
}

/// A small diamond in the grade's colour.
struct GradePip: View {
    let grade: GlassGrade
    var side: CGFloat = 9

    static func colour(_ grade: GlassGrade) -> Color {
        switch grade {
        case .flawed: return VitremberPalette.flawed
        case .sound: return VitremberPalette.sound
        case .fine: return VitremberPalette.fine
        case .masterwork: return VitremberPalette.masterwork
        }
    }

    var body: some View {
        HallmarkGlyph()
            .fill(Self.colour(grade))
            .frame(width: side, height: side)
    }
}

/// Money figure with its coin badge, so a number is never ambiguous about what it counts.
struct CoinFigure: View {
    let amount: Double
    var size: CGFloat = 15
    var tint: Color = VitremberPalette.ember

    var body: some View {
        HStack(spacing: 4) {
            CoinBadge(size: size * 0.82, tint: tint)
            Text(VitremberFormat.coins(amount))
                .font(VitremberType.readout(size, .bold))
                .foregroundColor(VitremberPalette.ivory)
        }
    }
}

/// The scroll container every screen uses. Bottom padding lives INSIDE the scroll view,
/// so the last row always clears the tab bar — a `safeAreaInset` on the outer stack does
/// not reach here.
struct VitremberScroll<Content: View>: View {
    let metrics: VitremberMetrics
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                content()
            }
            .frame(width: metrics.innerWidth, alignment: .leading)
            .padding(.horizontal, metrics.gutter)
            .padding(.top, 10)
            .padding(.bottom, metrics.scrollBottomInset)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Screen title bar. There is no navigation bar anywhere in this app, so every screen
/// draws its own heading.
struct ScreenHeading: View {
    let title: String
    let caption: String
    var metrics: VitremberMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(VitremberType.body(metrics.titleSize, .bold))
                .foregroundColor(VitremberPalette.ivory)
            Text(caption)
                .font(VitremberType.body(metrics.bodySize - 1))
                .foregroundColor(VitremberPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

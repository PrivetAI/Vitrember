import Foundation

/// Money and rate formatting for the workshop ledger.
enum VitremberFormat {

    private static let suffixes = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]

    /// Short money form. Below 1,000 it stays an integer so early play reads plainly.
    static func coins(_ value: Double) -> String {
        if !value.isFinite { return "0" }
        let v = max(value, 0)
        if v < 1000 { return String(Int(v.rounded(.down))) }
        var scaled = v
        var index = 0
        while scaled >= 1000 && index < suffixes.count - 1 {
            scaled /= 1000
            index += 1
        }
        let digits = scaled < 10 ? 2 : (scaled < 100 ? 1 : 0)
        return String(format: "%.\(digits)f%@", scaled, suffixes[index])
    }

    /// Per-second income, always with the unit attached so no readout is ambiguous.
    static func rate(_ value: Double) -> String {
        coins(value) + "/s"
    }

    /// Temperature readout. Always three or four digits plus the degree mark.
    static func degrees(_ value: Double) -> String {
        String(Int(value.rounded())) + "\u{00B0}"
    }

    static func percent(_ fraction: Double, digits: Int = 0) -> String {
        String(format: "%.\(digits)f%%", min(max(fraction, 0), 999) * 100)
    }

    /// "2h 14m" / "9m 06s" / "42s"
    static func duration(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if m > 0 { return "\(m)m \(String(format: "%02d", s))s" }
        return "\(s)s"
    }

    /// Compact count for the shelf tallies.
    static func count(_ value: Int) -> String {
        value < 10000 ? String(value) : coins(Double(value))
    }
}

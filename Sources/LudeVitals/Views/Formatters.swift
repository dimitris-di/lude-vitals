import Foundation

enum Fmt {
    static func bytes(_ b: UInt64) -> String {
        let v = Double(b)
        if v >= 1_073_741_824 { return String(format: "%.1f GB", v / 1_073_741_824) }
        if v >= 1_048_576     { return String(format: "%.0f MB", v / 1_048_576) }
        if v >= 1_024         { return String(format: "%.0f KB", v / 1_024) }
        return "\(b) B"
    }
    static func rate(_ bps: UInt64) -> String {
        let v = Double(bps)
        if v >= 1_000_000 { return String(format: "%.1f MB/s", v / 1_000_000) }
        if v >= 1_000     { return String(format: "%.0f KB/s", v / 1_000) }
        return "\(bps) B/s"
    }
    static func duration(minutes: Int) -> String {
        if minutes <= 0 { return "n/a" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

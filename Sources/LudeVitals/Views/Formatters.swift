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

    /// Strip control chars, bidi overrides, zero-width / format chars, and clamp length.
    /// Defense-in-depth for kernel-sourced strings rendered to SwiftUI.
    static func sanitizeDisplayString(_ input: String, maxLength: Int = 64) -> String {
        let strippedScalars = input.unicodeScalars.filter { scalar in
            // Drop C0 + DEL + C1 control chars
            if scalar.value < 0x20 || (scalar.value >= 0x7F && scalar.value <= 0x9F) { return false }
            // Drop bidi overrides + isolates
            if (0x202A...0x202E).contains(scalar.value) { return false }
            if (0x2066...0x2069).contains(scalar.value) { return false }
            // Drop zero-width + format chars
            if (0x200B...0x200F).contains(scalar.value) { return false }
            if scalar.value == 0xFEFF { return false } // BOM / zero-width no-break space
            return true
        }
        let stripped = String(String.UnicodeScalarView(strippedScalars))
        if stripped.count <= maxLength { return stripped }
        return String(stripped.prefix(maxLength)) + "…"
    }
}

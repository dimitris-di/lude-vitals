import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var scheduler: SamplingScheduler
    @ObservedObject var settings: AppSettings

    var body: some View {
        let s = scheduler.latest
        let isStale = s.timestamp == .distantPast
        HStack(spacing: 9) {
            if isStale {
                Text("LudeVitals…").foregroundStyle(.secondary)
            } else {
                content(s)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .padding(.horizontal, 2)
        .fixedSize()
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary(s, isStale: isStale))
    }

    @ViewBuilder
    private func content(_ s: MetricSnapshot) -> some View {
        switch settings.displayMode {
        case .minimal:
            tempBlock(s)
        case .balanced:
            tempBlock(s)
            memBlock(s)
        case .full:
            cpuBlock(s)
            memBlock(s)
            tempBlock(s)
            netBlock(s)
        case .custom:
            let o = settings.customOptions
            if o.showCPU         { cpuBlock(s) }
            if o.showMemory      { memBlock(s) }
            if o.showTemperature { tempBlock(s) }
            if o.showNetwork     { netBlock(s) }
            if o.showSparkline {
                Sparkline(values: scheduler.history.values.map(\.cpu.totalUsage),
                          height: 13, color: .accentColor, lineWidth: 1.4)
                    .frame(width: 28)
            }
        }
    }

    private func cpuBlock(_ s: MetricSnapshot) -> some View {
        let v = Int((s.cpu.totalUsage * 100).rounded())
        return block(icon: "cpu.fill", text: Self.padDigits("\(v)", to: 3) + "%")
    }
    private func memBlock(_ s: MetricSnapshot) -> some View {
        let v = Int((s.memory.usagePercent * 100).rounded())
        return block(icon: "memorychip.fill", text: Self.padDigits("\(v)", to: 3) + "%")
    }
    private func tempBlock(_ s: MetricSnapshot) -> some View {
        let text: String
        if let c = s.thermal.cpuTemperature, c > 3 {
            text = Self.padDigits("\(Int(settings.tempUnit.convert(c).rounded()))", to: 3) + "°"
        } else {
            text = Self.padDigits("n/a", to: 3) + " "
        }
        return block(icon: "thermometer.medium", text: text)
    }
    private func netBlock(_ s: MetricSnapshot) -> some View {
        block(icon: "arrow.up.arrow.down",
              text: Self.compactRate(s.network.bytesInPerSec + s.network.bytesOutPerSec))
    }

    private func block(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .imageScale(.medium)
                .frame(width: 16, alignment: .center)
            Text(text)
        }
    }

    // Figure-space (U+2007) matches digit width when monospacedDigit is active.
    private static func padDigits(_ s: String, to width: Int) -> String {
        guard s.count < width else { return s }
        return String(repeating: "\u{2007}", count: width - s.count) + s
    }

    static func compactRate(_ bps: UInt64) -> String {
        let v = Double(bps)
        // Thresholds account for printf rounding: e.g. 999_999 / 1_000_000 = 0.9999
        // formats as "1.0M" with %.1f, so the M-tier needs to start at 999_500.
        let raw: String
        if v >= 99_950_000_000     { raw = "100G" }
        else if v >= 9_950_000_000 { raw = String(format: "%.0fG", v / 1_000_000_000) }
        else if v >= 999_500_000   { raw = String(format: "%.1fG", v / 1_000_000_000) }
        else if v >= 9_950_000     { raw = String(format: "%.0fM", v / 1_000_000) }
        else if v >= 999_500       { raw = String(format: "%.1fM", v / 1_000_000) }
        else if v >= 1_000         { raw = String(format: "%.0fK", v / 1_000) }
        else                       { raw = "0K" }
        return padDigits(raw, to: 4)
    }

    private func accessibilitySummary(_ s: MetricSnapshot, isStale: Bool) -> String {
        if isStale { return "LudeVitals loading" }
        var parts: [String] = []
        let cpu = Int((s.cpu.totalUsage * 100).rounded())
        let mem = Int((s.memory.usagePercent * 100).rounded())
        let tempStr: String? = {
            guard let c = s.thermal.cpuTemperature, c > 3 else { return nil }
            return "\(Int(settings.tempUnit.convert(c).rounded())) degrees"
        }()
        switch settings.displayMode {
        case .minimal:
            if let t = tempStr { parts.append("Temperature \(t)") }
        case .balanced:
            if let t = tempStr { parts.append("Temperature \(t)") }
            parts.append("Memory \(mem) percent")
        case .full:
            parts.append("CPU \(cpu) percent")
            parts.append("Memory \(mem) percent")
            if let t = tempStr { parts.append("Temperature \(t)") }
            parts.append("Network \(Self.compactRate(s.network.bytesInPerSec + s.network.bytesOutPerSec)) per second")
        case .custom:
            let o = settings.customOptions
            if o.showCPU { parts.append("CPU \(cpu) percent") }
            if o.showMemory { parts.append("Memory \(mem) percent") }
            if o.showTemperature, let t = tempStr { parts.append("Temperature \(t)") }
            if o.showNetwork { parts.append("Network \(Self.compactRate(s.network.bytesInPerSec + s.network.bytesOutPerSec)) per second") }
        }
        return parts.isEmpty ? "LudeVitals" : "LudeVitals: " + parts.joined(separator: ", ")
    }
}

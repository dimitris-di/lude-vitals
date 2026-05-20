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
        HStack(spacing: 4) {
            Image(systemName: "cpu.fill").imageScale(.medium)
            Text("\(Int((s.cpu.totalUsage * 100).rounded()))%")
        }
    }
    private func memBlock(_ s: MetricSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip.fill").imageScale(.medium)
            Text("\(Int((s.memory.usagePercent * 100).rounded()))%")
        }
    }
    private func tempBlock(_ s: MetricSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer.medium").imageScale(.medium)
            if let c = s.thermal.cpuTemperature, c > 3 {
                Text("\(Int(settings.tempUnit.convert(c).rounded()))°")
            } else {
                Text("—")
            }
        }
    }
    private func netBlock(_ s: MetricSnapshot) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down").imageScale(.medium)
            Text(Self.compactRate(s.network.bytesInPerSec + s.network.bytesOutPerSec))
        }
    }

    static func compactRate(_ bps: UInt64) -> String {
        let v = Double(bps)
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "%.0fK", v / 1_000) }
        return "0K"
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

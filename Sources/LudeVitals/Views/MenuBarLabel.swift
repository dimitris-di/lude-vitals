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
                          width: 28, height: 13, color: .accentColor, lineWidth: 1.4)
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
}

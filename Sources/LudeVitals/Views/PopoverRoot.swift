import SwiftUI

struct PopoverRoot: View {
    @ObservedObject var scheduler: SamplingScheduler
    @ObservedObject var settings: AppSettings

    var body: some View {
        let s = scheduler.latest
        let history = scheduler.history.values

        ZStack {
            Color.clear.background(.ultraThinMaterial)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    heroTiles(s, history: history)
                    if !s.cpu.perCore.isEmpty { coresCard(s) }
                    memoryCard(s)
                    thermalCard(s)
                    networkCard(s)
                    if let bat = s.battery { batteryCard(bat) }
                    processesCard(s)
                }
                .padding(14)
            }
        }
        .frame(width: 400, height: 580)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .imageScale(.medium)
                    .foregroundStyle(.tint)
                Text("LudeVitals")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button {
                (NSApp.delegate as? AppDelegate)?.prefsController.show()
            } label: {
                Image(systemName: "gearshape").imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hero tiles

    private func heroTiles(_ s: MetricSnapshot, history: [MetricSnapshot]) -> some View {
        let tempCelsius = s.thermal.cpuTemperature
        let tempValue: String = {
            guard let c = tempCelsius, c > 3 else { return "—" }
            return "\(Int(settings.tempUnit.convert(c).rounded()))°"
        }()
        return HStack(spacing: 8) {
            HeroTile(
                title: "CPU",
                value: "\(Int((s.cpu.totalUsage * 100).rounded()))%",
                tint: .blue,
                spark: history.map(\.cpu.totalUsage)
            )
            HeroTile(
                title: "RAM",
                value: "\(Int((s.memory.usagePercent * 100).rounded()))%",
                tint: .purple,
                spark: history.map(\.memory.usagePercent)
            )
            HeroTile(
                title: "Temp",
                value: tempValue,
                tint: .orange,
                spark: history.compactMap(\.thermal.cpuTemperature).filter { $0 > 3 }.map { min(1, max(0, ($0 - 30) / 70)) }
            )
        }
    }

    // MARK: - Cores

    private func coresCard(_ s: MetricSnapshot) -> some View {
        Card(title: "Cores") {
            VStack(alignment: .leading, spacing: 10) {
                let p = s.cpu.perCore.filter { $0.type == .performance }
                let e = s.cpu.perCore.filter { $0.type == .efficiency }
                let u = s.cpu.perCore.filter { $0.type == .unknown }
                if !p.isEmpty { CoreRow(label: "P", cores: p) }
                if !e.isEmpty { CoreRow(label: "E", cores: e) }
                if !u.isEmpty { CoreRow(label: "•", cores: u) }
                HStack(spacing: 14) {
                    inlineKV("1m",  String(format: "%.2f", s.cpu.loadAverage.one))
                    inlineKV("5m",  String(format: "%.2f", s.cpu.loadAverage.five))
                    inlineKV("15m", String(format: "%.2f", s.cpu.loadAverage.fifteen))
                }
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Memory

    private func memoryCard(_ s: MetricSnapshot) -> some View {
        Card(title: "Memory", accessory: { AnyView(PressurePill.memory(s.memory.pressure)) }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.bytes(s.memory.used))
                        .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                    Text("of \(Fmt.bytes(s.memory.total))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ProgressBar(value: s.memory.usagePercent, tint: pressureTint(s.memory.pressure))
                HStack(spacing: 14) {
                    inlineKV("app",      Fmt.bytes(s.memory.app))
                    inlineKV("wired",    Fmt.bytes(s.memory.wired))
                    inlineKV("comp",     Fmt.bytes(s.memory.compressed))
                    if s.memory.swapUsed > 0 {
                        inlineKV("swap", Fmt.bytes(s.memory.swapUsed))
                    }
                }
            }
        }
    }

    // MARK: - Thermal

    private func thermalCard(_ s: MetricSnapshot) -> some View {
        let t = s.thermal
        let any = t.cpuTemperature != nil || t.gpuTemperature != nil || !t.fans.isEmpty
        return Card(title: "Thermal", accessory: { AnyView(PressurePill.thermal(t.thermalPressure)) }) {
            if !any {
                Text("Sensors unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 18) {
                        if let c = t.cpuTemperature { tempReadout("CPU", celsius: c) }
                        if let g = t.gpuTemperature { tempReadout("GPU", celsius: g) }
                        if let b = t.batteryTemperature { tempReadout("Battery", celsius: b) }
                        Spacer()
                    }
                    if !t.fans.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(t.fans) { f in FanRow(reading: f) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Network

    private func networkCard(_ s: MetricSnapshot) -> some View {
        Card(title: "Network", accessory: {
            AnyView(
                Text(s.network.primaryInterface ?? "—")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            )
        }) {
            HStack(spacing: 22) {
                NetRate(symbol: "arrow.down", color: .green, bps: s.network.bytesInPerSec)
                NetRate(symbol: "arrow.up", color: .blue, bps: s.network.bytesOutPerSec)
                Spacer()
            }
        }
    }

    // MARK: - Battery

    private func batteryCard(_ b: BatteryMetrics) -> some View {
        Card(title: "Battery", accessory: {
            AnyView(
                HStack(spacing: 4) {
                    Image(systemName: b.isCharging ? "bolt.fill" : (b.isPluggedIn ? "powerplug.fill" : "battery.100"))
                        .imageScale(.small)
                        .foregroundStyle(b.isCharging ? .yellow : .secondary)
                    Text("\(Int((b.percentage * 100).rounded()))%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
            )
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ProgressBar(
                    value: b.percentage,
                    tint: b.isCharging ? .green : (b.percentage < 0.15 ? .red : (b.percentage < 0.30 ? .orange : .accentColor))
                )
                HStack(spacing: 14) {
                    if let t = b.timeRemainingMinutes { inlineKV(b.isCharging ? "to full" : "remaining", Fmt.duration(minutes: t)) }
                    if let c = b.cycleCount { inlineKV("cycles", "\(c)") }
                    if let h = b.health { inlineKV("health", "\(Int((h * 100).rounded()))%") }
                    if let w = b.wattage {
                        inlineKV("power", String(format: "%@%.1fW", w >= 0 ? "+" : "−", abs(w)))
                    }
                }
            }
        }
    }

    // MARK: - Processes

    private func processesCard(_ s: MetricSnapshot) -> some View {
        Card(title: "Top processes") {
            ProcessListView(processes: s.cpu.topProcesses)
        }
    }

    // MARK: - Helpers

    private func inlineKV(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(.caption2).foregroundStyle(.tertiary).textCase(.lowercase)
            Text(v).font(.caption.monospacedDigit().weight(.medium))
        }
    }

    private func tempReadout(_ label: String, celsius: Double) -> some View {
        let v = settings.tempUnit.convert(celsius)
        return VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(v.rounded()))\(settings.tempUnit.symbol)")
                .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
        }
    }

    private func pressureTint(_ p: MemoryPressure) -> Color {
        switch p { case .normal: return .accentColor; case .warning: return .orange; case .critical: return .red }
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    let title: String
    var accessory: (() -> AnyView)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                if let a = accessory { a() }
            }
            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - Hero tile

struct HeroTile: View {
    let title: String
    let value: String
    let tint: Color
    let spark: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            GeometryReader { geo in
                Sparkline(values: spark, width: geo.size.width, height: 16, color: tint, lineWidth: 1.6)
            }
            .frame(height: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [tint.opacity(0.20), tint.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.22))
        )
    }
}

// MARK: - Cores

struct CoreRow: View {
    let label: String
    let cores: [CoreUsage]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .leading)
            HStack(spacing: 3) {
                ForEach(cores) { c in
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(barColor(c.usage))
                                .frame(height: max(2, geo.size.height * CGFloat(min(1, max(0, c.usage)))))
                        }
                    }
                    .frame(width: 10, height: 26)
                }
            }
            Spacer()
            Text("\(Int((average(cores) * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func average(_ c: [CoreUsage]) -> Double {
        c.isEmpty ? 0 : c.map(\.usage).reduce(0, +) / Double(c.count)
    }
    private func barColor(_ v: Double) -> Color {
        v < 0.6 ? .green : (v < 0.85 ? .yellow : .red)
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(tint).frame(width: geo.size.width * CGFloat(max(0, min(1, value))))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Net rate

struct NetRate: View {
    let symbol: String
    let color: Color
    let bps: UInt64

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .background(Circle().fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.rate(bps))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                Text(symbol.contains("down") ? "download" : "upload")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Fan

struct FanRow: View {
    let reading: FanReading
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "fanblades")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text(reading.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(reading.rpm)")
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
            Text("RPM")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Pressure pill

struct PressurePill: View {
    let label: String
    let tint: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(.primary)
    }
    static func memory(_ p: MemoryPressure) -> some View {
        switch p {
        case .normal:   return PressurePill(label: "Normal",   tint: .green)
        case .warning:  return PressurePill(label: "Warning",  tint: .orange)
        case .critical: return PressurePill(label: "Critical", tint: .red)
        }
    }
    static func thermal(_ p: ThermalPressure) -> some View {
        switch p {
        case .nominal:  return PressurePill(label: "Nominal",  tint: .green)
        case .fair:     return PressurePill(label: "Fair",     tint: .yellow)
        case .serious:  return PressurePill(label: "Serious",  tint: .orange)
        case .critical: return PressurePill(label: "Critical", tint: .red)
        }
    }
}

// MARK: - Process list

struct ProcessListView: View {
    let processes: [ProcessUsage]
    @State private var sort: SortMode = .cpu
    enum SortMode: String, CaseIterable, Identifiable { case cpu = "CPU"; case mem = "RAM"; var id: String { rawValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $sort) {
                ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 110)

            let rows = (sort == .cpu
                ? processes.sorted { $0.cpu > $1.cpu }
                : processes.sorted { $0.memoryBytes > $1.memoryBytes }
            ).prefix(5)

            if rows.isEmpty {
                Text("—").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(rows)) { p in
                        HStack(spacing: 8) {
                            Text(p.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1).truncationMode(.tail)
                            Spacer()
                            Text(String(format: "%.1f%%", p.cpu * 100))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(sort == .cpu ? .primary : .secondary)
                                .frame(width: 52, alignment: .trailing)
                            Text(Fmt.bytes(p.memoryBytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(sort == .mem ? .primary : .secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Formatters

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
        if minutes <= 0 { return "—" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

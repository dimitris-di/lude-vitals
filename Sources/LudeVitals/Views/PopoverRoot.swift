import SwiftUI

struct PopoverRoot: View {
    @ObservedObject var scheduler: SamplingScheduler
    @ObservedObject var settings: AppSettings

    var body: some View {
        let s = scheduler.latest
        let history = scheduler.history.values

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
                Spacer(minLength: 0)
            }
            .padding(14)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .frame(width: 400, height: 580)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .imageScale(.medium)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("LudeVitals")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button {
                (NSApp.delegate as? AppDelegate)?.prefsController.show()
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Preferences")
        }
    }

    // MARK: - Hero tiles

    private func heroTiles(_ s: MetricSnapshot, history: [MetricSnapshot]) -> some View {
        let tempCelsius = s.thermal.cpuTemperature
        let tempValue: String = {
            guard let c = tempCelsius, c > 3 else { return "··" }
            return "\(Int(settings.tempUnit.convert(c).rounded()))°"
        }()
        let tempA11y: String = {
            guard let c = tempCelsius, c > 3 else { return "Unavailable" }
            return "\(Int(settings.tempUnit.convert(c).rounded())) \(settings.tempUnit.symbol)"
        }()
        return HStack(spacing: 8) {
            HeroTile(
                title: "CPU",
                value: "\(Int((s.cpu.totalUsage * 100).rounded()))%",
                tint: .blue,
                spark: history.map(\.cpu.totalUsage)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("CPU usage")
            .accessibilityValue("\(Int((s.cpu.totalUsage * 100).rounded())) percent")

            HeroTile(
                title: "RAM",
                value: "\(Int((s.memory.usagePercent * 100).rounded()))%",
                tint: .purple,
                spark: history.map(\.memory.usagePercent)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Memory usage")
            .accessibilityValue("\(Int((s.memory.usagePercent * 100).rounded())) percent")

            HeroTile(
                title: "Temp",
                value: tempValue,
                tint: .orange,
                spark: history.compactMap(\.thermal.cpuTemperature).filter { $0 > 3 }.map { min(1, max(0, ($0 - 30) / 70)) }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("CPU temperature")
            .accessibilityValue(tempA11y)
        }
    }

    // MARK: - Cores

    private func coresCard(_ s: MetricSnapshot) -> some View {
        let load = String(format: "%.2f  %.2f  %.2f",
                          s.cpu.loadAverage.one,
                          s.cpu.loadAverage.five,
                          s.cpu.loadAverage.fifteen)
        return Card(title: "Cores", accessory: {
            HStack(spacing: 4) {
                Text("load")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(load)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Load averages 1, 5, 15 minutes")
            .accessibilityValue(load)
        }) {
            VStack(alignment: .leading, spacing: 8) {
                let p = s.cpu.perCore.filter { $0.type == .performance }
                let e = s.cpu.perCore.filter { $0.type == .efficiency }
                let u = s.cpu.perCore.filter { $0.type == .unknown }
                if !p.isEmpty { CoreRow(label: "P", clusterName: "Performance cores", cores: p) }
                if !e.isEmpty { CoreRow(label: "E", clusterName: "Efficiency cores", cores: e) }
                if !u.isEmpty { CoreRow(label: "•", clusterName: "Cores", cores: u) }
            }
        }
    }

    // MARK: - Memory

    private func memoryCard(_ s: MetricSnapshot) -> some View {
        Card(title: "Memory", accessory: {
            PressurePill.memory(s.memory.pressure)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Memory pressure")
                .accessibilityValue(pressureA11y(s.memory.pressure))
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Fmt.bytes(s.memory.used))
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text("of \(Fmt.bytes(s.memory.total))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Memory used")
                .accessibilityValue("\(Fmt.bytes(s.memory.used)) of \(Fmt.bytes(s.memory.total))")

                ProgressBar(value: s.memory.usagePercent, tint: pressureTint(s.memory.pressure))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Memory usage")
                    .accessibilityValue("\(Int((s.memory.usagePercent * 100).rounded())) percent")

                HStack(spacing: 14) {
                    inlineKV("app",      Fmt.bytes(s.memory.app))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("App memory")
                        .accessibilityValue(Fmt.bytes(s.memory.app))
                    inlineKV("wired",    Fmt.bytes(s.memory.wired))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Wired memory")
                        .accessibilityValue(Fmt.bytes(s.memory.wired))
                    inlineKV("comp",     Fmt.bytes(s.memory.compressed))
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Compressed memory")
                        .accessibilityValue(Fmt.bytes(s.memory.compressed))
                    if s.memory.swapUsed > 0 {
                        inlineKV("swap", Fmt.bytes(s.memory.swapUsed))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Swap used")
                            .accessibilityValue(Fmt.bytes(s.memory.swapUsed))
                    }
                }
            }
        }
    }

    // MARK: - Thermal

    private func thermalCard(_ s: MetricSnapshot) -> some View {
        let t = s.thermal
        let any = t.cpuTemperature != nil || t.gpuTemperature != nil || !t.fans.isEmpty
        return Card(title: "Thermal", accessory: {
            PressurePill.thermal(t.thermalPressure)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Thermal pressure")
                .accessibilityValue(thermalA11y(t.thermalPressure))
        }) {
            if !any {
                Text("Sensors unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 18) {
                        if let c = t.cpuTemperature { tempReadout("CPU", celsius: c, a11yLabel: "CPU temperature") }
                        if let g = t.gpuTemperature { tempReadout("GPU", celsius: g, a11yLabel: "GPU temperature") }
                        if let b = t.batteryTemperature { tempReadout("Battery", celsius: b, a11yLabel: "Battery temperature") }
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
            Text(s.network.primaryInterface ?? "··")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityLabel("Primary interface \(s.network.primaryInterface ?? "none")")
        }) {
            HStack(spacing: 22) {
                NetRate(symbol: "arrow.down", color: .green, bps: s.network.bytesInPerSec)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Download rate")
                    .accessibilityValue(Fmt.rate(s.network.bytesInPerSec))
                NetRate(symbol: "arrow.up", color: .blue, bps: s.network.bytesOutPerSec)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Upload rate")
                    .accessibilityValue(Fmt.rate(s.network.bytesOutPerSec))
                Spacer()
            }
        }
    }

    // MARK: - Battery

    private func batteryCard(_ b: BatteryMetrics) -> some View {
        Card(title: "Battery", accessory: {
            HStack(spacing: 4) {
                Image(systemName: b.isCharging ? "bolt.fill" : (b.isPluggedIn ? "powerplug.fill" : "battery.100"))
                    .imageScale(.small)
                    .foregroundStyle(b.isCharging ? .yellow : .secondary)
                Text("\(Int((b.percentage * 100).rounded()))%")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Battery level\(b.isCharging ? ", charging" : (b.isPluggedIn ? ", plugged in" : ""))")
            .accessibilityValue("\(Int((b.percentage * 100).rounded())) percent")
        }) {
            VStack(alignment: .leading, spacing: 10) {
                ProgressBar(
                    value: b.percentage,
                    tint: b.isCharging ? .green : (b.percentage < 0.15 ? .red : (b.percentage < 0.30 ? .orange : .accentColor))
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Battery charge")
                .accessibilityValue("\(Int((b.percentage * 100).rounded())) percent")

                HStack(spacing: 14) {
                    if let t = b.timeRemainingMinutes {
                        inlineKV(b.isCharging ? "to full" : "remaining", Fmt.duration(minutes: t))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(b.isCharging ? "Time to full" : "Time remaining")
                            .accessibilityValue(Fmt.duration(minutes: t))
                    }
                    if let c = b.cycleCount {
                        inlineKV("cycles", "\(c)")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Cycle count")
                            .accessibilityValue("\(c)")
                    }
                    if let h = b.health {
                        inlineKV("health", "\(Int((h * 100).rounded()))%")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Battery health")
                            .accessibilityValue("\(Int((h * 100).rounded())) percent")
                    }
                    if let w = b.wattage {
                        inlineKV("power", String(format: "%@%.1fW", w >= 0 ? "+" : "−", abs(w)))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Power")
                            .accessibilityValue(String(format: "%.1f watts", abs(w)))
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

    private func tempReadout(_ label: String, celsius: Double, a11yLabel: String) -> some View {
        let v = settings.tempUnit.convert(celsius)
        return VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(v.rounded()))\(settings.tempUnit.symbol)")
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .accessibilityValue("\(Int(v.rounded())) \(settings.tempUnit.symbol)")
    }

    private func pressureTint(_ p: MemoryPressure) -> Color {
        switch p { case .normal: return .accentColor; case .warning: return .orange; case .critical: return .red }
    }

    private func pressureA11y(_ p: MemoryPressure) -> String {
        switch p { case .normal: return "normal"; case .warning: return "warning"; case .critical: return "critical" }
    }

    private func thermalA11y(_ p: ThermalPressure) -> String {
        switch p { case .nominal: return "nominal"; case .fair: return "fair"; case .serious: return "serious"; case .critical: return "critical" }
    }
}

// MARK: - Card

struct Card<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let strokeOpacity = contrast == .increased ? 0.25 : 0.06
        let fillOpacity   = contrast == .increased ? 0.55 : 0.4
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                accessory()
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background.opacity(fillOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(strokeOpacity))
        )
    }
}

extension Card where Accessory == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.accessory = { EmptyView() }
        self.content = content
    }
}

// MARK: - Hero tile

struct HeroTile: View {
    let title: String
    let value: String
    let tint: Color
    let spark: [Double]
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let gradStart = contrast == .increased ? tint.opacity(0.35) : tint.opacity(0.20)
        let gradEnd   = contrast == .increased ? tint.opacity(0.20) : tint.opacity(0.05)
        let stroke    = contrast == .increased ? tint.opacity(0.45) : tint.opacity(0.22)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold).monospaced())
                .tracking(0.6)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Sparkline(values: spark, height: 16, color: tint, lineWidth: 1.6)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [gradStart, gradEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(stroke)
        )
    }
}

// MARK: - Cores

struct CoreRow: View {
    let label: String
    var clusterName: String = "Cores"
    let cores: [CoreUsage]
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let trackOpacity = contrast == .increased ? 0.20 : 0.10
        let avg = average(cores)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Text("\(Int((avg * 100).rounded()))%")
                    .font(.callout.monospacedDigit().weight(.semibold))
            }
            .frame(width: 36, alignment: .leading)
            .accessibilityHidden(true)

            HStack(spacing: 3) {
                ForEach(cores) { c in
                    CoreBar(usage: c.usage, trackOpacity: trackOpacity)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(clusterName)
        .accessibilityValue("Average \(Int((avg * 100).rounded())) percent across \(cores.count) cores")
    }

    private func average(_ c: [CoreUsage]) -> Double {
        c.isEmpty ? 0 : c.map(\.usage).reduce(0, +) / Double(c.count)
    }
}

private struct CoreBar: View {
    let usage: Double
    let trackOpacity: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.primary.opacity(trackOpacity))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(barColor(usage))
                    .frame(height: max(2, geo.size.height * CGFloat(min(1, max(0, usage)))))
            }
        }
    }
    private func barColor(_ v: Double) -> Color {
        v < 0.6 ? .green : (v < 0.85 ? .yellow : .red)
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    let value: Double
    let tint: Color
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let trackOpacity = contrast == .increased ? 0.2 : 0.08
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(trackOpacity))
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
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(Fmt.rate(bps))
                    .font(.callout.weight(.semibold).monospacedDigit())
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
                .accessibilityHidden(true)
            Text(reading.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(reading.rpm)")
                .font(.callout.weight(.semibold).monospacedDigit())
            Text("RPM")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fan \(reading.label)")
        .accessibilityValue("\(reading.rpm) RPM")
    }
}

// MARK: - Pressure pill

struct PressurePill: View {
    let label: String
    let tint: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
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
            Picker("Sort processes", selection: $sort) {
                ForEach(SortMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Sort processes")

            let rows = (sort == .cpu
                ? processes.sorted { $0.cpu > $1.cpu }
                : processes.sorted { $0.memoryBytes > $1.memoryBytes }
            ).prefix(5)

            if rows.isEmpty {
                Text("··").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(rows)) { p in
                        HStack(spacing: 8) {
                            Text(p.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1).truncationMode(.tail)
                            Spacer()
                            Text(String(format: "%.1f%%", p.cpu * 100))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(sort == .cpu ? .primary : .secondary)
                                .frame(minWidth: 52, alignment: .trailing)
                                .fixedSize(horizontal: true, vertical: false)
                            Text(Fmt.bytes(p.memoryBytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(sort == .mem ? .primary : .secondary)
                                .frame(minWidth: 60, alignment: .trailing)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Process \(p.name)")
                        .accessibilityValue("CPU \(String(format: "%.1f", p.cpu * 100)) percent, memory \(Fmt.bytes(p.memoryBytes))")
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
        if minutes <= 0 { return "··" }
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return "\(h)h \(m)m"
    }
}

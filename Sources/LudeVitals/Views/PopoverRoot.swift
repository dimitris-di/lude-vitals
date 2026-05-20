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
            guard let c = tempCelsius, c > 3 else { return "n/a" }
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
            Text(s.network.primaryInterface ?? "n/a")
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

import Foundation
import Combine

@MainActor
final class SamplingScheduler: ObservableObject {
    @Published private(set) var latest: MetricSnapshot = .placeholder
    @Published private(set) var history: RingBuffer<MetricSnapshot> = RingBuffer(capacity: 60)

    // Set by StatusItemController; samplers can branch on this to do cheap-only work when false.
    @Published var popoverIsOpen: Bool = false

    var cpuSampler:     (any AnySampler<CPUMetrics>)?
    var memorySampler:  (any AnySampler<MemoryMetrics>)?
    var thermalSampler: (any AnySampler<ThermalMetrics>)?
    var networkSampler: (any AnySampler<NetworkMetrics>)?
    var batterySampler: (any AnySampler<BatteryMetrics?>)?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.lude.LudeVitals.sampling", qos: .utility)
    private(set) var interval: TimeInterval
    private var isSampling = false

    init(interval: TimeInterval = 2.0, historyCapacity: Int = 60) {
        self.interval = interval
        self.history = RingBuffer(capacity: historyCapacity)
    }

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.1, repeating: interval, leeway: .milliseconds(100))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func setInterval(_ newValue: TimeInterval) {
        interval = max(0.5, newValue)
        if timer != nil { start() }
    }

    private nonisolated func tick() {
        Task { @MainActor in
            guard !self.isSampling else { return }
            self.isSampling = true
            defer { self.isSampling = false }

            let cpu     = self.cpuSampler?.sample()     ?? .zero
            let memory  = self.memorySampler?.sample()  ?? .zero
            let thermal = self.thermalSampler?.sample() ?? .zero
            let network = self.networkSampler?.sample() ?? .zero
            let battery = self.batterySampler?.sample() ?? nil
            let snap = MetricSnapshot(
                timestamp: .now,
                cpu: cpu, memory: memory, thermal: thermal,
                network: network, battery: battery
            )
            self.latest = snap
            self.history.append(snap)
        }
    }
}

@MainActor
protocol AnySampler<Output>: AnyObject {
    associatedtype Output
    func sample() -> Output
}

extension MetricSnapshot {
    static let placeholder = MetricSnapshot(
        timestamp: .distantPast,
        cpu: .zero, memory: .zero, thermal: .zero, network: .zero, battery: nil
    )
}

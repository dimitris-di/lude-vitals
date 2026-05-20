import Foundation
import Combine

/// Central sampling loop. Runs on a background DispatchQueue at `interval`
/// seconds, collects all samplers, publishes the snapshot on the main thread.
///
/// Agents wire their samplers via the public properties before calling `start()`.
@MainActor
final class SamplingScheduler: ObservableObject {
    @Published private(set) var latest: MetricSnapshot = .placeholder
    @Published private(set) var history: RingBuffer<MetricSnapshot> = RingBuffer(capacity: 60)

    var cpuSampler:     (any AnySampler<CPUMetrics>)?
    var memorySampler:  (any AnySampler<MemoryMetrics>)?
    var thermalSampler: (any AnySampler<ThermalMetrics>)?
    var networkSampler: (any AnySampler<NetworkMetrics>)?
    var batterySampler: (any AnySampler<BatteryMetrics?>)?

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.lude.LudeVitals.sampling", qos: .utility)
    private(set) var interval: TimeInterval

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

/// Type-erased sampler wrapper to dodge associated-type constraints at storage time.
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

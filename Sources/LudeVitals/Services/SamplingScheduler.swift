import Foundation
import Combine

struct SamplingContext: Sendable {
    let popoverIsOpen: Bool
}

@MainActor
final class SamplingScheduler: ObservableObject {
    @Published private(set) var latest: MetricSnapshot = .placeholder
    @Published private(set) var history: RingBuffer<MetricSnapshot> = RingBuffer(capacity: 60)

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
    private var timerGeneration = 0
    private let tickGate = SamplingTickGate()

    init(interval: TimeInterval = 2.0, historyCapacity: Int = 60) {
        self.interval = interval
        self.history = RingBuffer(capacity: historyCapacity)
    }

    func start() {
        stop()
        timerGeneration += 1
        let generation = timerGeneration
        let gate = tickGate
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.1, repeating: interval, leeway: .milliseconds(100))
        t.setEventHandler { [weak self, gate] in
            guard gate.tryEnter() else { return }
            Task { @MainActor [weak self, gate] in
                defer { gate.leave() }
                await self?.tick(generation: generation)
            }
        }
        timer = t
        t.resume()
    }

    func stop() {
        if timer != nil {
            timerGeneration += 1
        }
        timer?.cancel()
        timer = nil
    }

    func setInterval(_ newValue: TimeInterval) {
        let clamped = max(0.5, newValue)
        guard clamped != interval else { return }
        interval = clamped
        if timer != nil { start() }
    }

    func tick(generation: Int) async {
        guard generation == timerGeneration, timer != nil else { return }
        guard !isSampling else { return }
        isSampling = true
        defer { isSampling = false }

        let context = SamplingContext(popoverIsOpen: popoverIsOpen)
        let cpu     = await cpuSampler?.sample(context: context)     ?? .zero
        let memory  = await memorySampler?.sample(context: context)  ?? .zero
        let thermal = await thermalSampler?.sample(context: context) ?? .zero
        let network = await networkSampler?.sample(context: context) ?? .zero
        let battery = await batterySampler?.sample(context: context) ?? nil
        let snap = MetricSnapshot(
            timestamp: .now,
            cpu: cpu, memory: memory, thermal: thermal,
            network: network, battery: battery
        )
        latest = snap
        history.append(snap)
    }
}

private final class SamplingTickGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isPendingOrRunning = false

    func tryEnter() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isPendingOrRunning else { return false }
        isPendingOrRunning = true
        return true
    }

    func leave() {
        lock.lock()
        isPendingOrRunning = false
        lock.unlock()
    }
}

@MainActor
protocol AnySampler<Output>: AnyObject {
    associatedtype Output
    func sample(context: SamplingContext) async -> Output
}

extension MetricSnapshot {
    static let placeholder = MetricSnapshot(
        timestamp: .distantPast,
        cpu: .zero, memory: .zero, thermal: .zero, network: .zero, battery: nil
    )
}

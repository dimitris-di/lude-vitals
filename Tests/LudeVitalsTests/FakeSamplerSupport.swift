import XCTest
import Combine
@testable import LudeVitals

/// A scripted `AnySampler` used by tests.
///
/// Each call to ``sample(context:)`` returns the next value from a pre-seeded
/// queue. Once the queue is drained, the sampler returns either the last
/// scripted value (when initialized with a non-empty `values` array) or a
/// caller-provided `defaultValue`.
@MainActor
final class FakeSampler<Output>: AnySampler {
    /// Remaining scripted outputs. The head is consumed on each call.
    private var queue: [Output]
    /// Value returned once `queue` is empty.
    private var fallback: Output

    /// Number of times ``sample(context:)`` was invoked.
    private(set) var calls: Int = 0
    /// Every `SamplingContext` that was passed to ``sample(context:)``.
    private(set) var contexts: [SamplingContext] = []

    /// Create a sampler from a non-empty list of scripted values.
    /// After the queue drains, subsequent calls repeat the last value forever.
    init(values: [Output]) {
        precondition(!values.isEmpty, "FakeSampler(values:) requires at least one value; use init(values:default:) for an empty script")
        self.queue = values
        self.fallback = values.last!
    }

    /// Create a sampler with an explicit fallback returned after the script
    /// (which may be empty) is drained.
    init(values: [Output] = [], default defaultValue: Output) {
        self.queue = values
        self.fallback = defaultValue
    }

    /// Append more scripted values to be returned by future calls.
    func enqueue(_ value: Output) {
        queue.append(value)
    }

    /// Replace the fallback returned after the script drains.
    func setDefault(_ value: Output) {
        fallback = value
    }

    func sample(context: SamplingContext) async -> Output {
        calls += 1
        contexts.append(context)
        if queue.isEmpty {
            return fallback
        }
        return queue.removeFirst()
    }
}

// MARK: - Convenience aliases for metric sampler outputs

typealias FakeCPUSampler     = FakeSampler<CPUMetrics>
typealias FakeMemorySampler  = FakeSampler<MemoryMetrics>
typealias FakeNetworkSampler = FakeSampler<NetworkMetrics>
typealias FakeBatterySampler = FakeSampler<BatteryMetrics?>
typealias FakeThermalSampler = FakeSampler<ThermalMetrics>

// MARK: - RecordingPublisher

/// Subscribes to a Combine publisher and records every emitted value so a
/// test can assert the full stream after exercising the system under test.
@MainActor
final class RecordingPublisher<T> {
    private(set) var values: [T] = []
    private var cancellable: AnyCancellable?

    /// Subscribe to a publisher whose output is `T`. Any failure terminates
    /// recording silently (tests should use `Never`-failure publishers like
    /// `@Published`).
    init<P: Publisher>(_ publisher: P) where P.Output == T, P.Failure == Never {
        self.cancellable = publisher.sink { [weak self] value in
            self?.values.append(value)
        }
    }

    /// Stop recording further values.
    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }

    /// Number of recorded emissions.
    var count: Int { values.count }

    /// Most recent recorded value, if any.
    var last: T? { values.last }
}

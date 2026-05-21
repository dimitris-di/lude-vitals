import XCTest
@testable import LudeVitals

@MainActor
final class SamplingSchedulerTests: XCTestCase {

    // MARK: - Helpers

    /// Poll `condition` until it returns `true` or `timeout` elapses.
    /// Uses 50 ms sleeps between checks so tests stay deterministic and fast.
    private func waitFor(
        timeout: TimeInterval = 2.0,
        _ condition: () -> Bool
    ) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
        }
        return condition()
    }

    /// Build a scheduler with a short interval and all five fake samplers wired.
    private func makeScheduler(
        cpu: FakeCPUSampler? = nil,
        memory: FakeMemorySampler? = nil,
        thermal: FakeThermalSampler? = nil,
        network: FakeNetworkSampler? = nil,
        battery: FakeBatterySampler? = nil,
        interval: TimeInterval = 0.5
    ) -> SamplingScheduler {
        let s = SamplingScheduler(interval: interval, historyCapacity: 60)
        s.cpuSampler = cpu
        s.memorySampler = memory
        s.thermalSampler = thermal
        s.networkSampler = network
        s.batterySampler = battery
        return s
    }

    // MARK: - Tests

    func testTickPublishesSnapshotFromSamplers() async {
        let cpu     = FakeCPUSampler(values: [.zero])
        let memory  = FakeMemorySampler(values: [.zero])
        let thermal = FakeThermalSampler(values: [.zero])
        let network = FakeNetworkSampler(values: [.zero])
        let battery = FakeBatterySampler(values: [nil], default: nil)

        let scheduler = makeScheduler(
            cpu: cpu, memory: memory, thermal: thermal,
            network: network, battery: battery
        )

        scheduler.start()
        defer { scheduler.stop() }

        let didTick = await waitFor { scheduler.history.count > 0 }
        XCTAssertTrue(didTick, "Expected at least one tick to populate history")
        XCTAssertGreaterThanOrEqual(cpu.calls, 1)
        XCTAssertEqual(scheduler.latest.cpu.totalUsage, CPUMetrics.zero.totalUsage)
    }

    func testSamplersReceivePopoverContext() async {
        let cpu = FakeCPUSampler(values: [.zero])
        let scheduler = makeScheduler(cpu: cpu)

        scheduler.popoverIsOpen = true
        scheduler.start()
        defer { scheduler.stop() }

        XCTAssertTrue(await waitFor { cpu.calls >= 1 })
        XCTAssertEqual(cpu.contexts.last?.popoverIsOpen, true)

        let callsBefore = cpu.calls
        scheduler.popoverIsOpen = false

        XCTAssertTrue(await waitFor { cpu.calls > callsBefore })
        XCTAssertEqual(cpu.contexts.last?.popoverIsOpen, false)
    }

    func testSetIntervalIsClampedAndIdempotent() {
        let scheduler = makeScheduler(interval: 2.0)

        scheduler.setInterval(0.1)
        XCTAssertEqual(scheduler.interval, 0.5, "Sub-0.5 intervals must be clamped")

        // Calling with the same (already-clamped) value should be a no-op.
        scheduler.setInterval(0.5)
        XCTAssertEqual(scheduler.interval, 0.5)

        // Behavioural idempotency: a second call to the same interval while
        // running should not crash and the interval must remain stable.
        scheduler.start()
        defer { scheduler.stop() }
        scheduler.setInterval(0.5)
        XCTAssertEqual(scheduler.interval, 0.5)
    }

    func testStopHaltsTicking() async {
        let cpu = FakeCPUSampler(values: [.zero])
        let scheduler = makeScheduler(cpu: cpu)

        scheduler.start()
        XCTAssertTrue(await waitFor { scheduler.history.count >= 1 })

        scheduler.stop()
        let frozenCount = scheduler.history.count
        let frozenCalls = cpu.calls

        // Wait long enough that another tick would have fired if the timer
        // were still alive (interval is 0.5s).
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 s

        XCTAssertEqual(scheduler.history.count, frozenCount,
                       "history must not grow after stop()")
        XCTAssertEqual(cpu.calls, frozenCalls,
                       "sampler must not be invoked after stop()")
    }

    func testNilSamplerYieldsZeroMetric() async {
        let cpu = FakeCPUSampler(values: [.zero])
        // memory, thermal, network, battery intentionally left nil.
        let scheduler = makeScheduler(cpu: cpu)

        scheduler.start()
        defer { scheduler.stop() }

        XCTAssertTrue(await waitFor { scheduler.history.count >= 1 })

        let snap = scheduler.latest
        XCTAssertEqual(snap.memory.used,  MemoryMetrics.zero.used)
        XCTAssertNil(snap.thermal.cpuTemperature)
        XCTAssertTrue(snap.thermal.fans.isEmpty)
        XCTAssertEqual(snap.network.bytesInPerSec, NetworkMetrics.zero.bytesInPerSec)
        XCTAssertNil(snap.battery)
    }
}

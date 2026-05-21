import XCTest
@testable import LudeVitals

final class MetricModelTests: XCTestCase {
    func testMemoryUsagePercentHandlesZeroTotal() {
        XCTAssertEqual(MemoryMetrics.zero.usagePercent, 0)
    }

    func testMemoryUsagePercentUsesUsedBytesOverTotalBytes() {
        let metrics = MemoryMetrics(
            total: 16_000,
            used: 4_000,
            app: 0,
            wired: 0,
            compressed: 0,
            cached: 0,
            free: 12_000,
            swapUsed: 0,
            swapTotal: 0,
            pressure: .normal
        )

        XCTAssertEqual(metrics.usagePercent, 0.25)
    }

    func testCPUZeroIsIdleBaseline() {
        XCTAssertEqual(CPUMetrics.zero.totalUsage, 0)
        XCTAssertEqual(CPUMetrics.zero.userUsage, 0)
        XCTAssertEqual(CPUMetrics.zero.systemUsage, 0)
        XCTAssertEqual(CPUMetrics.zero.idleUsage, 1)
        XCTAssertTrue(CPUMetrics.zero.perCore.isEmpty)
        XCTAssertNil(CPUMetrics.zero.pCoreAverage)
        XCTAssertNil(CPUMetrics.zero.eCoreAverage)
        XCTAssertTrue(CPUMetrics.zero.topProcesses.isEmpty)
    }

    func testNetworkZeroHasNoRatesOrPrimaryInterface() {
        XCTAssertEqual(NetworkMetrics.zero.bytesInPerSec, 0)
        XCTAssertEqual(NetworkMetrics.zero.bytesOutPerSec, 0)
        XCTAssertEqual(NetworkMetrics.zero.totalBytesIn, 0)
        XCTAssertEqual(NetworkMetrics.zero.totalBytesOut, 0)
        XCTAssertNil(NetworkMetrics.zero.primaryInterface)
    }
}

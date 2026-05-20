import XCTest
@testable import LudeVitals

final class FmtTests: XCTestCase {
    func testBytesZero() {
        XCTAssertEqual(Fmt.bytes(0), "0 B")
    }

    func testBytesSubKB() {
        XCTAssertEqual(Fmt.bytes(512), "512 B")
        XCTAssertEqual(Fmt.bytes(1023), "1023 B")
    }

    func testBytesKB() {
        XCTAssertEqual(Fmt.bytes(1024), "1 KB")
        XCTAssertEqual(Fmt.bytes(2048), "2 KB")
        XCTAssertEqual(Fmt.bytes(1_048_575), "1024 KB")
    }

    func testBytesMB() {
        XCTAssertEqual(Fmt.bytes(1_048_576), "1 MB")
        XCTAssertEqual(Fmt.bytes(10_485_760), "10 MB")
    }

    func testBytesGB() {
        XCTAssertEqual(Fmt.bytes(1_073_741_824), "1.0 GB")
        XCTAssertEqual(Fmt.bytes(17_179_869_184), "16.0 GB")
    }

    func testRateZero() {
        XCTAssertEqual(Fmt.rate(0), "0 B/s")
    }

    func testRateKB() {
        XCTAssertEqual(Fmt.rate(1_500), "2 KB/s")
        XCTAssertEqual(Fmt.rate(999_999), "1000 KB/s")
    }

    func testRateMB() {
        XCTAssertEqual(Fmt.rate(1_000_000), "1.0 MB/s")
        XCTAssertEqual(Fmt.rate(2_500_000), "2.5 MB/s")
    }

    func testDurationZeroOrNegative() {
        XCTAssertEqual(Fmt.duration(minutes: 0), "n/a")
        XCTAssertEqual(Fmt.duration(minutes: -1), "n/a")
    }

    func testDurationSubHour() {
        XCTAssertEqual(Fmt.duration(minutes: 1), "1m")
        XCTAssertEqual(Fmt.duration(minutes: 59), "59m")
    }

    func testDurationHours() {
        XCTAssertEqual(Fmt.duration(minutes: 60), "1h 0m")
        XCTAssertEqual(Fmt.duration(minutes: 192), "3h 12m")
    }
}

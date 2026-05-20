import XCTest
@testable import LudeVitals

final class RingBufferTests: XCTestCase {
    func testEmptyBuffer() {
        let r = RingBuffer<Int>(capacity: 5)
        XCTAssertEqual(r.count, 0)
        XCTAssertNil(r.last)
        XCTAssertEqual(r.values, [])
    }

    func testAppendUnderCapacity() {
        var r = RingBuffer<Int>(capacity: 5)
        r.append(1); r.append(2); r.append(3)
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r.last, 3)
        XCTAssertEqual(r.values, [1, 2, 3])
    }

    func testAppendAtCapacity() {
        var r = RingBuffer<Int>(capacity: 3)
        r.append(1); r.append(2); r.append(3)
        XCTAssertEqual(r.values, [1, 2, 3])
        XCTAssertEqual(r.count, 3)
    }

    func testAppendOverCapacity_oldestEvicted() {
        var r = RingBuffer<Int>(capacity: 3)
        for i in 1...6 { r.append(i) }
        XCTAssertEqual(r.count, 3)
        XCTAssertEqual(r.values, [4, 5, 6])
        XCTAssertEqual(r.last, 6)
    }

    func testCapacityOneActsAsLatestCache() {
        var r = RingBuffer<String>(capacity: 1)
        r.append("a"); r.append("b"); r.append("c")
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.values, ["c"])
        XCTAssertEqual(r.last, "c")
    }

    func testZeroCapacityClampsToOne() {
        var r = RingBuffer<Int>(capacity: 0)
        XCTAssertEqual(r.capacity, 1)
        r.append(42)
        XCTAssertEqual(r.values, [42])
    }
}

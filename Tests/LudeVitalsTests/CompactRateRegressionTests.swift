import XCTest
@testable import LudeVitals

final class CompactRateRegressionTests: XCTestCase {
    private let figureSpace = "\u{2007}"

    func testCompactRateRoundingBoundaries() {
        XCTAssertEqual(MenuBarLabel.compactRate(999), figureSpace + figureSpace + "0K")
        XCTAssertEqual(MenuBarLabel.compactRate(1_000), figureSpace + figureSpace + "1K")

        XCTAssertEqual(MenuBarLabel.compactRate(999_499), "999K")
        XCTAssertEqual(MenuBarLabel.compactRate(999_500), "1.0M")

        XCTAssertEqual(MenuBarLabel.compactRate(9_949_999), "9.9M")
        XCTAssertEqual(MenuBarLabel.compactRate(9_950_000), figureSpace + "10M")

        XCTAssertEqual(MenuBarLabel.compactRate(999_499_999), "999M")
        XCTAssertEqual(MenuBarLabel.compactRate(999_500_000), "1.0G")

        XCTAssertEqual(MenuBarLabel.compactRate(9_949_999_999), "9.9G")
        XCTAssertEqual(MenuBarLabel.compactRate(9_950_000_000), figureSpace + "10G")
    }

    func testCompactRateCapsLargeValuesAtFourCharacters() {
        XCTAssertEqual(MenuBarLabel.compactRate(99_950_000_000), "100G")
        XCTAssertEqual(MenuBarLabel.compactRate(500_000_000_000), "100G")
        XCTAssertEqual(MenuBarLabel.compactRate(UInt64.max), "100G")
    }
}

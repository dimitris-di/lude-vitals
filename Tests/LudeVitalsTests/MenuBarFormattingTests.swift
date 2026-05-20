import XCTest
@testable import LudeVitals

final class MenuBarFormattingTests: XCTestCase {
    func testCompactRateBelowKB() {
        XCTAssertEqual(MenuBarLabel.compactRate(0), "\u{2007}\u{2007}0K")
        XCTAssertEqual(MenuBarLabel.compactRate(500), "\u{2007}\u{2007}0K")
    }

    func testCompactRateKB() {
        let s = MenuBarLabel.compactRate(2_500)
        XCTAssertTrue(s.hasSuffix("3K"))
        XCTAssertEqual(s.count, 4)
    }

    func testCompactRateMB() {
        XCTAssertEqual(MenuBarLabel.compactRate(1_200_000), "1.2M")
        XCTAssertEqual(MenuBarLabel.compactRate(1_200_000).count, 4)
    }

    func testCompactRateWidthConstant() {
        let widths = [0, 500, 999, 1_000, 999_999, 1_000_000, 50_000_000]
            .map { MenuBarLabel.compactRate(UInt64($0)).count }
        let unique = Set(widths)
        XCTAssertEqual(unique, [4], "compactRate must produce constant-width output")
    }
}

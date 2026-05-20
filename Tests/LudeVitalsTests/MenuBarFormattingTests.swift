import XCTest
@testable import LudeVitals

final class MenuBarFormattingTests: XCTestCase {
    func testCompactRateBelowKB() {
        XCTAssertEqual(MenuBarLabel.compactRate(0), "\u{2007}\u{2007}0K")
        XCTAssertEqual(MenuBarLabel.compactRate(500), "\u{2007}\u{2007}0K")
    }

    func testCompactRateKB() {
        let s = MenuBarLabel.compactRate(3_000)
        XCTAssertTrue(s.hasSuffix("3K"))
        XCTAssertEqual(s.count, 4)
    }

    func testCompactRateMB() {
        XCTAssertEqual(MenuBarLabel.compactRate(1_200_000), "1.2M")
        XCTAssertEqual(MenuBarLabel.compactRate(1_200_000).count, 4)
    }

    func testCompactRateWidthConstant() {
        let inputs: [UInt64] = [
            0, 500, 999,                          // sub-1K
            1_000, 999_499,                       // K tier
            999_500, 1_000_000, 9_949_999,        // M.M tier
            9_950_000, 10_000_000, 999_499_999,   // MM tier
            999_500_000, 1_000_000_000,           // G.G tier
            9_949_999_999,                        // G.G tier upper
            9_950_000_000, 50_000_000_000,        // GG tier
            99_950_000_000, 500_000_000_000       // capped
        ]
        let widths = inputs.map { MenuBarLabel.compactRate($0).count }
        let unique = Set(widths)
        XCTAssertEqual(unique, [4], "compactRate must produce constant-width output across all magnitudes; got widths: \(widths)")
    }
}

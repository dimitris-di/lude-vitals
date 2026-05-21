import Foundation
import XCTest

final class ReleaseMetadataTests: XCTestCase {
    func testVersionFileMatchesBundleShortVersion() throws {
        let version = try Self.versionFileString()
        let plist = try Self.infoPlist()
        let bundleVersion = try XCTUnwrap(plist["CFBundleShortVersionString"] as? String)

        XCTAssertEqual(bundleVersion, version)
        XCTAssertTrue(
            version.range(of: #"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"#, options: .regularExpression) != nil,
            "VERSION should be a semantic version"
        )
    }

    func testBundleBuildNumberIsPositiveInteger() throws {
        let plist = try Self.infoPlist()
        let build = try XCTUnwrap(plist["CFBundleVersion"] as? String)
        let buildNumber = try XCTUnwrap(Int(build))

        XCTAssertGreaterThan(buildNumber, 0)
    }

    func testBundleIdentityMatchesMenuBarAppRelease() throws {
        let plist = try Self.infoPlist()

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "LudeVitals")
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.lude.LudeVitals")
        XCTAssertEqual(plist["CFBundleName"] as? String, "LudeVitals")
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "LudeVitals")
        XCTAssertEqual(plist["CFBundlePackageType"] as? String, "APPL")
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
    }

    private static func versionFileString() throws -> String {
        let raw = try String(contentsOf: packageRoot.appendingPathComponent("VERSION"), encoding: .utf8)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: packageRoot.appendingPathComponent("Info.plist"))
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

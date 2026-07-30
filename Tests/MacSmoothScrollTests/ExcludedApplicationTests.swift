import Foundation
import XCTest
@testable import MacSmoothScroll

final class ExcludedApplicationTests: XCTestCase {
    func testResolvesNameAndBundleIdentifierWithoutRetainingPath() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let applicationURL = temporaryDirectory
            .appendingPathComponent("Example Editor.app", isDirectory: true)
        let contentsURL = applicationURL
            .appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contentsURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.example.Editor",
            "CFBundleDisplayName": "Example Editor"
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(
            to: contentsURL.appendingPathComponent("Info.plist")
        )

        XCTAssertEqual(
            try ExcludedApplication.resolve(at: applicationURL),
            ExcludedApplication(
                bundleIdentifier: "com.example.Editor",
                name: "Example Editor"
            )
        )
    }

    func testRejectsNonApplicationURL() {
        XCTAssertThrowsError(
            try ExcludedApplication.resolve(
                at: URL(fileURLWithPath: "/tmp/not-an-application.txt")
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Choose a macOS application with a valid bundle identifier."
            )
        }
    }
}

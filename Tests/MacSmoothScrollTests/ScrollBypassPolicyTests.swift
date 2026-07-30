import CoreGraphics
import XCTest
@testable import MacSmoothScroll

final class ScrollBypassPolicyTests: XCTestCase {
    private let policy = ScrollBypassPolicy()

    func testAssignedModifierTemporarilyBypassesSmoothing() {
        XCTAssertTrue(
            policy.shouldBypass(
                flags: .maskAlternate,
                modifier: .option,
                frontmostBundleIdentifier: nil,
                excludedBundleIdentifiers: []
            )
        )
    }

    func testNoneModifierNeverBypassesSmoothing() {
        XCTAssertFalse(
            policy.shouldBypass(
                flags: [.maskShift, .maskCommand, .maskControl, .maskAlternate],
                modifier: .none,
                frontmostBundleIdentifier: nil,
                excludedBundleIdentifiers: []
            )
        )
    }

    func testExcludedFrontmostApplicationBypassesSmoothing() {
        XCTAssertTrue(
            policy.shouldBypass(
                flags: [],
                modifier: .none,
                frontmostBundleIdentifier: "com.example.Editor",
                excludedBundleIdentifiers: ["com.example.Editor"]
            )
        )
    }

    func testUnknownOrUnlistedApplicationDoesNotBypassSmoothing() {
        XCTAssertFalse(
            policy.shouldBypass(
                flags: [],
                modifier: .none,
                frontmostBundleIdentifier: "com.example.Browser",
                excludedBundleIdentifiers: ["com.example.Editor"]
            )
        )
        XCTAssertFalse(
            policy.shouldBypass(
                flags: [],
                modifier: .none,
                frontmostBundleIdentifier: nil,
                excludedBundleIdentifiers: ["com.example.Editor"]
            )
        )
    }
}

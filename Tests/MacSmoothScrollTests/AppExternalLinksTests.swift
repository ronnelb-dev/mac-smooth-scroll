import Foundation
import XCTest
@testable import MacSmoothScroll

final class AppExternalLinksTests: XCTestCase {
    func testReleasesURLUsesThePublicHTTPSRepositoryPage() {
        XCTAssertEqual(AppExternalLinks.releases.scheme, "https")
        XCTAssertEqual(AppExternalLinks.releases.host, "github.com")
        XCTAssertEqual(
            AppExternalLinks.releases.path,
            "/ronnelb-dev/mac-smooth-scroll/releases"
        )
    }

    func testOpenReleasesUsesTheInjectedWorkspaceAction() {
        var openedURL: URL?

        let result = AppExternalLinks.openReleases { url in
            openedURL = url
            return true
        }

        XCTAssertTrue(result)
        XCTAssertEqual(openedURL, AppExternalLinks.releases)
    }

    func testOpenReleasesReportsWorkspaceFailure() {
        XCTAssertFalse(AppExternalLinks.openReleases { _ in false })
    }
}

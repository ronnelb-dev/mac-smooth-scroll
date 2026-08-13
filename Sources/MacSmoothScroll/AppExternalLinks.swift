import AppKit
import Foundation

enum AppExternalLinks {
    static let releases = URL(
        string: "https://github.com/ronnelb-dev/mac-smooth-scroll/releases"
    )!

    @discardableResult
    static func openReleases(
        using opener: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        opener(releases)
    }
}

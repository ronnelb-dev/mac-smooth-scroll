import CoreGraphics
import Foundation

struct ScrollBypassPolicy {
    func shouldBypass(
        flags: CGEventFlags,
        modifier: ModifierKey,
        frontmostBundleIdentifier: String?,
        excludedBundleIdentifiers: Set<String>
    ) -> Bool {
        if modifier.isActive(in: flags) {
            return true
        }

        guard let frontmostBundleIdentifier else {
            return false
        }
        return excludedBundleIdentifiers.contains(frontmostBundleIdentifier)
    }
}

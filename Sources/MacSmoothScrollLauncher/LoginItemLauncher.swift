import Foundation

struct LoginItemLauncher {
    static let maximumAttempts = 4
    static let retryDelayNanoseconds: UInt64 = 750_000_000

    static func mainApplicationURL(from helperBundleURL: URL) -> URL {
        helperBundleURL
            .deletingLastPathComponent() // LoginItems
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // Mac Smooth Scroll.app
    }

    static func launch(
        maximumAttempts: Int = maximumAttempts,
        retryDelayNanoseconds: UInt64 = retryDelayNanoseconds,
        openApplication: () async throws -> Void,
        sleep: (UInt64) async -> Void = { delay in
            try? await Task.sleep(nanoseconds: delay)
        }
    ) async throws {
        precondition(maximumAttempts > 0)

        var lastError: Error?
        for attempt in 1...maximumAttempts {
            do {
                try await openApplication()
                return
            } catch {
                lastError = error
                guard attempt < maximumAttempts else { break }
                await sleep(retryDelayNanoseconds * UInt64(attempt))
            }
        }

        throw lastError!
    }
}

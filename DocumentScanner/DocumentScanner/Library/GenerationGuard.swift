import Foundation

/// Guards against out-of-order async results overwriting newer ones.
///
/// When several async refreshes overlap — e.g. rapid iCloud `NSMetadataQuery`
/// notifications, each spawning a detached build that reads files off disk —
/// they can finish out of order. Without a guard the LAST task to complete wins,
/// even if it carries a STALE snapshot, so documents can flash in and then
/// vanish.
///
/// Each refresh takes a token from `begin()`. A completing task applies its
/// result only while `isCurrent(token)` still holds; a newer `begin()`
/// invalidates every prior token.
@MainActor
final class GenerationGuard {
    private var current = 0

    /// Starts a new generation and returns its token, invalidating all prior ones.
    func begin() -> Int {
        current &+= 1
        return current
    }

    /// True only for the token from the most recent `begin()`.
    func isCurrent(_ token: Int) -> Bool { token == current }
}

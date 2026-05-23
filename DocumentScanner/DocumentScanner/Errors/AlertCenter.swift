import Foundation
import Observation

/// Thin presenter for user-facing alerts. A single instance lives at the
/// app root and is bound by a `.alert` modifier. Any view or service that
/// needs to surface an error reaches it via `@Environment` or by passing
/// it explicitly.
@MainActor
@Observable
final class AlertCenter {
    private(set) var current: AppAlert?

    func present(_ alert: AppAlert) { current = alert }
    func dismiss() { current = nil }
}

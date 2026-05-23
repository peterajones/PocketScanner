import Foundation
import Observation
import SwiftUI

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

private struct AlertCenterKey: EnvironmentKey {
    @MainActor static let defaultValue = AlertCenter()
}

extension EnvironmentValues {
    var alertCenter: AlertCenter {
        get { self[AlertCenterKey.self] }
        set { self[AlertCenterKey.self] = newValue }
    }
}

import AVFoundation

/// Lightweight wrapper around AVFoundation's camera authorization API.
struct CameraPermission {

    enum Status { case authorized, denied, notDetermined }

    /// Synchronous current status. Use this when deciding which UI to show.
    static var current: Status {
        if isUITesting { return .authorized }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    /// Trigger the system permission prompt when status is .notDetermined.
    /// Returns the resulting status. Has no effect if status is already
    /// .authorized or .denied.
    static func request() async -> Status {
        if isUITesting { return .authorized }
        if current != .notDetermined { return current }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return current
    }

    /// In hermetic UI-test mode (`-UITestMode`) the scanner is stubbed
    /// (`StubDocumentScanner`), so there is no real camera to authorize. Treat
    /// permission as granted so the stub presents deterministically instead of
    /// depending on the real system permission dialog + a flaky interruption
    /// monitor. Matches how the app already stubs the scanner / store / lock
    /// gate under the same flag.
    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestMode")
    }
}

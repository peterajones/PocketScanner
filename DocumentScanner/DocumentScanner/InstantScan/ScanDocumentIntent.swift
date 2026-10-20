import AppIntents

/// The only thing the scan intent can "open". `OpenIntent` requires a target;
/// the system foregrounds the app for it.
enum ScanTarget: String, AppEnum {
    case scanner

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Scanner")
    static let caseDisplayRepresentations: [ScanTarget: DisplayRepresentation] = [
        .scanner: DisplayRepresentation(title: "Scanner")
    ]
}

/// Starts an instant scan: the app comes to the foreground and presents the
/// camera. Shared by Siri/Spotlight, the Action button and the Control.
struct ScanDocumentIntent: OpenIntent {
    static let title: LocalizedStringResource = "Scan Document"

    @Parameter(title: "Target")
    var target: ScanTarget

    init() {
        target = .scanner
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // The Controls extension compiles this file too, but the system runs
        // an OpenIntent in the app, so only the app's copy does the work.
        #if !CONTROLS_EXTENSION
        InstantScanCoordinator.shared.request()
        #endif
        return .result()
    }
}

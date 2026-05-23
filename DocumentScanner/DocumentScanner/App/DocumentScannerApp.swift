import SwiftUI

@main
struct DocumentScannerApp: App {
    @State private var store = MetadataQueryLibraryStore()
    @State private var lockSettings = AppLockSettings()
    @State private var alertCenter = AlertCenter()
    @AppStorage("iCloudOnboardingDismissed") private var iCloudOnboardingDismissed = false

    private let container = ICloudContainer()
    private let pipeline = ScanPipeline()
    private let scannerPresenter: DocumentScannerPresenting = SystemDocumentScanner()

    var body: some Scene {
        WindowGroup {
            if !iCloudOnboardingDismissed && !container.isICloudAvailable {
                ICloudOnboardingView(onTryAnyway: { iCloudOnboardingDismissed = true })
                    .environment(\.alertCenter, alertCenter)
            } else {
                LockGate(lockSettings: lockSettings) {
                    PrivacyBlurOverlay {
                        LibraryView(
                            store: store,
                            scannerPresenter: scannerPresenter,
                            storage: DocumentStorage(documentsURL: container.resolveDocumentsURL()),
                            pipeline: pipeline,
                            lockSettings: lockSettings
                        )
                    }
                }
                .environment(\.alertCenter, alertCenter)
                .alert(item: Binding(
                    get: { alertCenter.current },
                    set: { _ in alertCenter.dismiss() }
                )) { alert in
                    appAlert(alert)
                }
            }
        }
    }

    @MainActor
    private func appAlert(_ alert: AppAlert) -> Alert {
        let primaryButton = button(from: alert.primary)
        if let secondary = alert.secondary {
            return Alert(title: Text(alert.title),
                         message: Text(alert.message),
                         primaryButton: primaryButton,
                         secondaryButton: button(from: secondary))
        }
        return Alert(title: Text(alert.title),
                     message: Text(alert.message),
                     dismissButton: primaryButton)
    }

    private func button(from action: AppAlert.Action) -> Alert.Button {
        switch action.role {
        case .cancel:
            return .cancel(Text(action.title)) { action.handler?() }
        case .destructive:
            return .destructive(Text(action.title)) { action.handler?() }
        case .default:
            return .default(Text(action.title)) { action.handler?() }
        }
    }
}

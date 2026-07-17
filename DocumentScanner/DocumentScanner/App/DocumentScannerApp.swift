import SwiftUI

@main
struct DocumentScannerApp: App {
    @State private var metadataStore = MetadataQueryLibraryStore()
    @State private var localStore: InMemoryLibraryStore
    @State private var inMemoryStore: InMemoryLibraryStore
    @State private var lockSettings = AppLockSettings()
    @State private var alertCenter = AlertCenter()
    @AppStorage("iCloudOnboardingDismissed") private var iCloudOnboardingDismissed = false

    private let container = ICloudContainer()
    private let pipeline = ScanPipeline()
    private let scannerPresenter: DocumentScannerPresenting =
        isUITesting ? StubDocumentScanner() : SystemDocumentScanner()
    private let testStorage: DocumentStorage

    /// Cached once at launch. `container.isICloudAvailable` calls
    /// `FileManager.url(forUbiquityContainerIdentifier:)`, which can block.
    /// SwiftUI re-evaluates `body` on every state change, so caching avoids
    /// repeating that blocking call.
    private let iCloudAvailable: Bool
    private let resolvedDocumentsURL: URL

    init() {
        iCloudAvailable = container.isICloudAvailable
        resolvedDocumentsURL = container.resolveDocumentsURL()

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("uitests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        testStorage = DocumentStorage(documentsURL: tmp)
        // Point the in-memory store at the same temp dir the stub storage
        // writes to, so refresh() picks up new PDFs the test creates.
        let store = InMemoryLibraryStore()
        store.documentsURL = tmp
        _inMemoryStore = State(initialValue: store)

        // Local-mode fallback: when iCloud isn't available, the library
        // list scans the app's local Documents directory directly.
        // MetadataQueryLibraryStore only queries the iCloud scope, so
        // without this, local scans save successfully but never appear.
        let local = InMemoryLibraryStore()
        local.documentsURL = container.localDocumentsURL
        _localStore = State(initialValue: local)

        #if DEBUG
        if DemoSeeder.isRequested {
            DemoSeeder(documentsURL: container.localDocumentsURL).seed()
        }
        #endif
    }

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestMode")
    }

    var body: some Scene {
        WindowGroup {
            Group {
            if Self.isUITesting {
                // Hermetic wiring: no iCloud, no real scanner, no lock gate.
                LibraryView(
                    store: inMemoryStore,
                    scannerPresenter: scannerPresenter,
                    storage: testStorage,
                    pipeline: pipeline,
                    lockSettings: lockSettings
                )
                .environment(\.alertCenter, alertCenter)
            } else if !iCloudOnboardingDismissed && !iCloudAvailable {
                ICloudOnboardingView(onTryAnyway: { iCloudOnboardingDismissed = true })
                    .environment(\.alertCenter, alertCenter)
            } else if iCloudAvailable {
                // iCloud path: NSMetadataQuery sees ubiquitous documents.
                LockGate(lockSettings: lockSettings) {
                    PrivacyBlurOverlay {
                        LibraryView(
                            store: metadataStore,
                            scannerPresenter: scannerPresenter,
                            storage: DocumentStorage(documentsURL: resolvedDocumentsURL),
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
            } else {
                // Local-only path: directory-scan store sees the app sandbox.
                // Used when the user dismissed iCloud onboarding without
                // signing in. Without this branch the library list was
                // permanently empty for these users.
                LockGate(lockSettings: lockSettings) {
                    PrivacyBlurOverlay {
                        LibraryView(
                            store: localStore,
                            scannerPresenter: scannerPresenter,
                            storage: DocumentStorage(documentsURL: container.localDocumentsURL),
                            pipeline: pipeline,
                            lockSettings: lockSettings
                        )
                        .task { localStore.refresh() }
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
            .touchIndicators()
            .onOpenURL { url in handleIncomingPDF(url) }
        }
    }

    /// Imports a PDF opened from another app (Mail/Files/Safari) into the library
    /// root, then refreshes the active store. Errors surface via the alert center.
    private func handleIncomingPDF(_ url: URL) {
        guard url.pathExtension.lowercased() == "pdf" else { return }
        let storage = DocumentStorage(documentsURL: resolvedDocumentsURL)
        do {
            _ = try PDFImporter.importPDF(from: url, using: storage)
            if iCloudAvailable { metadataStore.refresh() } else { localStore.refresh() }
        } catch {
            alertCenter.present(AppAlert(
                title: String(localized: "Couldn't Import"),
                message: String(localized: "That file isn't a readable PDF.")))
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

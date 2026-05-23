import SwiftUI

@main
struct DocumentScannerApp: App {
    @State private var store = MetadataQueryLibraryStore()
    @State private var lockSettings = AppLockSettings()

    private let container = ICloudContainer()
    private let pipeline = ScanPipeline()
    private let scannerPresenter: DocumentScannerPresenting = SystemDocumentScanner()

    var body: some Scene {
        WindowGroup {
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
        }
    }
}

import AppIntents

/// Makes "Scan with Pocket Scanner" available to Siri and Spotlight with no
/// setup by the user.
struct PocketScannerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan with \(.applicationName)",
                "Scan a document with \(.applicationName)"
            ],
            shortTitle: "Scan Document",
            systemImageName: "doc.viewfinder"
        )
    }
}

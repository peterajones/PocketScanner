import AppIntents
import SwiftUI
import WidgetKit

/// "Scan Document" for Control Center, the lock screen and the Action button.
/// Tapping it runs `ScanDocumentIntent`, which opens the app straight into the camera.
struct ScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ca.peter-jones.DocumentScanner.ScanControl") {
            ControlWidgetButton(action: ScanDocumentIntent()) {
                Label("Scan Document", systemImage: "doc.viewfinder")
            }
        }
        .displayName("Scan Document")
        .description("Open Pocket Scanner straight into the camera.")
    }
}

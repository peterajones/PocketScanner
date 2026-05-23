import SwiftUI
import UIKit

struct ICloudOnboardingView: View {
    let onTryAnyway: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("iCloud Drive recommended")
                .font(.title2.weight(.semibold))
            Text("Mobile Scanner syncs your documents across devices through iCloud Drive. You can use the app without it — scans will stay on this device only.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Try anyway (local only)", action: onTryAnyway)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

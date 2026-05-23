import SwiftUI

/// Covers content with a system material blur whenever the scene is not
/// `.active`. Used to redact document names and thumbnails from the iOS
/// app-switcher snapshot, independently of the App Lock state.
struct PrivacyBlurOverlay<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            content()
            if scenePhase != .active {
                // Opaque material so the underlying content is fully hidden,
                // not just softened.
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea()
                    .overlay {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

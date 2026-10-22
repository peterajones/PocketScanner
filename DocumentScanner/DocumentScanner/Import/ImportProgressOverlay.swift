import SwiftUI

/// Where an import's OCR has got to: page `current` of the `total` pages that had no
/// text layer.
struct ImportProgress: Equatable {
    var current: Int
    var total: Int
}

/// Dims the screen and blocks touches while an imported PDF's text-less pages are
/// recognized. Shows no page content, so it is safe above the app lock.
struct ImportProgressOverlay: View {
    let progress: ImportProgress

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: Double(progress.current), total: Double(progress.total))
                    .frame(width: 200)
                Text("Processing page \(progress.current) of \(progress.total)")
                    .font(.subheadline)
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }
}

#Preview {
    ImportProgressOverlay(progress: ImportProgress(current: 2, total: 5))
}

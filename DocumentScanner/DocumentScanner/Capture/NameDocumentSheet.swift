import SwiftUI
import PDFKit

/// Modal shown after capture. Shows a page-1 filter preview + picker and lets the
/// user name the document while OCR runs in the background; Save applies the chosen
/// filter to every page and writes the assembled PDF to disk.
struct NameDocumentSheet: View {
    let images: [UIImage]
    let recognizeTask: Task<[ScannedPage], Never>
    let pipeline: ScanPipeline
    let storage: DocumentStorage
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var name: String = DefaultDocumentName.fallback()
    @State private var hasUserEdited = false
    @State private var isWorking = false
    @State private var filter: ImageFilter = .none
    @State private var previewBase: UIImage?     // downscaled page 1
    @State private var previewImage: UIImage?    // previewBase with `filter` applied
    private let filterEngine = ImageFilterEngine()
    @Environment(\.alertCenter) private var alertCenter

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 280)
                            .accessibilityIdentifier("NameSheet.Preview")
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                Section("Filter") {
                    Picker("Filter", selection: $filter) {
                        ForEach(ImageFilter.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(isWorking)
                    .accessibilityIdentifier("NameSheet.FilterPicker")
                }
                Section("Name") {
                    TextField("Name", text: Binding(
                        get: { name },
                        set: { newValue in
                            hasUserEdited = true
                            name = newValue
                        }
                    ))
                        .textInputAutocapitalization(.words)
                        .disabled(isWorking)
                        .accessibilityIdentifier("NameSheet.NameField")
                }
            }
            .navigationTitle("Save Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recognizeTask.cancel()
                        onCancel()
                    }
                    .disabled(isWorking)
                    .accessibilityIdentifier("NameSheet.Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("NameSheet.Save")
                    }
                }
            }
            .task { await refineDefaultName() }
            .task { await loadPreviewBase() }
            .onChange(of: filter) { _, _ in applyFilterToPreview() }
            .onDisappear { recognizeTask.cancel() }
        }
        .interactiveDismissDisabled(isWorking)
    }

    /// While OCR runs, the sheet shows a timestamp default. Once recognition
    /// finishes, swap in a smarter name — but only if the user hasn't already
    /// started typing their own.
    private func refineDefaultName() async {
        let pages = await recognizeTask.value
        guard !hasUserEdited else { return }
        let ocrText = pages.flatMap(\.observations).map(\.string).joined(separator: "\n")
        if let suggestion = DefaultDocumentName.suggest(from: ocrText) {
            name = suggestion
        }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let pages = await recognizeTask.value
            let result = try await pipeline.assemble(pages: pages, filter: filter)
            _ = try storage.write(result.pdf, preferredName: name)
            onSaved()
        } catch {
            alertCenter.present(AppAlert(
                title: "Couldn't save",
                message: error.localizedDescription,
                primary: AppAlert.Action(title: "Retry", role: .default, handler: {
                    Task { await save() }
                }),
                secondary: AppAlert.Action(title: "Cancel", role: .cancel, handler: {
                    onCancel()
                })
            ))
        }
    }

    /// Downscale page 1 so live filtering stays snappy regardless of scan size.
    /// `byPreparingThumbnail` does the resize off the main thread and is
    /// concurrency-safe, so there's no main-thread hitch and no non-Sendable
    /// UIImage capture.
    private func loadPreviewBase() async {
        guard let first = images.first else { return }
        let target = Self.previewSize(for: first.size, maxDimension: 1000)
        let base = await first.byPreparingThumbnail(ofSize: target) ?? first
        previewBase = base
        previewImage = base   // filter defaults to .none
    }

    private func applyFilterToPreview() {
        guard let base = previewBase else { return }
        previewImage = filterEngine.apply(filter, to: base) ?? base
    }

    /// Aspect-preserving target size whose longest side is at most `maxDimension`.
    private static func previewSize(for size: CGSize, maxDimension: CGFloat) -> CGSize {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return size }
        let scale = maxDimension / longest
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

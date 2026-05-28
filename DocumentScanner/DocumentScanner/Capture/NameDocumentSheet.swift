import SwiftUI
import PDFKit

/// Modal shown after capture. Lets the user name the document while the pipeline
/// processes in the background. Save waits for the pipeline (showing a spinner)
/// before writing to disk.
struct NameDocumentSheet: View {
    let pipelineTask: Task<ScanResult, Error>
    let storage: DocumentStorage
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var name: String = DefaultDocumentName.fallback()
    @State private var hasUserEdited = false
    @State private var isWorking = false
    @Environment(\.alertCenter) private var alertCenter

    var body: some View {
        NavigationStack {
            Form {
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
                        pipelineTask.cancel()
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
        }
        .interactiveDismissDisabled(isWorking)
    }

    /// While OCR runs, the sheet shows a timestamp default. Once the pipeline
    /// produces text, swap in a smarter name — but only if the user hasn't
    /// already started typing their own.
    private func refineDefaultName() async {
        guard let result = try? await pipelineTask.value else { return }
        guard !hasUserEdited else { return }
        if let suggestion = DefaultDocumentName.suggest(from: result.ocrText) {
            name = suggestion
        }
    }

    private func save() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await pipelineTask.value
            _ = try storage.write(result.pdf, preferredName: name)
            onSaved()
        } catch is CancellationError {
            onCancel()
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

}

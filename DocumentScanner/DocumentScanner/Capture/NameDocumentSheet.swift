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

    @State private var name: String = NameDocumentSheet.defaultName()
    @State private var isWorking = false
    @Environment(\.alertCenter) private var alertCenter

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
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
        }
        .interactiveDismissDisabled(isWorking)
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

    private static func defaultName() -> String {
        let f = DateFormatter()
        f.dateFormat = "'Scan' yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }
}

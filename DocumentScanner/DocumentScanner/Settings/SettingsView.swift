import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var lockSettings: AppLockSettings
    let scannerPresenter: DocumentScannerPresenting
    @State private var authError: String?
    @State private var signatureThumbnail: UIImage?
    @State private var showingSignatureCapture = false
    private let signatureStore = SignatureStore()
    @AppStorage("showFolders") private var showFolders = true
    #if DEBUG
    @AppStorage(TouchIndicatorSettings.key) private var touchIndicatorsEnabled = TouchIndicatorSettings.defaultEnabled
    #endif

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("App Lock", isOn: Binding(
                    get: { lockSettings.isEnabled },
                    set: { newValue in Task { await toggleLock(to: newValue) } }
                ))
                if let authError {
                    Text(authError).font(.footnote).foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Show Folders", isOn: $showFolders)
            } header: {
                Text("Library")
            } footer: {
                Text("When off, all documents appear in a single flat list.")
            }
            #if DEBUG
            Section {
                Toggle("Touch Indicators", isOn: $touchIndicatorsEnabled)
            } header: {
                Text("Developer")
            } footer: {
                Text("Shows a circle at each touch — for recording App Preview videos. Debug builds only.")
            }
            #endif
            Section {
                if let signatureThumbnail {
                    HStack {
                        Image(uiImage: signatureThumbnail).resizable().scaledToFit()
                            .frame(height: 40)
                        Spacer()
                    }
                    Button("Replace Signature") { showingSignatureCapture = true }
                    Button("Remove Signature", role: .destructive) {
                        signatureStore.clear(); self.signatureThumbnail = nil
                    }
                } else {
                    Button("Add Signature") { showingSignatureCapture = true }
                }
            } header: {
                Text("Signature")
            } footer: {
                Text("Scan your signature once on paper, then reuse it to sign any document.")
            }
            Section("About") {
                NavigationLink {
                    TipsView()
                } label: {
                    Label("Tips", systemImage: "lightbulb")
                }
                AboutRow()
                SendFeedbackRow()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { signatureThumbnail = signatureStore.load() }
        .sheet(isPresented: $showingSignatureCapture) {
            SignatureCaptureView(
                presenter: scannerPresenter,
                store: signatureStore,
                onSaved: { showingSignatureCapture = false; signatureThumbnail = signatureStore.load() },
                onCancel: { showingSignatureCapture = false }
            )
        }
    }

    /// Toggle the lock setting — but require successful auth before applying.
    /// Spec: "Enabling and disabling the lock both require successful
    /// authentication first."
    private func toggleLock(to newValue: Bool) async {
        let reason = newValue
            ? "Enable App Lock for your document library"
            : "Disable App Lock for your document library"
        let ok = await lockSettings.authenticate(reason: reason)
        if ok {
            lockSettings.isEnabled = newValue
            authError = nil
        } else {
            authError = "Face ID failed. Try again."
            // No need to manually revert — the Toggle binding's `get` still
            // reads the unchanged isEnabled.
        }
    }
}

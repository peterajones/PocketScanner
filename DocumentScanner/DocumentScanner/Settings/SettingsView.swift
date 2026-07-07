import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var lockSettings: AppLockSettings
    @State private var authError: String?
    @State private var signatures: [Signature] = []
    @State private var showingSignatureCapture = false
    @State private var renamingID: String?
    @State private var renameField = ""
    private let signatureStore = SignatureStore()
    @AppStorage("showFolders") private var showFolders = true
    @AppStorage("defaultScanFilter") private var defaultScanFilterRaw = ImageFilter.none.rawValue
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
            Section {
                Picker("Default Filter", selection: $defaultScanFilterRaw) {
                    ForEach(ImageFilter.allCases) { f in
                        Text(f.displayName).tag(f.rawValue)
                    }
                }
            } header: {
                Text("Scanning")
            } footer: {
                Text("New scans start with this filter. You can still change it for any scan.")
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
                ForEach(signatures) { sig in
                    HStack(spacing: 12) {
                        Image(uiImage: sig.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 32)
                            .padding(6)
                            .background(Color.white)   // black ink on transparent — visible in dark mode
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
                        if let name = sig.name, !name.isEmpty {
                            Text(name).lineLimit(1).truncationMode(.tail)
                        } else {
                            Text("Add a name").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { beginRename(sig) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            signatureStore.remove(id: sig.id)
                            signatures = signatureStore.all()
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
                Button("Add Signature") { showingSignatureCapture = true }
            } header: {
                Text("Signature")
            } footer: {
                Text("Scan your signature on paper, then reuse it to sign any document. Add more than one — you'll pick which to place.")
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
        .onAppear { signatures = signatureStore.all() }
        .sheet(isPresented: $showingSignatureCapture) {
            SignatureCaptureView(
                presenter: SingleShotCameraScanner(),
                store: signatureStore,
                onSaved: { showingSignatureCapture = false; signatures = signatureStore.all() },
                onCancel: { showingSignatureCapture = false }
            )
        }
        .alert("Rename Signature",
               isPresented: Binding(
                get: { renamingID != nil },
                set: { if !$0 { renamingID = nil; renameField = "" } }
               )) {
            TextField("Name", text: $renameField)
                .autocorrectionDisabled()
                .onChange(of: renameField) { _, new in
                    if new.count > 40 { renameField = String(new.prefix(40)) }
                }
            Button("Rename") { commitRename() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this signature a name so you can tell it apart when signing.")
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

    private func beginRename(_ sig: Signature) {
        renameField = sig.name ?? ""
        renamingID = sig.id
    }

    private func commitRename() {
        guard let id = renamingID else { return }
        signatureStore.rename(id: id, to: renameField)
        signatures = signatureStore.all()
        renamingID = nil
    }
}

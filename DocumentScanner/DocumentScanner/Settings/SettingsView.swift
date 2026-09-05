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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw = AppearanceMode.system.rawValue
    @AppStorage(AccentTint.storageKey) private var accentTintRaw = AccentTint.purple.rawValue
    @AppStorage("showFolders") private var showFolders = true
    @AppStorage("defaultScanFilter") private var defaultScanFilterRaw = ImageFilter.none.rawValue
    @AppStorage("scanPaperSize") private var scanPaperSizeRaw = PaperSize.auto.rawValue
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
                Picker("Page Size", selection: $scanPaperSizeRaw) {
                    ForEach(PaperSize.allCases) { p in
                        Text(p.displayName).tag(p.rawValue)
                    }
                }
            } header: {
                Text("Scanning")
            } footer: {
                Text("New scans start with this filter. You can still change it for any scan.\n\nPage Size sets the paper size of the PDF. Auto keeps the shape the scanner found; US Letter and A4 produce exactly that size, adding margins if the scan is a different shape.")
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
                // Three separate keys, NOT a String Catalog plural variation. Xcode
                // rejects a plural whose text does not reference the number:
                //
                //   "Plural variation requires referencing the number in the string. To
                //    maintain grammatical correctness for strings that do not reference
                //    the number of items, use separate top-level strings for one and
                //    greater than one."
                //
                // Plural variations exist to agree with a quantity that is DISPLAYED. This
                // header shows no number, so a switch in code is the right tool and each
                // form is translated independently -- which still lets French and Italian
                // go singular at zero ("Aucune signature", "Nessuna firma") while German
                // stays plural ("Keine Unterschriften").
                switch signatures.count {
                case 0:  Text("No Signatures")
                case 1:  Text("Signature")
                default: Text("Signatures")
                }
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
            // LAST, after About. Appearance is its own section because it changes how the
            // app LOOKS, while Privacy / Library / Scanning / Signature change what it
            // DOES. It sits below About because Tips and Send Feedback are things a user
            // might NEED — one to learn the app, one to reach Peter — and a theme picker
            // is a preference. Needs above preferences.
            Section {
                Picker("Theme", selection: $appearanceModeRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                // Shares the "Color" key with ImageFilter's no-filter option. Xcode
                // harvests the catalog comment from the String(localized:) call in
                // ImageFilter.swift, so that comment names both uses — otherwise it
                // regenerates as "Scan filter name" and a translator loses the context
                // that this also labels a colour picker.
                Picker("Color", selection: $accentTintRaw) {
                    ForEach(AccentTint.allCases) { tint in
                        // A swatch beside the name: the colour is the point, and it shows
                        // the value for the scheme the user is actually in.
                        Label {
                            Text(tint.displayName)
                        } icon: {
                            Circle()
                                .fill(tint.swatch(for: colorScheme))
                                .frame(width: 18, height: 18)
                        }
                        .tag(tint.rawValue)
                    }
                }
            } header: {
                Text("App Appearance")
            } footer: {
                Text("System follows your iPhone's light or dark setting.")
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

import SwiftUI
import Foundation

struct ConflictResolutionView: View {
    @Bindable var session: DocumentSession
    let onResolved: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("This device's version") {
                    Button {
                        do {
                            try session.resolveConflict(keeping: nil)
                            onResolved()
                        } catch { }
                    } label: {
                        Label("Keep this version", systemImage: "iphone")
                    }
                }
                Section("Other devices") {
                    ForEach(session.conflicts, id: \.self) { version in
                        Button {
                            do {
                                try session.resolveConflict(keeping: version)
                                onResolved()
                            } catch { }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(version.localizedName ?? "Unknown device")
                                if let date = version.modificationDate {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Two versions exist")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

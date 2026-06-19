import SwiftUI

/// A findable list of short in-app tips, reached from Settings ▸ About ▸ Tips.
/// Content lives in `Tip.all`; this view only renders it.
struct TipsView: View {
    var body: some View {
        List {
            ForEach(Tip.all) { tip in
                Section {
                    Text(tip.body)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(tip.title)
                }
            }
        }
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

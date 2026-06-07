import SwiftUI

/// Toolbar menu for choosing the document sort. The active key shows a
/// direction chevron; tapping a different key switches to it, tapping the
/// active key flips its direction. The caller owns the `DocumentSort` state
/// (persisted in @AppStorage) and applies the change via `onSelect`.
struct SortMenu: View {
    let sort: DocumentSort
    let onSelect: (SortKey) -> Void

    var body: some View {
        Menu {
            ForEach(SortKey.allCases, id: \.self) { key in
                Button {
                    onSelect(key)
                } label: {
                    if key == sort.key {
                        Label(key.title,
                              systemImage: sort.ascending ? "chevron.up" : "chevron.down")
                    } else {
                        Text(key.title)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityIdentifier("Library.SortMenu")
    }
}

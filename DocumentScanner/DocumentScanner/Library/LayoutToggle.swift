import SwiftUI

/// Toolbar button toggling between list and grid layout. Shows the icon of the
/// layout you'd switch TO.
struct LayoutToggle: View {
    let usesGrid: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: usesGrid ? "list.bullet" : "square.grid.2x2")
        }
        .accessibilityLabel(usesGrid ? "List view" : "Grid view")
        .accessibilityIdentifier("Library.LayoutToggle")
    }
}

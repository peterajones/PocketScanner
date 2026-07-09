import SwiftUI

/// Sheet for adding a date stamp: pick a date (defaults to today) and a format.
/// The format rows preview the currently-selected date live; the last-used format
/// is checkmarked and persisted. Tapping a format row is the confirm.
struct AddDateSheet: View {
    @AppStorage("dateStampFormat") private var lastFormatRaw = DateStampFormat.iso.rawValue
    @State private var selectedDate = Date()

    /// Called with the chosen date + format when a format row is tapped.
    let onPick: (Date, DateStampFormat) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)

                Section("Format") {
                    ForEach(DateStampFormat.allCases) { format in
                        Button {
                            lastFormatRaw = format.rawValue
                            onPick(selectedDate, format)
                        } label: {
                            HStack {
                                Text(format.string(for: selectedDate))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if format.rawValue == lastFormatRaw {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("AddDate.Format.\(format.rawValue)")
                    }
                }
            }
            .navigationTitle("Add Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
            }
        }
    }
}

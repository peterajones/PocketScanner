import SwiftUI

struct AboutRow: View {
    var body: some View {
        HStack {
            Text("Version")
            Spacer()
            Text(versionString)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

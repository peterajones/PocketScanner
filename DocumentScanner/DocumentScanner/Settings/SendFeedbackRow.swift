import SwiftUI
import UIKit

struct SendFeedbackRow: View {
    var body: some View {
        Link(destination: mailURL) {
            HStack {
                Text("Send Feedback")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "envelope")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mailURL: URL {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let iOSVersion = UIDevice.current.systemVersion
        let device = UIDevice.current.model

        let subject = "Pocket Scanner \(version) feedback"
        let body = """


        ---
        App: Pocket Scanner \(version) (\(build))
        iOS: \(iOSVersion)
        Device: \(device)
        """

        let allowed = CharacterSet.urlQueryAllowed
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let urlString = "mailto:peterjones@mac.com?subject=\(encodedSubject)&body=\(encodedBody)"

        return URL(string: urlString) ?? URL(string: "mailto:peterjones@mac.com")!
    }
}

import Foundation

/// A user-facing alert. `primary` is the default action; `secondary` is
/// optional (e.g., for a destructive choice in a confirmation alert).
struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let primary: Action
    let secondary: Action?

    static func == (lhs: AppAlert, rhs: AppAlert) -> Bool { lhs.id == rhs.id }

    struct Action: Equatable {
        let title: String
        let role: Role
        let handler: (@MainActor () -> Void)?

        enum Role { case `default`, cancel, destructive }

        static func == (lhs: Action, rhs: Action) -> Bool {
            lhs.title == rhs.title && lhs.role == rhs.role
        }
    }

    init(title: String,
         message: String,
         primary: Action = Action(title: String(localized: "OK"), role: .default, handler: nil),
         secondary: Action? = nil) {
        self.title = title
        self.message = message
        self.primary = primary
        self.secondary = secondary
    }
}

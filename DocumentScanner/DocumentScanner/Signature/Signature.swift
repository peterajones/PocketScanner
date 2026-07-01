import UIKit

/// One saved signature. `id` is the on-disk filename stem (a UUID), so the store
/// and placed annotations can reference a specific signature. `name` is an
/// optional user-supplied label (nil when unnamed).
struct Signature: Identifiable {
    let id: String
    let image: UIImage
    var name: String? = nil
}

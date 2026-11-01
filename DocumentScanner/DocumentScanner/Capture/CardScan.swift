import UIKit

/// Card scans: a wallet-sized card (licence, health card) scanned on its own is offered
/// a second capture for its back, and the two sides are stitched into one page, front
/// above back — the composite people otherwise assemble by hand. Passports and paper
/// are left alone.
///
/// Pure logic, so the shape rule, the offer and the layout are unit-tested; the library
/// and folder screens only ask and act on the answer. Instant Scan never asks: it saves
/// silently by design.
enum CardScan {

    /// ID-1, the wallet-card standard: 85.6 × 54 mm.
    static let cardAspect: CGFloat = 85.6 / 54

    /// The scanner's crop is a few percent out either way. ±5% takes 1.51–1.66, which
    /// keeps out a 4×6 photo (1.5) and a business card (1.75).
    static let aspectTolerance: CGFloat = 0.05

    /// Gap between the two sides, as a fraction of the page width.
    static let gapFraction: CGFloat = 0.04

    enum Offer: Equatable {
        /// One card-shaped page: offer to capture its back.
        case scanBack
        /// Two card-shaped pages captured together: offer to stitch them.
        case combine
        case none
    }

    /// What a prompt button does.
    enum Choice: Equatable {
        case scanBack, continueWithFront, combine, keepAsTwoPages
    }

    struct PromptButton: Equatable {
        let choice: Choice
        let isCancel: Bool
    }

    /// The buttons for an offer's prompt. The cancel-role button also runs when the
    /// dialog is dismissed by tapping outside, so it is always the choice that keeps
    /// the scan as captured. From iOS 26 the system hides that button on iPhone, so
    /// the same choice is added as an ordinary, visible button as well.
    static func buttons(for offer: Offer, cancelIsHidden: Bool) -> [PromptButton] {
        let (action, safe): (Choice?, Choice) = switch offer {
        case .scanBack: (.scanBack, .continueWithFront)
        case .combine: (.combine, .keepAsTwoPages)
        case .none: (nil, .continueWithFront)
        }
        var result: [PromptButton] = []
        if let action { result.append(PromptButton(choice: action, isCancel: false)) }
        if cancelIsHidden { result.append(PromptButton(choice: safe, isCancel: false)) }
        result.append(PromptButton(choice: safe, isCancel: true))
        return result
    }

    enum Route {
        /// Go straight to the name sheet with these pages.
        case save([UIImage])
        /// Ask first; the pages are what was captured.
        case ask(Offer, [UIImage])
    }

    static func isCardShaped(_ size: CGSize) -> Bool {
        guard size.width > 0, size.height > 0 else { return false }
        let aspect = max(size.width, size.height) / min(size.width, size.height)
        return abs(aspect - cardAspect) / cardAspect <= aspectTolerance
    }

    /// Only on the Auto page size: Letter and A4 promise paper-shaped pages, and their
    /// users keep exactly the behaviour they had.
    static func offer(forPageSizes sizes: [CGSize], paperSize: PaperSize) -> Offer {
        guard paperSize == .auto, sizes.allSatisfy(isCardShaped) else { return .none }
        switch sizes.count {
        case 1: return .scanBack
        case 2: return .combine
        default: return .none
        }
    }

    /// What to do with a capture. `front` is set when this capture is the back of a card
    /// the person chose to complete; its first page is stitched under the front and any
    /// further pages follow as ordinary pages.
    static func route(captured: [UIImage], awaitingBackFor front: UIImage?, paperSize: PaperSize) -> Route {
        if let front {
            guard let back = captured.first else { return .save([front]) }
            return .save([stitch(front: front, back: back)] + captured.dropFirst())
        }
        let offer = offer(forPageSizes: captured.map(\.pixelSize), paperSize: paperSize)
        return offer == .none ? .save(captured) : .ask(offer, captured)
    }

    /// Front above back on one white page, the back scaled to the front's width.
    static func stitch(front: UIImage, back: UIImage) -> UIImage {
        let width = front.pixelSize.width
        let frontHeight = front.pixelSize.height
        let backHeight = back.pixelSize.width > 0
            ? (back.pixelSize.height * width / back.pixelSize.width).rounded()
            : 0
        let gap = (width * gapFraction).rounded()
        let size = CGSize(width: width, height: frontHeight + gap + backHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            front.draw(in: CGRect(x: 0, y: 0, width: width, height: frontHeight))
            back.draw(in: CGRect(x: 0, y: frontHeight + gap, width: width, height: backHeight))
        }
    }
}

private extension UIImage {
    /// Size in pixels: the camera's images are not always scale 1.
    var pixelSize: CGSize { CGSize(width: size.width * scale, height: size.height * scale) }
}

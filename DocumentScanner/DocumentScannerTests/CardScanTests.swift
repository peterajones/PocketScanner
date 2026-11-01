import XCTest
import UIKit
@testable import DocumentScanner

final class CardScanShapeTests: XCTestCase {

    // A wallet card (ID-1) is 85.6 × 54 mm, about 1.59 : 1.
    func test_walletCard_isCardShaped_inEitherOrientation() {
        XCTAssertTrue(CardScan.isCardShaped(CGSize(width: 856, height: 540)))
        XCTAssertTrue(CardScan.isCardShaped(CGSize(width: 540, height: 856)))
    }

    // The scanner's crop is never exact; a few percent either way is still a card.
    func test_slightlyOffCrop_isStillCardShaped() {
        XCTAssertTrue(CardScan.isCardShaped(CGSize(width: 1550, height: 1000)))
        XCTAssertTrue(CardScan.isCardShaped(CGSize(width: 1640, height: 1000)))
    }

    func test_paperAndOtherCards_areNotCardShaped() {
        XCTAssertFalse(CardScan.isCardShaped(CGSize(width: 612, height: 792)), "US Letter")
        XCTAssertFalse(CardScan.isCardShaped(CGSize(width: 595, height: 842)), "A4")
        XCTAssertFalse(CardScan.isCardShaped(CGSize(width: 1500, height: 1000)), "4×6 photo")
        XCTAssertFalse(CardScan.isCardShaped(CGSize(width: 1750, height: 1000)), "business card")
        XCTAssertFalse(CardScan.isCardShaped(CGSize(width: 1000, height: 1000)), "square")
        XCTAssertFalse(CardScan.isCardShaped(.zero))
    }
}

final class CardScanOfferTests: XCTestCase {

    private let card = CGSize(width: 856, height: 540)
    private let letter = CGSize(width: 1700, height: 2200)

    func test_oneCard_onAuto_offersToScanTheBack() {
        XCTAssertEqual(CardScan.offer(forPageSizes: [card], paperSize: .auto), .scanBack)
    }

    func test_twoCards_onAuto_offersToCombine() {
        XCTAssertEqual(CardScan.offer(forPageSizes: [card, card], paperSize: .auto), .combine)
    }

    func test_onlyOnAuto() {
        XCTAssertEqual(CardScan.offer(forPageSizes: [card], paperSize: .usLetter), .none)
        XCTAssertEqual(CardScan.offer(forPageSizes: [card, card], paperSize: .a4), .none)
    }

    func test_documentsAndMixedScans_areLeftAlone() {
        XCTAssertEqual(CardScan.offer(forPageSizes: [letter], paperSize: .auto), .none)
        XCTAssertEqual(CardScan.offer(forPageSizes: [card, letter], paperSize: .auto), .none)
        XCTAssertEqual(CardScan.offer(forPageSizes: [card, card, card], paperSize: .auto), .none)
        XCTAssertEqual(CardScan.offer(forPageSizes: [], paperSize: .auto), .none)
    }
}

final class CardScanStitchTests: XCTestCase {

    // Front 856×540 above a half-resolution back, scaled up to the same width,
    // with a gap of 4% of the width (34px): 540 + 34 + 540 = 1114.
    func test_stitch_putsFrontAboveBack_atTheFrontsWidth() throws {
        let front = UIImage.solid(.red, size: CGSize(width: 856, height: 540))
        let back = UIImage.solid(.blue, size: CGSize(width: 428, height: 270))

        let page = CardScan.stitch(front: front, back: back)

        XCTAssertEqual(page.size.width * page.scale, 856)
        XCTAssertEqual(page.size.height * page.scale, 1114)
        XCTAssertEqual(try page.pixel(x: 428, y: 100), .red, "top half should be the front")
        XCTAssertEqual(try page.pixel(x: 428, y: 1000), .blue, "bottom half should be the back")
        XCTAssertEqual(try page.pixel(x: 428, y: 557), .white, "the gap should be white")
    }

    // The stitched page is itself card-shaped only by accident; what matters is that a
    // second detection pass never runs on it. Checked here so the result goes straight
    // to saving: one page, not two.
    func test_route_backCapture_isStitchedIntoOnePage() {
        let front = UIImage.solid(.red, size: CGSize(width: 856, height: 540))
        let back = UIImage.solid(.blue, size: CGSize(width: 856, height: 540))
        guard case .save(let pages) = CardScan.route(captured: [back], awaitingBackFor: front, paperSize: .auto) else {
            return XCTFail("expected the back capture to be saved")
        }
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages.first.map { $0.size.height * $0.scale }, 1114)
    }

    func test_route_backCaptureWithExtraPages_keepsThemAfterTheCard() {
        let front = UIImage.solid(.red, size: CGSize(width: 856, height: 540))
        let back = UIImage.solid(.blue, size: CGSize(width: 856, height: 540))
        let extra = UIImage.solid(.green, size: CGSize(width: 1700, height: 2200))
        guard case .save(let pages) = CardScan.route(captured: [back, extra], awaitingBackFor: front, paperSize: .auto) else {
            return XCTFail("expected the back capture to be saved")
        }
        XCTAssertEqual(pages.count, 2)
        XCTAssertTrue(pages[1] === extra)
    }

    func test_route_firstCapture_asksOrSaves() {
        let card = UIImage.solid(.red, size: CGSize(width: 856, height: 540))
        let letter = UIImage.solid(.red, size: CGSize(width: 1700, height: 2200))
        guard case .ask(.scanBack, let asked) = CardScan.route(captured: [card], awaitingBackFor: nil, paperSize: .auto) else {
            return XCTFail("expected a scan-back offer")
        }
        XCTAssertEqual(asked.count, 1)
        guard case .save(let saved) = CardScan.route(captured: [letter], awaitingBackFor: nil, paperSize: .auto) else {
            return XCTFail("expected a document to be saved as captured")
        }
        XCTAssertEqual(saved.count, 1)
    }
}

private extension UIImage {
    static func solid(_ color: UIColor, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    enum PixelError: Error { case unreadable }

    /// The colour at a pixel, snapped to red/green/blue/white so assertions stay readable.
    func pixel(x: Int, y: Int) throws -> UIColor {
        guard let cg = cgImage, let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { throw PixelError.unreadable }
        let bpp = cg.bitsPerPixel / 8
        let i = y * cg.bytesPerRow + x * bpp
        // Renderer images are BGRA (little-endian, premultiplied first).
        let b = bytes[i], g = bytes[i + 1], r = bytes[i + 2]
        switch (r > 200, g > 200, b > 200) {
        case (true, true, true): return .white
        case (true, false, false): return .red
        case (false, true, false): return .green
        case (false, false, true): return .blue
        default: return .black
        }
    }
}

/// From iOS 26, iPhone hides a confirmation dialog's cancel-role button (tap outside
/// instead). Every real choice must stay visible there, and tapping outside must
/// still keep what was scanned. Found on device: "Keep as Two Pages" was invisible.
final class CardScanButtonTests: XCTestCase {
    typealias B = CardScan.PromptButton

    func test_scanBack_whenCancelHidden_showsContinueAsVisibleButton() {
        XCTAssertEqual(CardScan.buttons(for: .scanBack, cancelIsHidden: true), [
            B(choice: .scanBack, isCancel: false),
            B(choice: .continueWithFront, isCancel: false),
            B(choice: .continueWithFront, isCancel: true),
        ])
    }

    func test_combine_whenCancelHidden_showsKeepAsTwoPagesAsVisibleButton() {
        XCTAssertEqual(CardScan.buttons(for: .combine, cancelIsHidden: true), [
            B(choice: .combine, isCancel: false),
            B(choice: .keepAsTwoPages, isCancel: false),
            B(choice: .keepAsTwoPages, isCancel: true),
        ])
    }

    // iOS 17–18 show the cancel-role button, so the safe choice is that button alone.
    func test_whenCancelShown_safeChoiceIsTheCancelButtonOnly() {
        XCTAssertEqual(CardScan.buttons(for: .scanBack, cancelIsHidden: false), [
            B(choice: .scanBack, isCancel: false),
            B(choice: .continueWithFront, isCancel: true),
        ])
        XCTAssertEqual(CardScan.buttons(for: .combine, cancelIsHidden: false), [
            B(choice: .combine, isCancel: false),
            B(choice: .keepAsTwoPages, isCancel: true),
        ])
    }

    // Tapping outside runs the cancel action, so it must never discard the scan.
    func test_everyOffer_hasExactlyOneCancel_thatKeepsTheScan() {
        for offer in [CardScan.Offer.scanBack, .combine, .none] {
            for hidden in [true, false] {
                let cancels = CardScan.buttons(for: offer, cancelIsHidden: hidden).filter(\.isCancel)
                XCTAssertEqual(cancels.count, 1, "\(offer) hidden=\(hidden)")
                XCTAssertNotEqual(cancels.first?.choice, .scanBack)
                XCTAssertNotEqual(cancels.first?.choice, .combine)
            }
        }
    }
}

import XCTest
@testable import DocumentScanner

final class DefaultDocumentNameTests: XCTestCase {
    private let fixedDate: Date = {
        var c = DateComponents()
        c.year = 2026
        c.month = 5
        c.day = 28
        c.hour = 14
        c.minute = 30
        c.timeZone = TimeZone.current
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    // MARK: - fallback

    func test_fallback_usesTimestampFormat() {
        let name = DefaultDocumentName.fallback(now: fixedDate)
        XCTAssertEqual(name, "Scan 2026-05-28 14:30")
    }

    // MARK: - receipt

    func test_receipt_keywordTriggersReceiptName() {
        let ocr = """
        COSTCO WHOLESALE
        #1234 BURNABY
        ITEM A 12.99
        ITEM B 4.50
        RECEIPT
        SUBTOTAL 17.49
        TOTAL 19.66
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Costco Wholesale Receipt — May 28")
    }

    func test_receipt_subtotalAndTotalAreEnough() {
        let ocr = """
        Whole Foods Market
        Cheese 6.99
        Bread 4.50
        Subtotal 11.49
        Total 12.96
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Whole Foods Market Receipt — May 28")
    }

    // MARK: - invoice

    func test_invoice_keywordTriggersInvoiceName() {
        let ocr = """
        ACME PLUMBING SERVICES LTD
        Invoice #4421
        Bill to: Peter Jones
        Total Due: $250.00
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Acme Plumbing Services Ltd Invoice — May 28")
    }

    // MARK: - recipe

    func test_recipe_ingredientsTriggersRecipeName() {
        let ocr = """
        Banana Bread
        Ingredients
        3 ripe bananas
        1 cup flour
        Directions
        Preheat oven to 350F
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Recipe — Banana Bread")
    }

    func test_recipe_skipsTheWordRecipeItself() {
        let ocr = """
        Recipe
        Pumpkin Pie
        Ingredients
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Recipe — Pumpkin Pie")
    }

    // MARK: - title fallback

    func test_titleFallback_usesFirstTitleLikeLine() {
        let ocr = """
        Quarterly Sales Forecast
        Prepared by accounting
        Page 1 of 12
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Quarterly Sales Forecast — May 28")
    }

    func test_titleFallback_titleCasesAllCaps() {
        let ocr = """
        ANNUAL REPORT 2025
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Annual Report 2025 — May 28")
    }

    // MARK: - no match

    func test_emptyOCR_returnsNil() {
        XCTAssertNil(DefaultDocumentName.suggest(from: "", now: fixedDate))
    }

    func test_onlyDigits_returnsNil() {
        XCTAssertNil(DefaultDocumentName.suggest(from: "123456789", now: fixedDate))
    }

    func test_veryShortLine_returnsNil() {
        XCTAssertNil(DefaultDocumentName.suggest(from: "ok", now: fixedDate))
    }
}

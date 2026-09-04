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
        // Format deliberately changed: comma not em dash (these become filenames), and
        // the date is locale-aware now, so assert the parts rather than a fixed string.
        XCTAssertEqual(name?.hasPrefix("Costco Wholesale Receipt, "), true, "got: \(name ?? "nil")")
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
        XCTAssertEqual(name?.hasPrefix("Whole Foods Market Receipt, "), true, "got: \(name ?? "nil")")
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
        XCTAssertEqual(name?.hasPrefix("Acme Plumbing Services Ltd Invoice, "), true, "got: \(name ?? "nil")")
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
        XCTAssertEqual(name, "Recipe, Banana Bread")
    }

    func test_recipe_skipsTheWordRecipeItself() {
        let ocr = """
        Recipe
        Pumpkin Pie
        Ingredients
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name, "Recipe, Pumpkin Pie")
    }

    // MARK: - title fallback

    func test_titleFallback_usesFirstTitleLikeLine() {
        let ocr = """
        Quarterly Sales Forecast
        Prepared by accounting
        Page 1 of 12
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name?.hasPrefix("Quarterly Sales Forecast, "), true, "got: \(name ?? "nil")")
    }

    func test_titleFallback_titleCasesAllCaps() {
        let ocr = """
        ANNUAL REPORT 2025
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertEqual(name?.hasPrefix("Annual Report 2025, "), true, "got: \(name ?? "nil")")
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
    // MARK: - Misclassification (the bug this exists to fix)

    /// The real case: the demo consulting agreement contains "payable within thirty
    /// (30) days of receipt", and a bare substring match named it
    /// "Meridian Advisory Group Receipt — Jul 12". It shipped that way in an App
    /// Store screenshot.
    func test_contractMentioningReceiptIsNotCalledAReceipt() {
        let ocr = """
        MERIDIAN ADVISORY GROUP
        CONSULTING SERVICES AGREEMENT
        This Consulting Services Agreement is entered into by and between Meridian
        Advisory Group, LLC and Jordan Avery, an independent contractor.
        3. COMPENSATION
        The Company shall pay the Consultant a fee of $185.00 per hour, invoiced
        monthly and payable within thirty (30) days of receipt.
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertNotNil(name)
        XCTAssertFalse(name!.contains("Receipt"), "named a contract a receipt: \(name!)")
    }

    /// The looser third clause: any document with both "total" and "tax" became a
    /// receipt. A tax slip has both and is not one.
    func test_taxDocumentWithATotalIsNotAReceipt() {
        let ocr = """
        CANADA REVENUE AGENCY
        STATEMENT OF REMUNERATION PAID
        Employment income 148,000.00
        Income tax deducted 32,410.00
        Total deductions 41,220.00
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertNotNil(name)
        XCTAssertFalse(name!.contains("Receipt"), "named a tax slip a receipt: \(name!)")
    }

    /// A real receipt must still be recognised — the fix must not simply stop
    /// classifying.
    func test_realReceiptIsStillRecognised() {
        let ocr = """
        COSTCO WHOLESALE
        #1234 BURNABY
        ITEM A 12.99
        SUBTOTAL 17.49
        TAX 2.17
        TOTAL 19.66
        """
        let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate)
        XCTAssertNotNil(name)
        XCTAssertTrue(name!.contains("Receipt"), "stopped recognising a real receipt: \(name!)")
    }

    // MARK: - No em dashes in generated names

    /// These strings become FILENAMES, and per Peter's standing preference they must
    /// not contain em dashes.
    func test_generatedNamesContainNoEmDash() {
        let samples = [
            "COSTCO WHOLESALE\nSUBTOTAL 17.49\nTOTAL 19.66",
            "ACME LTD\nINVOICE #42\nBILL TO: someone",
            "Banana Bread\nIngredients\nDirections",
            "Residential Lease Agreement\nbetween the parties",
        ]
        for ocr in samples {
            guard let name = DefaultDocumentName.suggest(from: ocr, now: fixedDate) else { continue }
            XCTAssertFalse(name.contains("\u{2014}"), "em dash in generated name: \(name)")
        }
    }

}

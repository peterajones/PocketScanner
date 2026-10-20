import XCTest
import UIKit
@testable import DocumentScanner

@MainActor
final class InstantScanPresenterTests: XCTestCase {

    private func present(_ child: UIViewController, from parent: UIViewController) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            parent.present(child, animated: false) { continuation.resume() }
        }
    }

    func test_topMost_walksPresentedChain() async {
        let a = UIViewController(), b = UIViewController(), c = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = a
        window.makeKeyAndVisible()

        XCTAssertTrue(InstantScanPresenter.topMost(from: a) === a)

        await present(b, from: a)
        await present(c, from: b)

        XCTAssertTrue(InstantScanPresenter.topMost(from: a) === c)
        XCTAssertTrue(InstantScanPresenter.topMost(from: c) === c)
        window.isHidden = true
    }
}

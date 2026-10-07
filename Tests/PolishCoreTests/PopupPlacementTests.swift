import CoreGraphics
import XCTest
@testable import PolishCore

final class PopupPlacementTests: XCTestCase {
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let right = CGRect(x: 1440, y: -180, width: 1920, height: 1080)

    func testMissingCaretUsesEditorDisplayRatherThanPointerDisplay() {
        let field = CGRect(x: 1600, y: 80, width: 700, height: 140)
        let window = CGRect(x: 1500, y: 0, width: 1200, height: 800)
        let anchor = PopupPlacement.anchor(caret: nil, field: field, window: window, screens: [primary, right])
        XCTAssertEqual(anchor, field)
        XCTAssertEqual(PopupPlacement.screenIndex(for: anchor!, screens: [primary, right]), 1)
    }

    func testMissingEditorBoundsFallsBackToSourceWindow() {
        let window = CGRect(x: 1650, y: 50, width: 1000, height: 700)
        XCTAssertEqual(PopupPlacement.anchor(caret: .zero, field: nil, window: window, screens: [primary, right]), window)
    }

    func testCaretOnWrongDisplayIsRejected() {
        let field = CGRect(x: 1700, y: 100, width: 600, height: 180)
        let invalidCaret = CGRect(x: 0, y: 880, width: 0, height: 20)
        XCTAssertEqual(PopupPlacement.anchor(caret: invalidCaret, field: field, window: nil, screens: [primary, right]), field)
    }

    func testZeroWidthCaretIsValid() {
        let caret = CGRect(x: 1700, y: 150, width: 0, height: 20)
        let anchor = PopupPlacement.anchor(caret: caret, field: CGRect(x: 1600, y: 100, width: 600, height: 100), window: nil, screens: [primary, right])
        XCTAssertEqual(anchor, CGRect(x: 1700, y: 150, width: 1, height: 20))
    }

    func testDisplaysAboveBelowAndLeftUsePrimaryCoordinateOrigin() {
        for ax in [
            CGRect(x: -1400, y: 100, width: 400, height: 100),
            CGRect(x: 200, y: -900, width: 400, height: 100),
            CGRect(x: 200, y: 1000, width: 400, height: 100)
        ] {
            let converted = PopupPlacement.appKitRect(fromAX: ax, primaryScreenTop: 900)
            XCTAssertEqual(converted.minX, ax.minX)
            XCTAssertEqual(converted.minY, 900 - ax.maxY)
            XCTAssertEqual(PopupPlacement.appKitRect(fromAX: converted, primaryScreenTop: 900), ax)
        }
        let upper = CGRect(x: 0, y: 900, width: 1920, height: 1080)
        let caret = PopupPlacement.appKitRect(fromAX: CGRect(x: 200, y: -500, width: 1, height: 20), primaryScreenTop: 900)
        XCTAssertEqual(PopupPlacement.screenIndex(for: caret, screens: [primary, upper]), 1)
    }

    func testBottomComposerPlacesPopupAboveAndOnSameScreen() {
        let field = CGRect(x: 3200, y: -160, width: 100, height: 80)
        let size = CGSize(width: 460, height: 300)
        let origin = PopupPlacement.origin(for: size, beside: field, visibleFrame: right)
        XCTAssertEqual(origin.y, field.maxY + 10)
        XCTAssertTrue(right.contains(CGRect(origin: origin, size: size)))
    }

    func testTopCaretPlacesLoadingBelowWithoutCoveringTheCaret() {
        let caret = CGRect(x: 1800, y: 840, width: 1, height: 20)
        let size = CGSize(width: 320, height: 80)
        let origin = PopupPlacement.origin(for: size, beside: caret, visibleFrame: right)
        XCTAssertEqual(origin.y + size.height, caret.minY - 10)
        XCTAssertTrue(right.contains(CGRect(origin: origin, size: size)))
    }

    func testStraddlingFieldUsesDisplayWithMostOfTheEditor() {
        let field = CGRect(x: 1400, y: 100, width: 600, height: 100)
        XCTAssertEqual(PopupPlacement.screenIndex(for: field, screens: [primary, right]), 1)
    }

    func testOffscreenOrNonfiniteBoundsAreNotUsedAsAnAnchor() {
        let window = CGRect(x: 1600, y: 100, width: 1000, height: 600)
        XCTAssertEqual(PopupPlacement.anchor(caret: CGRect(x: CGFloat.nan, y: 20, width: 1, height: 20),
            field: CGRect(x: 9000, y: 9000, width: 100, height: 100), window: window, screens: [primary, right]), window)
        XCTAssertNil(PopupPlacement.anchor(caret: nil, field: nil, window: nil, screens: [primary, right]))
    }
}

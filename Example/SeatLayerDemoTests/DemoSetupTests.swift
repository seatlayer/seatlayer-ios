import UIKit
import XCTest

/// The example never assumes an API. The test host launches without
/// `SEATLAYER_API_BASE`, so the example must show setup guidance and open no
/// picker.
@MainActor
final class DemoSetupTests: XCTestCase {
    func testWithoutAnAPIBaseTheExampleShowsSetupAndOpensNoPicker() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["SEATLAYER_API_BASE"] != nil,
            "this run sets SEATLAYER_API_BASE"
        )
        let window = try XCTUnwrap(UIApplication.shared.delegate?.window ?? nil)
        let root = try XCTUnwrap(window.rootViewController)
        root.loadViewIfNeeded()
        XCTAssertNotNil(view(identified: "seatlayer-demo-setup", in: root.view), "no setup guidance")
        XCTAssertNil(view(identified: "seatlayer-demo-picker", in: root.view), "a picker opened without an API base")
        XCTAssertTrue(root.children.isEmpty, "a picker opened without an API base")
    }

    private func view(identified identifier: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == identifier { return root }
        for child in root.subviews {
            if let found = view(identified: identifier, in: child) { return found }
        }
        return nil
    }
}

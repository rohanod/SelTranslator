import AppKit
import XCTest
@testable import SelTranslator

@MainActor
final class TranslatorPanelControllerTests: XCTestCase {
    func testTranslatorPanelStaysVisibleAcrossSpacesAndFullScreenWindows() throws {
        let controller = TranslatorPanelController(
            viewModel: TranslatorViewModel(
                languageStore: TranslationLanguageStore(),
                translationService: TranslationService()
            )
        )

        let panel = try XCTUnwrap(Mirror(reflecting: controller).descendant("panel") as? NSPanel)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertFalse(panel.collectionBehavior.contains(.transient))
        XCTAssertFalse(panel.hidesOnDeactivate)
    }

    func testCopyToastStaysVisibleAcrossSpacesAndFullScreenWindows() throws {
        let controller = TranslatorPanelController(
            viewModel: TranslatorViewModel(
                languageStore: TranslationLanguageStore(),
                translationService: TranslationService()
            )
        )

        let panel = try XCTUnwrap(Mirror(reflecting: controller).descendant("copyToastPanel") as? NSPanel)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.stationary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertFalse(panel.collectionBehavior.contains(.transient))
        XCTAssertFalse(panel.hidesOnDeactivate)
    }

    func testResigningKeyWithoutOutsideMouseClickDoesNotDismissPanel() throws {
        let viewModel = TranslatorViewModel(
            languageStore: TranslationLanguageStore(),
            translationService: TranslationService()
        )
        let controller = TranslatorPanelController(viewModel: viewModel)
        let panel = try XCTUnwrap(Mirror(reflecting: controller).descendant("panel") as? NSPanel)

        viewModel.isPresented = true
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }

        controller.windowDidResignKey(
            Notification(name: NSWindow.didResignKeyNotification, object: panel)
        )

        XCTAssertTrue(viewModel.isPresented)
        XCTAssertTrue(panel.isVisible)
    }
}

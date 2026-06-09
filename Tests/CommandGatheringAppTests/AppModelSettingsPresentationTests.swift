import CommandGatheringCore
import XCTest
@testable import CommandGatheringApp

@MainActor
final class AppModelSettingsPresentationTests: XCTestCase {
    func testSettingsPresentationCanOpenAndClose() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        try store.save(.defaultValue)
        let model = AppModel(store: store)

        XCTAssertFalse(model.isSettingsPresented)

        model.presentSettings()

        XCTAssertTrue(model.isSettingsPresented)

        model.dismissSettings()

        XCTAssertFalse(model.isSettingsPresented)
    }
}

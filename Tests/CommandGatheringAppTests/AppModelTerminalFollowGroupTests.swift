import CommandGatheringCore
import XCTest
@testable import CommandGatheringApp

@MainActor
final class AppModelTerminalFollowGroupTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "terminalFollowsSelectedGroup")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "terminalFollowsSelectedGroup")
        super.tearDown()
    }

    func testVisibleTerminalSessionsFollowSelectedGroupWhenEnabled() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        let config = CommandConfiguration.defaultValue
        try store.save(config)
        let model = AppModel(store: store)
        let firstGroup = config.groups[0]
        let secondGroup = config.groups[1]
        let firstCommand = try XCTUnwrap(config.commands.first { $0.groupID == firstGroup.id })
        let secondCommand = try XCTUnwrap(config.commands.first { $0.groupID == secondGroup.id })

        model.terminalFollowsSelectedGroup = true
        model.select(group: firstGroup)
        model.open(command: firstCommand)

        XCTAssertEqual(model.visibleTerminalSessions.map(\.groupID), [firstGroup.id])
        XCTAssertTrue(model.isTerminalSessionSelected(try XCTUnwrap(model.visibleTerminalSessions.first?.id)))

        model.select(group: secondGroup)

        XCTAssertEqual(model.visibleTerminalSessions, [])
        XCTAssertFalse(model.isTerminalSessionVisible(try XCTUnwrap(model.terminalCoordinator.sessions.first?.id)))
        XCTAssertFalse(model.isTerminalSessionSelected(try XCTUnwrap(model.terminalCoordinator.sessions.first?.id)))

        model.open(command: secondCommand)

        XCTAssertEqual(model.visibleTerminalSessions.map(\.groupID), [secondGroup.id])
        XCTAssertEqual(model.terminalCoordinator.sessions.count, 2)
    }

    func testTemporaryAndBlankTerminalsUseCurrentGroupWhenFollowEnabled() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        let config = CommandConfiguration.defaultValue
        try store.save(config)
        let model = AppModel(store: store)
        let targetGroup = config.groups[1]

        model.terminalFollowsSelectedGroup = true
        model.select(group: targetGroup)
        model.createTemporaryTerminal()
        model.createBlankTerminal()

        XCTAssertEqual(model.visibleTerminalSessions.count, 2)
        XCTAssertTrue(model.visibleTerminalSessions.allSatisfy { $0.groupID == targetGroup.id })
    }

    func testAllTerminalSessionsRemainVisibleWhenFollowDisabled() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        let config = CommandConfiguration.defaultValue
        try store.save(config)
        let model = AppModel(store: store)
        let firstGroup = config.groups[0]
        let secondGroup = config.groups[1]
        let firstCommand = try XCTUnwrap(config.commands.first { $0.groupID == firstGroup.id })
        let secondCommand = try XCTUnwrap(config.commands.first { $0.groupID == secondGroup.id })

        model.terminalFollowsSelectedGroup = false
        model.select(group: firstGroup)
        model.open(command: firstCommand)
        model.select(group: secondGroup)
        model.open(command: secondCommand)

        XCTAssertEqual(model.visibleTerminalSessions.count, 2)
    }

    func testEnablingFollowGroupAssignsExistingUngroupedTerminalsToCurrentGroup() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        let config = CommandConfiguration.defaultValue
        try store.save(config)
        let model = AppModel(store: store)
        let targetGroup = config.groups[1]

        model.select(group: targetGroup)
        model.createBlankTerminal()
        model.terminalFollowsSelectedGroup = true

        XCTAssertEqual(model.visibleTerminalSessions.map(\.groupID), [targetGroup.id])
    }
}

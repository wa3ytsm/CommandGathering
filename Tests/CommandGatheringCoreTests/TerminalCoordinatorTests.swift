import XCTest
@testable import CommandGatheringCore

final class TerminalCoordinatorTests: XCTestCase {
    func testOpeningCommandCreatesBoundSessionAndExecutionRequestOnce() {
        var coordinator = TerminalCoordinator()
        let workspaceRoot = URL(fileURLWithPath: "/tmp/command-gathering-workspace", isDirectory: true)
        let command = CommandConfiguration.makeDefaultValue(defaultWorkspaceDirectory: workspaceRoot).commands[1]

        let first = coordinator.open(command: command)
        let second = coordinator.open(command: command)

        XCTAssertTrue(first.shouldExecuteCommand)
        XCTAssertEqual(first.session.boundCommandID, command.id)
        XCTAssertEqual(first.session.groupID, command.groupID)
        XCTAssertEqual(first.session.startupCommand, command.command)
        XCTAssertEqual(
            first.session.workingDirectory,
            "/tmp/command-gathering-workspace/scripts"
        )
        XCTAssertFalse(second.shouldExecuteCommand)
        XCTAssertEqual(second.session.id, first.session.id)
        XCTAssertEqual(coordinator.selectedSessionID, first.session.id)
        XCTAssertEqual(coordinator.sessions.count, 1)
    }

    func testClosingBoundSessionClearsBindingSoCommandCanExecuteAgain() throws {
        var coordinator = TerminalCoordinator()
        let command = CommandConfiguration.defaultValue.commands[0]
        let first = coordinator.open(command: command)

        coordinator.close(sessionID: first.session.id)
        let second = coordinator.open(command: command)

        XCTAssertTrue(second.shouldExecuteCommand)
        XCTAssertNotEqual(second.session.id, first.session.id)
        XCTAssertEqual(coordinator.sessions.count, 1)
    }

    func testClosingSessionDeletesItsHistoryFile() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }

        var coordinator = TerminalCoordinator(rootDirectory: root)
        let session = coordinator.createBlankSession().session
        let historyFileURL = TerminalSessionStorage.historyFileURL(for: session.id, rootDirectory: root)
        try "echo test\n".write(to: historyFileURL, atomically: true, encoding: .utf8)

        coordinator.close(sessionID: session.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: historyFileURL.path))
    }

    func testCreateBlankSessionIsUnboundAndDoesNotExecuteCommand() {
        var coordinator = TerminalCoordinator()
        let groupID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        let result = coordinator.createBlankSession(groupID: groupID)

        XCTAssertFalse(result.shouldExecuteCommand)
        XCTAssertNil(result.session.boundCommandID)
        XCTAssertEqual(result.session.groupID, groupID)
        XCTAssertEqual(coordinator.selectedSessionID, result.session.id)
    }

    func testMoveSessionReordersTerminalTabsAndPreservesSelection() {
        var coordinator = TerminalCoordinator()
        let first = coordinator.createBlankSession().session
        let second = coordinator.createBlankSession().session
        let third = coordinator.createBlankSession().session
        coordinator.select(sessionID: second.id)

        coordinator.moveSession(id: first.id, to: third.id)

        XCTAssertEqual(coordinator.sessions.map(\.id), [second.id, third.id, first.id])
        XCTAssertEqual(coordinator.selectedSessionID, second.id)
    }

    func testCreateTemporarySessionUsesDirectoryCommandWithoutBinding() {
        var coordinator = TerminalCoordinator()
        let groupID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let result = coordinator.createTemporarySession(defaultDirectory: "/tmp/example", groupID: groupID)

        XCTAssertFalse(result.shouldExecuteCommand)
        XCTAssertNil(result.session.boundCommandID)
        XCTAssertEqual(result.session.groupID, groupID)
        XCTAssertEqual(result.session.startupCommand, "cd /tmp/example")
        XCTAssertEqual(result.session.title, "临时命令")
    }

    func testAssignUngroupedSessionsSetsGroupOnlyForUngroupedTerminals() {
        var coordinator = TerminalCoordinator()
        let assignedGroupID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let existingGroupID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let first = coordinator.createBlankSession().session
        let second = coordinator.createBlankSession(groupID: existingGroupID).session

        coordinator.assignUngroupedSessions(to: assignedGroupID)

        XCTAssertEqual(coordinator.sessions.first { $0.id == first.id }?.groupID, assignedGroupID)
        XCTAssertEqual(coordinator.sessions.first { $0.id == second.id }?.groupID, existingGroupID)
    }

    func testRestoredBoundCommandSessionDoesNotExecuteAgainAndReusesExistingWindow() {
        let command = CommandConfiguration.defaultValue.commands[0]
        let restoredSession = PersistedTerminalSession(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            title: command.name,
            boundCommandID: command.id,
            groupID: command.groupID,
            workingDirectory: "/tmp/restored",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        var coordinator = TerminalCoordinator(
            workspaceState: TerminalWorkspaceState(
                sessions: [restoredSession],
                selectedSessionID: restoredSession.id
            )
        )

        let reopened = coordinator.open(command: command)

        XCTAssertFalse(reopened.shouldExecuteCommand)
        XCTAssertEqual(reopened.session.id, restoredSession.id)
        XCTAssertEqual(coordinator.sessions.count, 1)
        XCTAssertNil(coordinator.sessions[0].startupCommand)
        XCTAssertEqual(coordinator.sessions[0].groupID, command.groupID)
        XCTAssertEqual(coordinator.sessions[0].workingDirectory, "/tmp/restored")
    }

    func testPersistedWorkspaceStateRoundTripsSessionsAndSelection() {
        let workspaceRoot = URL(fileURLWithPath: "/tmp/command-gathering-workspace", isDirectory: true)
        let command = CommandConfiguration.makeDefaultValue(defaultWorkspaceDirectory: workspaceRoot).commands[1]
        var coordinator = TerminalCoordinator()
        let bound = coordinator.open(command: command)
        let blank = coordinator.createBlankSession()
        coordinator.select(sessionID: blank.session.id)

        let persisted = coordinator.persistedWorkspaceState()
        let restored = TerminalCoordinator(workspaceState: persisted)

        XCTAssertEqual(restored.sessions.count, 2)
        XCTAssertEqual(restored.selectedSessionID, blank.session.id)
        XCTAssertEqual(restored.sessions.first { $0.id == bound.session.id }?.boundCommandID, command.id)
        XCTAssertEqual(restored.sessions.first { $0.id == bound.session.id }?.groupID, command.groupID)
        XCTAssertNil(restored.sessions.first { $0.id == bound.session.id }?.startupCommand)
        XCTAssertEqual(
            restored.sessions.first { $0.id == bound.session.id }?.workingDirectory,
            "/tmp/command-gathering-workspace/scripts"
        )
    }

    func testResolveWorkingDirectoryParsesLeadingCdCommand() {
        let command = """
        cd /tmp/example-dir
        bash build.sh
        """

        XCTAssertEqual(TerminalCoordinator.resolveWorkingDirectory(from: command), "/tmp/example-dir")
    }
}

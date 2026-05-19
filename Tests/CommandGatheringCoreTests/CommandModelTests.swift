import XCTest
@testable import CommandGatheringCore

final class CommandModelTests: XCTestCase {
    func testDefaultConfigurationHasGroupsAndCommands() {
        let config = CommandConfiguration.defaultValue

        XCTAssertEqual(config.schemaVersion, CommandConfiguration.currentSchemaVersion)
        XCTAssertFalse(config.groups.isEmpty)
        XCTAssertFalse(config.commands.isEmpty)
        XCTAssertTrue(config.commands.allSatisfy { command in
            config.groups.contains { $0.id == command.groupID }
        })
    }

    func testDefaultConfigurationContainsPackagingGroupAndCommand() throws {
        let workspaceRoot = URL(fileURLWithPath: "/tmp/command-gathering-workspace", isDirectory: true)
        let config = CommandConfiguration.makeDefaultValue(defaultWorkspaceDirectory: workspaceRoot)
        let packagingGroup = try XCTUnwrap(config.groups.first { $0.name == "程序打包" })
        let command = try XCTUnwrap(config.commands.first { $0.name == "打包 Command Gathering" })

        XCTAssertEqual(command.groupID, packagingGroup.id)
        XCTAssertEqual(
            command.command,
            "cd /tmp/command-gathering-workspace/scripts\nbash build-app.sh"
        )
        XCTAssertFalse(config.commands.contains { $0.command == "git status --short" })
    }

    func testCommandConfigurationRoundTripsThroughJSON() throws {
        let config = CommandConfiguration.defaultValue
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(config)
        let decoded = try decoder.decode(CommandConfiguration.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func testReorderGroupsMovesGroupAndRewritesSortOrder() throws {
        var config = CommandConfiguration.defaultValue
        let firstID = config.groups[0].id
        let secondID = config.groups[1].id

        config.moveGroup(id: secondID, before: firstID)

        let sorted = config.groups.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(sorted.map(\.id), [secondID, firstID])
        XCTAssertEqual(sorted.map(\.sortOrder), [0, 1])
    }

    func testReorderCommandsMovesCommandWithinGroupAndRewritesSortOrder() {
        let groupID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let otherGroupID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let firstID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let secondID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let thirdID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!

        var config = CommandConfiguration(
            groups: [
                CommandGroup(id: groupID, name: "常用命令", sortOrder: 0),
                CommandGroup(id: otherGroupID, name: "程序打包", sortOrder: 1)
            ],
            commands: [
                CommandItem(id: firstID, groupID: groupID, name: "A", command: "echo A", iconName: "terminal", accentColor: "#22C55E", sortOrder: 0, createdAt: .distantPast, updatedAt: .distantPast),
                CommandItem(id: secondID, groupID: groupID, name: "B", command: "echo B", iconName: "terminal", accentColor: "#22C55E", sortOrder: 1, createdAt: .distantPast, updatedAt: .distantPast),
                CommandItem(id: thirdID, groupID: groupID, name: "C", command: "echo C", iconName: "terminal", accentColor: "#22C55E", sortOrder: 2, createdAt: .distantPast, updatedAt: .distantPast),
                CommandItem(groupID: otherGroupID, name: "D", command: "echo D", iconName: "terminal", accentColor: "#22C55E", sortOrder: 0, createdAt: .distantPast, updatedAt: .distantPast)
            ]
        )

        config.moveCommand(id: firstID, to: thirdID)

        let reordered: [CommandItem] = config.commands
            .filter { $0.groupID == groupID }
            .sorted { $0.sortOrder < $1.sortOrder }

        XCTAssertEqual(reordered.map { $0.id }, [secondID, thirdID, firstID])
        XCTAssertEqual(reordered.map { $0.sortOrder }, [0, 1, 2])
        XCTAssertEqual(
            config.commands.first { $0.groupID == otherGroupID }?.sortOrder,
            0
        )
    }

    func testRenameGroupTrimsNameAndRejectsDuplicateNames() throws {
        var config = CommandConfiguration.defaultValue
        let groupID = config.groups[0].id

        XCTAssertTrue(config.renameGroup(id: groupID, to: " NAS "))
        XCTAssertEqual(config.groups.first { $0.id == groupID }?.name, "NAS")

        XCTAssertFalse(config.renameGroup(id: groupID, to: "程序打包"))
        XCTAssertEqual(config.groups.first { $0.id == groupID }?.name, "NAS")
    }

    func testDeleteGroupRemovesItsCommandsAndRewritesSortOrder() throws {
        var config = CommandConfiguration.defaultValue
        let deletedGroupID = config.groups[0].id

        let nextSelectedID = config.deleteGroup(id: deletedGroupID)

        XCTAssertNotNil(nextSelectedID)
        XCTAssertFalse(config.groups.contains { $0.id == deletedGroupID })
        XCTAssertFalse(config.commands.contains { $0.groupID == deletedGroupID })
        XCTAssertEqual(config.groups.sorted { $0.sortOrder < $1.sortOrder }.map(\.sortOrder), [0])
    }

    func testDeleteGroupKeepsLastGroup() throws {
        var config = CommandConfiguration(
            groups: [
                CommandGroup(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "NAS", sortOrder: 0)
            ],
            commands: []
        )

        XCTAssertNil(config.deleteGroup(id: config.groups[0].id))
        XCTAssertEqual(config.groups.count, 1)
    }
}

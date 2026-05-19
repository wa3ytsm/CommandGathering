import XCTest
@testable import CommandGatheringCore

final class CommandStoreTests: XCTestCase {
    func testLoadOrCreateWritesDefaultConfigurationWhenMissing() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)

        let config = try store.loadOrCreate()

        XCTAssertEqual(config, .defaultValue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "commands.json").path))
    }

    func testSaveAndLoadRoundTripConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        var config = CommandConfiguration.defaultValue
        config.groups.append(CommandGroup(name: "部署", sortOrder: 2))

        try store.save(config)
        let loaded = try store.load()

        XCTAssertEqual(loaded, config)
    }

    func testPackagedAppStorageRootUsesDataDirectoryInsideAppBundle() {
        let bundleURL = URL(fileURLWithPath: "/Applications/CommandGathering.app", isDirectory: true)
        let current = URL(fileURLWithPath: "/tmp/work", isDirectory: true)

        let root = StorageRootLocator.resolveRootDirectory(bundleURL: bundleURL, currentDirectoryURL: current)

        XCTAssertEqual(root.path, "/Applications/CommandGathering.app/CommandGatheringData")
    }

    func testSwiftRunStorageRootUsesCurrentDirectoryDataFolder() {
        let bundleURL = URL(fileURLWithPath: "/tmp/CommandGatheringApp", isDirectory: false)
        let current = URL(fileURLWithPath: "/tmp/work", isDirectory: true)

        let root = StorageRootLocator.resolveRootDirectory(bundleURL: bundleURL, currentDirectoryURL: current)

        XCTAssertEqual(root.path, "/tmp/work/CommandGatheringData")
    }

    func testLoadOrCreateMigratesOldBundledGitStatusDefault() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        let commonGroup = CommandGroup(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "常用",
            sortOrder: 0
        )
        let projectGroup = CommandGroup(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "项目",
            sortOrder: 1
        )
        let oldConfig = CommandConfiguration(
            groups: [commonGroup, projectGroup],
            commands: [
                CommandItem(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    groupID: projectGroup.id,
                    name: "Git 状态",
                    command: "git status --short",
                    iconName: "branch",
                    accentColor: "#38BDF8",
                    notes: "查看当前仓库状态",
                    sortOrder: 0
                )
            ]
        )
        try store.save(oldConfig)

        let migrated = try store.loadOrCreate()
        let expectedPackagingCommand = CommandConfiguration.defaultValue
            .commands
            .first { $0.name == "打包 Command Gathering" }?
            .command

        XCTAssertTrue(migrated.groups.contains { $0.name == "程序打包" })
        XCTAssertTrue(migrated.commands.contains { $0.name == "打包 Command Gathering" })
        XCTAssertEqual(
            migrated.commands.first { $0.name == "打包 Command Gathering" }?.command,
            expectedPackagingCommand
        )
        XCTAssertFalse(migrated.commands.contains { $0.command == "git status --short" })
    }

    func testLoadOrCreatePreservesCustomizedCurrentConfiguration() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)

        let packagingGroup = CommandConfiguration.defaultValue.groups[1]
        var packagingCommand = CommandConfiguration.defaultValue.commands[1]
        packagingCommand.name = "本地打包"
        packagingCommand.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let customized = CommandConfiguration(
            groups: [packagingGroup],
            commands: [packagingCommand]
        )

        try store.save(customized)
        let loaded = try store.loadOrCreate()

        XCTAssertEqual(loaded, customized)
        XCTAssertFalse(loaded.commands.contains { $0.name == "查看当前目录" })
        XCTAssertTrue(loaded.commands.contains { $0.name == "本地打包" })
    }

    func testSaveAndLoadRoundTripConfigurationPreservesWorkspaceSessions() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = CommandStore(rootDirectory: root)
        let command = CommandConfiguration.defaultValue.commands[0]
        let session = PersistedTerminalSession(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            title: command.name,
            boundCommandID: command.id,
            workingDirectory: "/tmp/restored",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        var config = CommandConfiguration.defaultValue
        config.workspace = TerminalWorkspaceState(
            sessions: [session],
            selectedSessionID: session.id
        )

        try store.save(config)
        let loaded = try XCTUnwrap(store.load())

        XCTAssertEqual(loaded.workspace, config.workspace)
    }
}

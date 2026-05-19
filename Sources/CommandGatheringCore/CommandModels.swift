import Foundation

public struct CommandConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var groups: [CommandGroup]
    public var commands: [CommandItem]
    public var workspace: TerminalWorkspaceState

    public init(
        schemaVersion: Int = CommandConfiguration.currentSchemaVersion,
        groups: [CommandGroup],
        commands: [CommandItem],
        workspace: TerminalWorkspaceState = .empty
    ) {
        self.schemaVersion = schemaVersion
        self.groups = groups
        self.commands = commands
        self.workspace = workspace
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case groups
        case commands
        case workspace
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        groups = try container.decode([CommandGroup].self, forKey: .groups)
        commands = try container.decode([CommandItem].self, forKey: .commands)
        workspace = try container.decodeIfPresent(TerminalWorkspaceState.self, forKey: .workspace) ?? .empty
    }

    public static var defaultValue: CommandConfiguration {
        makeDefaultValue()
    }

    public static func makeDefaultValue(
        defaultWorkspaceDirectory: URL = StorageRootLocator.resolveDefaultWorkspaceDirectory()
    ) -> CommandConfiguration {
        let normalizedWorkspacePath = defaultWorkspaceDirectory.standardizedFileURL.path

        return CommandConfiguration(
            groups: [
                CommandGroup(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "常用命令", sortOrder: 0),
                CommandGroup(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "程序打包", sortOrder: 1)
            ],
            commands: [
                CommandItem(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    groupID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    name: "查看当前目录",
                    command: "pwd && ls -la",
                    iconName: "terminal",
                    accentColor: "#22C55E",
                    notes: "输出当前目录和文件列表",
                    sortOrder: 0,
                    createdAt: Date(timeIntervalSince1970: 1_767_897_600),
                    updatedAt: Date(timeIntervalSince1970: 1_767_897_600)
                ),
                CommandItem(
                    id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
                    groupID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                    name: "打包 Command Gathering",
                    command: "cd \(normalizedWorkspacePath)/scripts\nbash build-app.sh",
                    iconName: "hammer",
                    accentColor: "#38BDF8",
                    notes: "构建 dist/CommandGathering.app 并保留 App 内配置目录",
                    sortOrder: 0,
                    createdAt: Date(timeIntervalSince1970: 1_767_897_600),
                    updatedAt: Date(timeIntervalSince1970: 1_767_897_600)
                )
            ],
            workspace: .empty
        )
    }

    public mutating func moveGroup(id movingID: UUID, before targetID: UUID) {
        var ordered = groups.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }

        guard let sourceIndex = ordered.firstIndex(where: { $0.id == movingID }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetID }),
              sourceIndex != targetIndex else {
            return
        }

        let moving = ordered.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        ordered.insert(moving, at: adjustedTargetIndex)

        for index in ordered.indices {
            ordered[index].sortOrder = index
        }
        groups = ordered
    }

    public mutating func moveCommand(id movingID: UUID, to targetID: UUID) {
        guard let movingCommand = commands.first(where: { $0.id == movingID }),
              let targetCommand = commands.first(where: { $0.id == targetID }),
              movingCommand.groupID == targetCommand.groupID,
              movingID != targetID else {
            return
        }

        let groupID = movingCommand.groupID
        var ordered = commands
            .filter { $0.groupID == groupID }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }

        guard let sourceIndex = ordered.firstIndex(where: { $0.id == movingID }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        let moving = ordered.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex : targetIndex
        ordered.insert(moving, at: adjustedTargetIndex)

        for index in ordered.indices {
            ordered[index].sortOrder = index
        }

        let reorderedByID = Dictionary(uniqueKeysWithValues: ordered.map { ($0.id, $0) })
        for index in commands.indices where commands[index].groupID == groupID {
            if let reordered = reorderedByID[commands[index].id] {
                commands[index] = reordered
            }
        }
    }

    @discardableResult
    public mutating func renameGroup(id groupID: UUID, to name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = groups.firstIndex(where: { $0.id == groupID }),
              !groups.contains(where: { $0.id != groupID && $0.name == trimmedName }) else {
            return false
        }

        groups[index].name = trimmedName
        return true
    }

    @discardableResult
    public mutating func deleteGroup(id groupID: UUID) -> UUID? {
        guard groups.count > 1,
              groups.contains(where: { $0.id == groupID }) else {
            return nil
        }

        groups.removeAll { $0.id == groupID }
        commands.removeAll { $0.groupID == groupID }

        groups.sort { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }

        for index in groups.indices {
            groups[index].sortOrder = index
        }

        return groups.first?.id
    }
}

public struct CommandGroup: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int

    public init(id: UUID = UUID(), name: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

public struct CommandItem: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var groupID: UUID
    public var name: String
    public var command: String
    public var iconName: String
    public var accentColor: String
    public var notes: String
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        groupID: UUID,
        name: String,
        command: String,
        iconName: String,
        accentColor: String,
        notes: String = "",
        sortOrder: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.command = command
        self.iconName = iconName
        self.accentColor = accentColor
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

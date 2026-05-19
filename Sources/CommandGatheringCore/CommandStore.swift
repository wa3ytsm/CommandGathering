import Foundation

public struct CommandStore: Sendable {
    public let rootDirectory: URL
    public let fileURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.fileURL = rootDirectory.appending(path: "commands.json", directoryHint: .notDirectory)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() throws -> CommandConfiguration? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CommandConfiguration.self, from: data)
    }

    public func loadOrCreate() throws -> CommandConfiguration {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        if let config = try load() {
            let migrated = migrate(config)
            if migrated != config {
                try save(migrated)
            }
            return migrated
        }

        let defaults = CommandConfiguration.defaultValue
        try save(defaults)
        return defaults
    }

    public func save(_ configuration: CommandConfiguration) throws {
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: .atomic)
    }

    private func migrate(_ configuration: CommandConfiguration) -> CommandConfiguration {
        var migrated = configuration
        let defaults = CommandConfiguration.defaultValue
        let hasOldGitStatusDefault = migrated.commands.contains { $0.command == "git status --short" }

        if migrated.schemaVersion != CommandConfiguration.currentSchemaVersion {
            migrated.schemaVersion = CommandConfiguration.currentSchemaVersion
        }

        migrated.workspace.sessions = migrated.workspace.sessions.map { session in
            guard session.workingDirectory == nil,
                  let commandID = session.boundCommandID,
                  let command = migrated.commands.first(where: { $0.id == commandID }),
                  let workingDirectory = TerminalCoordinator.resolveWorkingDirectory(from: command.command) else {
                return session
            }

            return PersistedTerminalSession(
                id: session.id,
                title: session.title,
                boundCommandID: session.boundCommandID,
                workingDirectory: workingDirectory,
                createdAt: session.createdAt
            )
        }

        guard hasOldGitStatusDefault else {
            return migrated
        }

        migrated.groups.removeAll { group in
            group.name == "项目" && !migrated.commands.contains { $0.groupID == group.id && $0.command != "git status --short" }
        }

        migrated.commands.removeAll { command in
            command.command == "git status --short"
        }

        for group in defaults.groups where !migrated.groups.contains(where: { $0.id == group.id || $0.name == group.name }) {
            migrated.groups.append(group)
        }

        for command in defaults.commands where !migrated.commands.contains(where: { $0.id == command.id || $0.name == command.name }) {
            migrated.commands.append(command)
        }

        migrated.groups.sort { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
        migrated.commands.sort { lhs, rhs in
            if lhs.groupID == rhs.groupID {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.groupID.uuidString < rhs.groupID.uuidString
        }
        return migrated
    }
}

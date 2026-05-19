import Foundation

public struct TerminalSession: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var boundCommandID: UUID?
    public var startupCommand: String?
    public var workingDirectory: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        boundCommandID: UUID? = nil,
        startupCommand: String? = nil,
        workingDirectory: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.boundCommandID = boundCommandID
        self.startupCommand = startupCommand
        self.workingDirectory = workingDirectory
        self.createdAt = createdAt
    }
}

public struct TerminalWorkspaceState: Codable, Equatable, Sendable {
    public var sessions: [PersistedTerminalSession]
    public var selectedSessionID: UUID?

    public init(sessions: [PersistedTerminalSession] = [], selectedSessionID: UUID? = nil) {
        self.sessions = sessions
        self.selectedSessionID = selectedSessionID
    }

    public static let empty = TerminalWorkspaceState()
}

public struct PersistedTerminalSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var boundCommandID: UUID?
    public var workingDirectory: String?
    public var createdAt: Date

    public init(
        id: UUID,
        title: String,
        boundCommandID: UUID?,
        workingDirectory: String?,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.boundCommandID = boundCommandID
        self.workingDirectory = workingDirectory
        self.createdAt = createdAt
    }
}

public extension TerminalSession {
    init(persistedSession: PersistedTerminalSession) {
        self.init(
            id: persistedSession.id,
            title: persistedSession.title,
            boundCommandID: persistedSession.boundCommandID,
            startupCommand: nil,
            workingDirectory: persistedSession.workingDirectory,
            createdAt: persistedSession.createdAt
        )
    }

    var persistedSession: PersistedTerminalSession {
        PersistedTerminalSession(
            id: id,
            title: title,
            boundCommandID: boundCommandID,
            workingDirectory: workingDirectory,
            createdAt: createdAt
        )
    }
}

public struct TerminalOpenResult: Equatable, Sendable {
    public var session: TerminalSession
    public var commandText: String?
    public var shouldExecuteCommand: Bool

    public init(session: TerminalSession, commandText: String?, shouldExecuteCommand: Bool) {
        self.session = session
        self.commandText = commandText
        self.shouldExecuteCommand = shouldExecuteCommand
    }
}

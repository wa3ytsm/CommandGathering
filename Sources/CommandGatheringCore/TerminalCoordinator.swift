import Foundation

public struct TerminalCoordinator: Sendable {
    public private(set) var sessions: [TerminalSession] = []
    public private(set) var selectedSessionID: UUID?
    private var commandBindings: [UUID: UUID] = [:]
    private let rootDirectory: URL

    public init(
        workspaceState: TerminalWorkspaceState = .empty,
        rootDirectory: URL = StorageRootLocator.resolveRootDirectory()
    ) {
        self.rootDirectory = rootDirectory
        restore(workspaceState)
    }

    public mutating func open(command: CommandItem) -> TerminalOpenResult {
        if let sessionID = commandBindings[command.id],
           let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }) {
            sessions[sessionIndex].groupID = command.groupID
            selectedSessionID = sessions[sessionIndex].id
            return TerminalOpenResult(session: sessions[sessionIndex], commandText: nil, shouldExecuteCommand: false)
        }

        let session = TerminalSession(
            title: command.name,
            boundCommandID: command.id,
            groupID: command.groupID,
            startupCommand: command.command,
            workingDirectory: Self.resolveWorkingDirectory(from: command.command)
        )
        sessions.append(session)
        commandBindings[command.id] = session.id
        selectedSessionID = session.id
        return TerminalOpenResult(session: session, commandText: command.command, shouldExecuteCommand: true)
    }

    public mutating func createBlankSession(groupID: UUID? = nil) -> TerminalOpenResult {
        let number = sessions.filter { $0.boundCommandID == nil }.count + 1
        let session = TerminalSession(
            title: "Shell \(number)",
            groupID: groupID,
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )
        sessions.append(session)
        selectedSessionID = session.id
        return TerminalOpenResult(session: session, commandText: nil, shouldExecuteCommand: false)
    }

    public mutating func createTemporarySession(defaultDirectory: String, groupID: UUID? = nil) -> TerminalOpenResult {
        let session = TerminalSession(
            title: "临时命令",
            groupID: groupID,
            startupCommand: "cd \(defaultDirectory)",
            workingDirectory: defaultDirectory
        )
        sessions.append(session)
        selectedSessionID = session.id
        return TerminalOpenResult(session: session, commandText: nil, shouldExecuteCommand: false)
    }

    public mutating func select(sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else {
            return
        }
        selectedSessionID = sessionID
    }

    public mutating func assignUngroupedSessions(to groupID: UUID) {
        for index in sessions.indices where sessions[index].groupID == nil {
            sessions[index].groupID = groupID
        }
    }

    public mutating func close(sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else {
            return
        }

        sessions.removeAll { $0.id == sessionID }
        commandBindings = commandBindings.filter { $0.value != sessionID }
        TerminalSessionStorage.deleteHistoryFile(for: sessionID, rootDirectory: rootDirectory)

        if selectedSessionID == sessionID {
            selectedSessionID = sessions.last?.id
        }
    }

    public mutating func moveSession(id movingID: UUID, to targetID: UUID) {
        guard let sourceIndex = sessions.firstIndex(where: { $0.id == movingID }),
              let targetIndex = sessions.firstIndex(where: { $0.id == targetID }),
              sourceIndex != targetIndex else {
            return
        }

        let moving = sessions.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex : targetIndex
        sessions.insert(moving, at: adjustedTargetIndex)
    }

    public mutating func restore(_ workspaceState: TerminalWorkspaceState) {
        var restoredSessions: [TerminalSession] = []
        var restoredBindings: [UUID: UUID] = [:]

        for persistedSession in workspaceState.sessions {
            var session = TerminalSession(persistedSession: persistedSession)
            if let commandID = session.boundCommandID {
                if restoredBindings[commandID] == nil {
                    restoredBindings[commandID] = session.id
                } else {
                    session.boundCommandID = nil
                }
            }
            restoredSessions.append(session)
        }

        sessions = restoredSessions
        commandBindings = restoredBindings

        if let selectedSessionID = workspaceState.selectedSessionID,
           sessions.contains(where: { $0.id == selectedSessionID }) {
            self.selectedSessionID = selectedSessionID
        } else {
            self.selectedSessionID = sessions.last?.id
        }
    }

    public func persistedWorkspaceState() -> TerminalWorkspaceState {
        TerminalWorkspaceState(
            sessions: sessions.map(\.persistedSession),
            selectedSessionID: selectedSessionID
        )
    }

    static func resolveWorkingDirectory(from command: String) -> String? {
        guard let firstMeaningfulLine = command
            .split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) else {
            return nil
        }

        guard firstMeaningfulLine.hasPrefix("cd ") || firstMeaningfulLine.hasPrefix("cd\t") else {
            return nil
        }

        let rawPath = firstMeaningfulLine
            .dropFirst(2)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPath.isEmpty else {
            return nil
        }

        let unquotedPath: String
        if (rawPath.hasPrefix("\"") && rawPath.hasSuffix("\"")) || (rawPath.hasPrefix("'") && rawPath.hasSuffix("'")) {
            unquotedPath = String(rawPath.dropFirst().dropLast())
        } else {
            unquotedPath = rawPath
        }

        let expandedPath = NSString(string: unquotedPath).expandingTildeInPath
        return expandedPath.isEmpty ? nil : expandedPath
    }
}

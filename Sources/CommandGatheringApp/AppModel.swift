import CommandGatheringCore
import Foundation

@MainActor
@Observable
final class AppModel {
    var configuration: CommandConfiguration
    var terminalCoordinator: TerminalCoordinator
    var presentedEditor: CommandEditorMode?
    var presentedGroupEditor: GroupEditorMode?
    var errorMessage: String?
    var selectedGroupID: UUID?
    var newGroupName = ""
    var draggedGroupID: UUID?
    var draggedCommandID: UUID?
    var draggedSessionID: UUID?
    var isSidebarHidden: Bool {
        didSet {
            UserDefaults.standard.set(isSidebarHidden, forKey: "isSidebarHidden")
        }
    }
    var themeMode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    private let store: CommandStore
    private let temporaryTerminalDirectory = StorageRootLocator.resolveDefaultWorkspaceDirectory().path

    init(store: CommandStore = CommandStore(rootDirectory: StorageRootLocator.resolveRootDirectory())) {
        self.store = store
        self.isSidebarHidden = UserDefaults.standard.bool(forKey: "isSidebarHidden")
        let rawThemeMode = UserDefaults.standard.string(forKey: "themeMode") ?? AppThemeMode.dark.rawValue
        self.themeMode = AppThemeMode(rawValue: rawThemeMode) ?? .dark
        self.terminalCoordinator = TerminalCoordinator()
        do {
            self.configuration = try store.loadOrCreate()
            self.terminalCoordinator = TerminalCoordinator(workspaceState: self.configuration.workspace)
            self.selectedGroupID = self.configuration.groups.sorted { $0.sortOrder < $1.sortOrder }.first?.id
        } catch {
            self.configuration = .defaultValue
            self.terminalCoordinator = TerminalCoordinator(workspaceState: self.configuration.workspace)
            self.selectedGroupID = self.configuration.groups.sorted { $0.sortOrder < $1.sortOrder }.first?.id
            self.errorMessage = "命令配置读取失败，已加载默认配置：\(error.localizedDescription)"
        }
    }

    var sortedGroups: [CommandGroup] {
        configuration.groups.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var selectedSessionID: UUID? {
        terminalCoordinator.selectedSessionID
    }

    var selectedSession: TerminalSession? {
        guard let selectedSessionID else {
            return nil
        }
        return terminalCoordinator.sessions.first { $0.id == selectedSessionID }
    }

    var selectedGroup: CommandGroup? {
        if let selectedGroupID,
           let group = configuration.groups.first(where: { $0.id == selectedGroupID }) {
            return group
        }
        return sortedGroups.first
    }

    var selectedGroupCommands: [CommandItem] {
        guard let selectedGroup else {
            return []
        }
        return commands(in: selectedGroup)
    }

    func commands(in group: CommandGroup) -> [CommandItem] {
        configuration.commands
            .filter { $0.groupID == group.id }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    func open(command: CommandItem) {
        _ = terminalCoordinator.open(command: command)
        _ = persist()
    }

    func createBlankTerminal() {
        _ = terminalCoordinator.createBlankSession()
        _ = persist()
    }

    func createTemporaryTerminal() {
        _ = terminalCoordinator.createTemporarySession(defaultDirectory: temporaryTerminalDirectory)
        _ = persist()
    }

    func toggleSidebar() {
        isSidebarHidden.toggle()
    }

    func toggleThemeMode() {
        themeMode = themeMode.toggled
    }

    func select(group: CommandGroup) {
        selectedGroupID = group.id
    }

    func createGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }
        guard !configuration.groups.contains(where: { $0.name == name }) else {
            errorMessage = "分组已存在"
            return
        }

        let sortOrder = (configuration.groups.map(\.sortOrder).max() ?? -1) + 1
        let group = CommandGroup(name: name, sortOrder: sortOrder)
        configuration.groups.append(group)
        selectedGroupID = group.id
        newGroupName = ""
        persist()
    }

    func moveGroup(id movingID: UUID, before targetID: UUID) {
        configuration.moveGroup(id: movingID, before: targetID)
        selectedGroupID = movingID
        persist()
    }

    func renameGroup(using draft: GroupDraft) {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "分组名称不能为空"
            return
        }
        guard !configuration.groups.contains(where: { $0.id != draft.id && $0.name == name }) else {
            errorMessage = "分组已存在"
            return
        }
        guard configuration.renameGroup(id: draft.id, to: name) else {
            errorMessage = "分组不存在"
            return
        }

        persist()
        presentedGroupEditor = nil
    }

    func delete(group: CommandGroup) {
        let previousSelectedID = selectedGroupID
        guard let fallbackGroupID = configuration.deleteGroup(id: group.id) else {
            errorMessage = "至少保留一个分组"
            return
        }

        if previousSelectedID == group.id || !configuration.groups.contains(where: { $0.id == previousSelectedID }) {
            selectedGroupID = fallbackGroupID
        }
        persist()
    }

    func moveCommand(id movingID: UUID, to targetID: UUID) {
        configuration.moveCommand(id: movingID, to: targetID)
        draggedCommandID = movingID
        persist()
    }

    func select(sessionID: UUID) {
        terminalCoordinator.select(sessionID: sessionID)
        _ = persist()
    }

    func close(sessionID: UUID) {
        terminalCoordinator.close(sessionID: sessionID)
        _ = persist()
    }

    func moveSession(id movingID: UUID, to targetID: UUID) {
        terminalCoordinator.moveSession(id: movingID, to: targetID)
        draggedSessionID = movingID
        _ = persist()
    }

    func commandValidationMessage(for draft: CommandDraft) -> String? {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = draft.command.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            return "命令名称不能为空"
        }
        if trimmedCommand.isEmpty {
            return "命令内容不能为空"
        }
        return nil
    }

    @discardableResult
    func save(command draft: CommandDraft) -> Bool {
        let now = Date()
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCommand = draft.command.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validationMessage = commandValidationMessage(for: draft) {
            errorMessage = validationMessage
            return false
        }

        if let existingID = draft.id,
           let index = configuration.commands.firstIndex(where: { $0.id == existingID }) {
            configuration.commands[index].groupID = draft.groupID
            configuration.commands[index].name = trimmedName
            configuration.commands[index].command = trimmedCommand
            configuration.commands[index].iconName = draft.iconName
            configuration.commands[index].accentColor = draft.accentColor
            configuration.commands[index].notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            configuration.commands[index].updatedAt = now
        } else {
            let nextSortOrder = (commands(in: group(for: draft.groupID)).map(\.sortOrder).max() ?? -1) + 1
            configuration.commands.append(
                CommandItem(
                    groupID: draft.groupID,
                    name: trimmedName,
                    command: trimmedCommand,
                    iconName: draft.iconName,
                    accentColor: draft.accentColor,
                    notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    sortOrder: nextSortOrder,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        guard persist() else {
            return false
        }
        selectedGroupID = draft.groupID
        presentedEditor = nil
        return true
    }

    func delete(command: CommandItem) {
        configuration.commands.removeAll { $0.id == command.id }
        persist()
    }

    func group(for id: UUID) -> CommandGroup {
        configuration.groups.first { $0.id == id } ?? sortedGroups[0]
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            configuration.workspace = terminalCoordinator.persistedWorkspaceState()
            try store.save(configuration)
            return true
        } catch {
            errorMessage = "命令配置保存失败：\(error.localizedDescription)"
            return false
        }
    }
}

enum CommandEditorMode: Identifiable, Equatable {
    case create(groupID: UUID)
    case edit(CommandItem)

    var id: String {
        switch self {
        case .create(let groupID):
            "create-\(groupID.uuidString)"
        case .edit(let command):
            "edit-\(command.id.uuidString)"
        }
    }
}

struct CommandDraft: Equatable {
    var id: UUID?
    var groupID: UUID
    var name: String
    var command: String
    var iconName: String
    var accentColor: String
    var notes: String

    init(mode: CommandEditorMode, fallbackGroupID: UUID) {
        switch mode {
        case .create(let groupID):
            self.id = nil
            self.groupID = groupID
            self.name = "新命令"
            self.command = "pwd"
            self.iconName = "terminal"
            self.accentColor = "#22C55E"
            self.notes = ""
        case .edit(let command):
            self.id = command.id
            self.groupID = command.groupID
            self.name = command.name
            self.command = command.command
            self.iconName = command.iconName
            self.accentColor = command.accentColor
            self.notes = command.notes
        }

        if self.groupID == UUID() {
            self.groupID = fallbackGroupID
        }
    }
}

enum GroupEditorMode: Identifiable, Equatable {
    case edit(CommandGroup)

    var id: String {
        switch self {
        case .edit(let group):
            "edit-\(group.id.uuidString)"
        }
    }
}

struct GroupDraft: Equatable {
    var id: UUID
    var name: String

    init(mode: GroupEditorMode) {
        switch mode {
        case .edit(let group):
            self.id = group.id
            self.name = group.name
        }
    }
}

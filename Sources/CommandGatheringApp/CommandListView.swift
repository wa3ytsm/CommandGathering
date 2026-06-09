import CommandGatheringCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CommandListView: View {
    @Bindable var model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ZStack {
                Rectangle()
                    .fill(Theme.panelBackground)
                    .contentShape(Rectangle())

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 360), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(model.selectedGroupCommands) { command in
                            CommandCard(command: command, model: model)
                                .onDrag {
                                    model.draggedCommandID = command.id
                                    return NSItemProvider(object: command.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: CommandDropDelegate(targetCommandID: command.id, model: model)
                                )
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .contentShape(Rectangle())

                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: commandContentHeight(containerWidth: proxy.size.width))

                        BlankCommandContextMenuView(createCommand: createCommand)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.panelBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(model.selectedGroup?.name ?? "命令")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)

            Spacer()

            Button {
                createCommand()
            } label: {
                Label("新建命令", systemImage: "plus.square")
                    .font(.system(size: 13, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 9)
                    .frame(height: Theme.compactControlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("在当前分组中新建保存的命令")

            Button {
                model.createTemporaryTerminal()
            } label: {
                Label("临时命令", systemImage: "terminal")
                    .font(.system(size: 13, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 9)
                    .frame(height: Theme.compactControlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("新建临时终端，不保存命令")

            Button {
                model.presentSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: Theme.compactControlHeight, height: Theme.compactControlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("设置")

            Button {
                model.toggleThemeMode()
            } label: {
                Image(systemName: model.themeMode.toggleIconName)
                    .frame(width: Theme.compactControlHeight, height: Theme.compactControlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.compactHeaderHeight)
        .background(Theme.appBackground)
    }

    private func createCommand() {
        if let groupID = model.selectedGroup?.id {
            model.presentedEditor = .create(groupID: groupID)
        }
    }

    private func commandContentHeight(containerWidth: CGFloat) -> CGFloat {
        let commandCount = model.selectedGroupCommands.count
        guard commandCount > 0 else {
            return 0
        }

        let horizontalPadding: CGFloat = 16
        let spacing: CGFloat = 8
        let minimumCardWidth: CGFloat = 220
        let usableWidth = max(minimumCardWidth, containerWidth - horizontalPadding)
        let columns = max(1, Int((usableWidth + spacing) / (minimumCardWidth + spacing)))
        let rowCount = Int(ceil(Double(commandCount) / Double(columns)))
        return CGFloat(rowCount) * Theme.compactCardHeight + CGFloat(max(0, rowCount - 1)) * spacing + horizontalPadding
    }
}

private struct CommandDropDelegate: DropDelegate {
    let targetCommandID: UUID
    let model: AppModel

    func dropEntered(info: DropInfo) {
        guard let draggedCommandID = model.draggedCommandID,
              draggedCommandID != targetCommandID else {
            return
        }
        model.moveCommand(id: draggedCommandID, to: targetCommandID)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.draggedCommandID = nil
        return true
    }
}

private struct CommandCard: View {
    let command: CommandItem
    @Bindable var model: AppModel

    var body: some View {
        Button {
            model.open(command: command)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbolName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.82))
                    .frame(width: 20, height: 20)
                    .background(Theme.color(hex: command.accentColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(command.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Menu {
                    Button("编辑") {
                        model.presentedEditor = .edit(command)
                    }
                    Button("删除", role: .destructive) {
                        model.delete(command: command)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
                .help("命令操作")
            }
            .padding(.horizontal, 7)
            .frame(
                maxWidth: .infinity,
                minHeight: Theme.compactCardHeight,
                maxHeight: Theme.compactCardHeight,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.controlBackground)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.color(hex: command.accentColor))
                            .frame(width: 3)
                    }
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑命令") {
                model.presentedEditor = .edit(command)
            }
            Button("删除", role: .destructive) {
                model.delete(command: command)
            }
        }
    }

    private var symbolName: String {
        switch command.iconName {
        case "branch":
            return "point.3.connected.trianglepath.dotted"
        case "hammer":
            return "hammer.fill"
        case "play":
            return "play.fill"
        default:
            return "terminal.fill"
        }
    }
}

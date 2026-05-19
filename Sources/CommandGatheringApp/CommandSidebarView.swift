import CommandGatheringCore
import SwiftUI
import UniformTypeIdentifiers

struct CommandSidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            groupTree
            newGroupBar
        }
        .background(Theme.panelBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.primaryAccent)

            Text("命令分组")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)

            Spacer()

            Button {
                model.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.leading")
                    .frame(width: Theme.compactControlHeight, height: Theme.compactControlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText)
            .help("隐藏侧边栏")
        }
        .padding(.horizontal, 12)
        .frame(height: Theme.compactHeaderHeight)
        .background(Theme.appBackground)
    }

    private var groupTree: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(model.sortedGroups) { group in
                    GroupRow(
                        group: group,
                        commandCount: model.commands(in: group).count,
                        isSelected: model.selectedGroup?.id == group.id,
                        editAction: {
                            model.presentedGroupEditor = .edit(group)
                        },
                        deleteAction: {
                            model.delete(group: group)
                        }
                    ) {
                        model.select(group: group)
                    }
                    .onDrag {
                        model.draggedGroupID = group.id
                        return NSItemProvider(object: group.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: GroupDropDelegate(targetGroupID: group.id, model: model)
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    private var newGroupBar: some View {
        HStack(spacing: 8) {
            TextField("新建分组", text: $model.newGroupName)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.primaryText)
                .tint(Theme.primaryAccent)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onSubmit {
                    model.createGroup()
                }

            Button {
                model.createGroup()
            } label: {
                Image(systemName: "plus")
                    .frame(width: Theme.compactControlHeight, height: Theme.compactControlHeight)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("新建分组")
        }
        .padding(12)
        .frame(height: Theme.sidebarFooterHeight)
        .background(Theme.appBackground)
    }
}

private struct GroupDropDelegate: DropDelegate {
    let targetGroupID: UUID
    let model: AppModel

    func dropEntered(info: DropInfo) {
        guard let draggedGroupID = model.draggedGroupID,
              draggedGroupID != targetGroupID else {
            return
        }
        model.moveGroup(id: draggedGroupID, before: targetGroupID)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.draggedGroupID = nil
        return true
    }
}

private struct GroupRow: View {
    let group: CommandGatheringCore.CommandGroup
    let commandCount: Int
    let isSelected: Bool
    let editAction: () -> Void
    let deleteAction: () -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.primaryAccent : Theme.secondaryText)
                    .frame(width: 20)

                Text(group.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
                    .lineLimit(1)

                Spacer()

                Text("\(commandCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.mutedText)
                    .frame(minWidth: 22)

                Menu {
                    Button("编辑名称", action: editAction)
                    Button("删除分组", role: .destructive, action: deleteAction)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .foregroundStyle(Theme.secondaryText)
                .help("分组操作")
            }
            .padding(.horizontal, 10)
            .frame(height: Theme.compactRowHeight)
            .background(isSelected ? Theme.controlBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("编辑名称", action: editAction)
            Button("删除分组", role: .destructive, action: deleteAction)
        }
    }
}

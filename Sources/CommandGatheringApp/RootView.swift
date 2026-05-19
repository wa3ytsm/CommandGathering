import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.isSidebarHidden {
                HStack(spacing: 0) {
                    sidebarRestoreRail
                    detailContent
                }
            } else {
                PersistentSplitView(
                    storageKey: "sidebarWidth",
                    defaultSidebarWidth: 280,
                    minSidebarWidth: 220,
                    maxSidebarWidth: 420,
                    minDetailWidth: 640
                ) {
                    CommandSidebarView(model: model)
                } detail: {
                    detailContent
                }
            }
        }
        .background(Theme.appBackground)
        .preferredColorScheme(model.themeMode.colorScheme)
        .sheet(item: $model.presentedEditor) { mode in
            CommandEditorView(
                model: model,
                draft: CommandDraft(
                    mode: mode,
                    fallbackGroupID: model.sortedGroups.first?.id ?? UUID()
                )
            )
        }
        .sheet(item: $model.presentedGroupEditor) { mode in
            GroupEditorView(
                model: model,
                draft: GroupDraft(mode: mode)
            )
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("知道了") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var detailContent: some View {
        PersistentVerticalStackSplitView(
            storageKey: "commandListHeight.compactV2",
            defaultTopHeight: 100,
            minTopHeight: 92,
            maxTopHeight: 140,
            minBottomHeight: 260
        ) {
            CommandListView(model: model)
        } bottom: {
            TerminalTabsView(model: model)
                .frame(minWidth: 640)
        }
    }

    private var sidebarRestoreRail: some View {
        VStack {
            Button {
                model.toggleSidebar()
            } label: {
                Image(systemName: "sidebar.left")
                    .frame(width: 28, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 14)

            Spacer()
        }
        .frame(width: 44)
        .background(Theme.appBackground)
    }
}

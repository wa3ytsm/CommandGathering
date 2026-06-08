import CommandGatheringCore
import SwiftUI
import UniformTypeIdentifiers

struct TerminalTabsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()
                .overlay(Theme.mutedText.opacity(0.22))

            ZStack {
                ForEach(model.terminalCoordinator.sessions) { session in
                    TerminalPaneView(model: model, session: session)
                        .opacity(model.isTerminalSessionSelected(session.id) ? 1 : 0)
                        .allowsHitTesting(model.isTerminalSessionSelected(session.id))
                }

                if model.visibleTerminalSessions.isEmpty {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: Theme.terminalBackground))

            Color.clear
                .frame(height: Theme.terminalBottomInset)
        }
        .background(Theme.appBackground)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.visibleTerminalSessions) { session in
                        TerminalTabButton(
                            session: session,
                            isSelected: model.isTerminalSessionSelected(session.id),
                            select: { model.select(sessionID: session.id) },
                            close: { model.close(sessionID: session.id) }
                        )
                        .onDrag {
                            model.draggedSessionID = session.id
                            return NSItemProvider(object: session.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: TerminalSessionDropDelegate(targetSessionID: session.id, model: model)
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
            }

            Button {
                model.createBlankTerminal()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.primaryText)
            .background(Theme.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("新建空白终端")
            .padding(.trailing, 10)
        }
        .frame(height: 36)
        .background(Theme.appBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "terminal")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(Theme.primaryAccent)

            Text("选择左侧命令，或点击 + 新建空白终端")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
        }
    }
}

private struct TerminalSessionDropDelegate: DropDelegate {
    let targetSessionID: UUID
    let model: AppModel

    func dropEntered(info: DropInfo) {
        guard let draggedSessionID = model.draggedSessionID,
              draggedSessionID != targetSessionID else {
            return
        }
        model.moveSession(id: draggedSessionID, to: targetSessionID)
    }

    func performDrop(info: DropInfo) -> Bool {
        model.draggedSessionID = nil
        return true
    }
}

private struct TerminalTabButton: View {
    let session: TerminalSession
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: select) {
                HStack(spacing: 7) {
                    Image(systemName: session.boundCommandID == nil ? "terminal" : "play.fill")
                        .font(.caption)
                    Text(session.title)
                        .lineLimit(1)
                        .frame(maxWidth: 180, alignment: .leading)
                }
                .padding(.leading, 10)
                .frame(height: 30)
            }
            .buttonStyle(.plain)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("关闭终端")
        }
        .padding(.trailing, 7)
        .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
        .background(isSelected ? Theme.controlBackground : Theme.controlBackgroundHover.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

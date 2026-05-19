import CommandGatheringCore
import SwiftUI

struct CommandEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State var draft: CommandDraft
    @State private var inlineError: String?

    private let accentOptions = ["#22C55E", "#38BDF8", "#F59E0B", "#EF4444", "#A78BFA", "#F472B6"]
    private let iconOptions = [
        ("terminal", "terminal.fill"),
        ("branch", "point.3.connected.trianglepath.dotted"),
        ("hammer", "hammer.fill"),
        ("play", "play.fill")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(draft.id == nil ? "新建命令" : "编辑命令")
                .font(.title2.weight(.semibold))

            if let inlineError {
                Label(inlineError, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            Form {
                TextField("名称", text: $draft.name)
                    .onChange(of: draft.name) { _, _ in
                        inlineError = nil
                    }

                Picker("分组", selection: $draft.groupID) {
                    ForEach(model.sortedGroups) { group in
                        Text(group.name).tag(group.id)
                    }
                }

                Picker("图标", selection: $draft.iconName) {
                    ForEach(iconOptions, id: \.0) { value, symbol in
                        Label(value, systemImage: symbol).tag(value)
                    }
                }

                HStack {
                    Text("颜色")
                    Spacer()
                    ForEach(accentOptions, id: \.self) { color in
                        Button {
                            draft.accentColor = color
                        } label: {
                            Circle()
                                .fill(Theme.color(hex: color))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if draft.accentColor == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.black.opacity(0.75))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("说明", text: $draft.notes)

                VStack(alignment: .leading, spacing: 8) {
                    Text("命令")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $draft.command)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onChange(of: draft.command) { _, _ in
                            inlineError = nil
                        }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    if let validationMessage = model.commandValidationMessage(for: draft) {
                        inlineError = validationMessage
                        return
                    }

                    if model.save(command: draft) {
                        dismiss()
                    } else {
                        inlineError = model.errorMessage
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 560)
        .frame(minHeight: 520)
    }
}

import SwiftUI

struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: AppModel
    @State var draft: GroupDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑分组")
                .font(.title2.weight(.semibold))

            TextField("分组名称", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    model.renameGroup(using: draft)
                }

            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                Button("保存") {
                    model.renameGroup(using: draft)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 360)
    }
}

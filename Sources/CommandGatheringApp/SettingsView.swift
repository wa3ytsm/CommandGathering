import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .overlay(Theme.mutedText.opacity(0.18))

            HStack(spacing: 0) {
                sidebar

                Divider()
                    .overlay(Theme.mutedText.opacity(0.18))

                terminalSettings
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .overlay(Theme.mutedText.opacity(0.18))

            footer
        }
        .frame(width: 640, height: 430)
        .background(Theme.appBackground)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.primaryAccent)
                .frame(width: 34, height: 34)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("设置")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Text("管理 Command Gathering 的应用行为")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSidebarItem(
                title: "终端",
                subtitle: "Tab 与分组行为",
                systemImage: "terminal",
                isSelected: true
            )

            Spacer()
        }
        .padding(14)
        .frame(width: 190)
        .background(Theme.panelBackground)
    }

    private var terminalSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsToggleRow(
                    title: "终端跟随分组",
                    systemImage: "rectangle.stack",
                    isOn: Binding(
                        get: { model.terminalFollowsSelectedGroup },
                        set: { model.terminalFollowsSelectedGroup = $0 }
                    )
                )
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.appBackground)
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button("完成") {
                model.dismissSettings()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.panelBackground)
    }
}

private struct SettingsSidebarItem: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.primaryAccent : Theme.secondaryText)
                .frame(width: 24, height: 24)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mutedText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(isSelected ? Theme.controlBackgroundHover : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryAccent)
                .frame(width: 34, height: 34)
                .background(Theme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)

            Spacer(minLength: 10)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(16)
        .background(Theme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.mutedText.opacity(0.16), lineWidth: 1)
        )
    }
}

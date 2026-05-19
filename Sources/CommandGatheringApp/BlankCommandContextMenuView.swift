import AppKit
import SwiftUI

struct BlankCommandContextMenuView: NSViewRepresentable {
    let createCommand: () -> Void

    func makeNSView(context: Context) -> ContextMenuPassthroughView {
        let view = ContextMenuPassthroughView()
        view.createCommand = createCommand
        return view
    }

    func updateNSView(_ nsView: ContextMenuPassthroughView, context: Context) {
        nsView.createCommand = createCommand
    }
}

final class ContextMenuPassthroughView: NSView {
    var createCommand: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "新建命令", action: #selector(createCommandAction), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func createCommandAction() {
        createCommand?()
    }
}

import AppKit
import SwiftUI

struct PersistentSplitView<Sidebar: View, Detail: View>: NSViewRepresentable {
    let storageKey: String
    let defaultSidebarWidth: CGFloat
    let minSidebarWidth: CGFloat
    let maxSidebarWidth: CGFloat
    let minDetailWidth: CGFloat
    let sidebar: Sidebar
    let detail: Detail

    init(
        storageKey: String,
        defaultSidebarWidth: CGFloat,
        minSidebarWidth: CGFloat,
        maxSidebarWidth: CGFloat,
        minDetailWidth: CGFloat,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.storageKey = storageKey
        self.defaultSidebarWidth = defaultSidebarWidth
        self.minSidebarWidth = minSidebarWidth
        self.maxSidebarWidth = maxSidebarWidth
        self.minDetailWidth = minDetailWidth
        self.sidebar = sidebar()
        self.detail = detail()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let sidebarHost = NSHostingView(rootView: sidebar)
        let detailHost = NSHostingView(rootView: detail)
        context.coordinator.sidebarHost = sidebarHost
        context.coordinator.detailHost = detailHost

        splitView.addArrangedSubview(sidebarHost)
        splitView.addArrangedSubview(detailHost)

        DispatchQueue.main.async {
            let savedWidth = UserDefaults.standard.object(forKey: storageKey) as? Double
            let width = CGFloat(savedWidth ?? Double(defaultSidebarWidth))
            splitView.setPosition(width, ofDividerAt: 0)
        }

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sidebarHost?.rootView = sidebar
        context.coordinator.detailHost?.rootView = detail
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: PersistentSplitView
        weak var sidebarHost: NSHostingView<Sidebar>?
        weak var detailHost: NSHostingView<Detail>?

        init(parent: PersistentSplitView) {
            self.parent = parent
        }

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            parent.minSidebarWidth
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            min(parent.maxSidebarWidth, max(parent.minSidebarWidth, splitView.bounds.width - parent.minDetailWidth))
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView,
                  splitView.subviews.count >= 2 else {
                return
            }

            let sidebarWidth = splitView.subviews[0].frame.width
            let detailWidth = splitView.subviews[1].frame.width
            guard sidebarWidth >= parent.minSidebarWidth,
                  detailWidth >= parent.minDetailWidth else {
                return
            }

            UserDefaults.standard.set(Double(sidebarWidth), forKey: parent.storageKey)
        }
    }
}

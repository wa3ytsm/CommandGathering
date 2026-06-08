import AppKit
import SwiftUI

struct PersistentVerticalStackSplitView<Top: View, Bottom: View>: View {
    let storageKey: String
    let defaultTopHeight: CGFloat
    let minTopHeight: CGFloat
    let maxTopHeight: CGFloat
    let minBottomHeight: CGFloat
    let top: Top
    let bottom: Bottom

    @State private var topHeight: CGFloat
    @State private var dragStartHeight: CGFloat?

    init(
        storageKey: String,
        defaultTopHeight: CGFloat,
        minTopHeight: CGFloat,
        maxTopHeight: CGFloat,
        minBottomHeight: CGFloat,
        @ViewBuilder top: () -> Top,
        @ViewBuilder bottom: () -> Bottom
    ) {
        self.storageKey = storageKey
        self.defaultTopHeight = defaultTopHeight
        self.minTopHeight = minTopHeight
        self.maxTopHeight = maxTopHeight
        self.minBottomHeight = minBottomHeight
        self.top = top()
        self.bottom = bottom()

        let savedHeight = UserDefaults.standard.object(forKey: storageKey) as? Double
        let initialHeight = CGFloat(savedHeight ?? Double(defaultTopHeight))
        self._topHeight = State(initialValue: initialHeight)
    }

    var body: some View {
        GeometryReader { proxy in
            let constrainedTopHeight = constrainedHeight(for: proxy.size.height)

            VStack(spacing: 0) {
                top
                    .frame(height: constrainedTopHeight)

                ResizeDivider(resizeDrag: resizeGesture(totalHeight: proxy.size.height))

                bottom
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                applyConstraint(totalHeight: proxy.size.height)
            }
            .onChange(of: proxy.size.height) { _, newHeight in
                applyConstraint(totalHeight: newHeight)
            }
        }
    }

    private func resizeGesture(totalHeight: CGFloat) -> AnyGesture<DragGesture.Value> {
        AnyGesture(DragGesture()
            .onChanged { value in
                if dragStartHeight == nil {
                    dragStartHeight = topHeight
                }

                let proposedHeight = (dragStartHeight ?? topHeight) + value.translation.height
                topHeight = constrainedHeight(proposedHeight, totalHeight: totalHeight)
            }
            .onEnded { _ in
                dragStartHeight = nil
                topHeight = constrainedHeight(topHeight, totalHeight: totalHeight)
                UserDefaults.standard.set(Double(topHeight), forKey: storageKey)
            }
        )
    }

    private func applyConstraint(totalHeight: CGFloat) {
        topHeight = constrainedHeight(topHeight, totalHeight: totalHeight)
    }

    private func constrainedHeight(for totalHeight: CGFloat) -> CGFloat {
        constrainedHeight(topHeight, totalHeight: totalHeight)
    }

    private func constrainedHeight(_ proposedHeight: CGFloat, totalHeight: CGFloat) -> CGFloat {
        clampTopHeight(
            proposedHeight,
            minTopHeight: minTopHeight,
            maxTopHeight: maxTopHeight,
            minBottomHeight: minBottomHeight,
            totalHeight: totalHeight
        )
    }
}

func clampTopHeight(
    _ proposedHeight: CGFloat,
    minTopHeight: CGFloat,
    maxTopHeight: CGFloat,
    minBottomHeight: CGFloat,
    totalHeight: CGFloat
) -> CGFloat {
    let availableMaxHeight = max(minTopHeight, totalHeight - minBottomHeight)
    let upperBound = min(maxTopHeight, availableMaxHeight)
    return min(max(proposedHeight, minTopHeight), upperBound)
}

private struct ResizeDivider: View {
    let resizeDrag: AnyGesture<DragGesture.Value>
    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(isHovering ? Theme.controlBackgroundHover : Theme.appBackground)
            .frame(height: 6)
            .overlay {
                Capsule()
                    .fill(isHovering ? Theme.primaryAccent : Theme.mutedText.opacity(0.75))
                    .frame(width: 52, height: 2.5)
            }
            .contentShape(Rectangle())
            .gesture(resizeDrag)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .help("拖动调整终端区域高度")
    }
}

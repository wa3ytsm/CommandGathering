import CoreGraphics

enum CommandListSplitLayout {
    static let storageKey = "commandListHeight.relaxedV1"
    static let defaultTopHeight: CGFloat = 240
    static let minTopHeight: CGFloat = 140
    static let maxTopHeight: CGFloat = 520
    static let minBottomHeight: CGFloat = 260

    static func constrainedTopHeight(_ proposedHeight: CGFloat, totalHeight: CGFloat) -> CGFloat {
        clampTopHeight(
            proposedHeight,
            minTopHeight: minTopHeight,
            maxTopHeight: maxTopHeight,
            minBottomHeight: minBottomHeight,
            totalHeight: totalHeight
        )
    }
}

import AppKit
import SwiftUI

enum AppThemeMode: String {
    case dark
    case light

    var colorScheme: ColorScheme {
        switch self {
        case .dark:
            .dark
        case .light:
            .light
        }
    }

    var toggleIconName: String {
        switch self {
        case .dark:
            "sun.max"
        case .light:
            "moon"
        }
    }

    var toggled: AppThemeMode {
        switch self {
        case .dark:
            .light
        case .light:
            .dark
        }
    }
}

enum Theme {
    static let compactHeaderHeight: CGFloat = 40
    static let compactControlHeight: CGFloat = 28
    static let compactRowHeight: CGFloat = 32
    static let compactCardHeight: CGFloat = 36
    static let sidebarFooterHeight: CGFloat = 50
    static let terminalBottomInset: CGFloat = 12
    static let appBackground = dynamicColor(light: nsColor(0xf3, 0xf6, 0xfa), dark: nsColor(0x0a, 0x0f, 0x14))
    static let panelBackground = dynamicColor(light: nsColor(0xff, 0xff, 0xff), dark: nsColor(0x11, 0x17, 0x1f))
    static let controlBackground = dynamicColor(light: nsColor(0xe7, 0xec, 0xf3), dark: nsColor(0x1a, 0x22, 0x2d))
    static let controlBackgroundHover = dynamicColor(light: nsColor(0xda, 0xe2, 0xec), dark: nsColor(0x22, 0x2b, 0x37))
    static let primaryText = dynamicColor(light: nsColor(0x13, 0x1a, 0x24), dark: nsColor(0xf4, 0xf7, 0xfb))
    static let secondaryText = dynamicColor(light: nsColor(0x55, 0x62, 0x70), dark: nsColor(0xa7, 0xb0, 0xbc))
    static let mutedText = dynamicColor(light: nsColor(0x7b, 0x86, 0x94), dark: nsColor(0x75, 0x80, 0x8d))
    static let terminalBackground = dynamicNSColor(light: nsColor(0xfb, 0xfc, 0xfe), dark: nsColor(0x0f, 0x17, 0x2a))
    static let terminalForeground = dynamicNSColor(light: nsColor(0x16, 0x1d, 0x2b), dark: nsColor(0xe5, 0xe7, 0xeb))
    static let terminalSelection = NSColor.systemBlue.withAlphaComponent(0.35)
    static let terminalCaret = dynamicNSColor(light: nsColor(0x0f, 0x9f, 0x5f), dark: nsColor(0x22, 0xc5, 0x5e))
    static let primaryAccent = dynamicColor(light: nsColor(0x0f, 0x9f, 0x5f), dark: nsColor(0x22, 0xc5, 0x5e))

    static func color(hex: String) -> Color {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return primaryAccent
        }

        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }

    static func nsColor(hex: String) -> NSColor {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
            return terminalCaret
        }

        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    private static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
            return bestMatch == .darkAqua ? dark : light
        }
    }

    private static func nsColor(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

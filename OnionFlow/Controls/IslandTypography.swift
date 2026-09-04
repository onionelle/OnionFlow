import SwiftUI

/// 全 App 字体：只用整数号。
/// 10pt 及以上用 light（细体）；8–9pt 用 regular，再细会发糊。
enum IslandTypography {
    static let display = Font.system(size: 12, weight: .light)
    static let title = Font.system(size: 10, weight: .light)
    static let body = Font.system(size: 9, weight: .regular)
    static let caption = Font.system(size: 8, weight: .regular)
    static let hint = Font.system(size: 9, weight: .regular)
    static let micro = Font.system(size: 8, weight: .regular)
    static let mono = Font.system(size: 8, weight: .regular, design: .monospaced)
    static let icon = Font.system(size: 10, weight: .light)
}

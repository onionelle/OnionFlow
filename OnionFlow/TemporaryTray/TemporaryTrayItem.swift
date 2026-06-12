import Foundation

enum TemporaryTrayTransferMode: Equatable {
    case move
    case copy

    var label: String {
        switch self {
        case .move:
            return "移"
        case .copy:
            return "拷"
        }
    }

    var systemImage: String {
        switch self {
        case .move:
            return "arrow.right"
        case .copy:
            return "doc.on.doc"
        }
    }

    var helpText: String {
        switch self {
        case .move:
            return "拖出后移动到目标位置"
        case .copy:
            return "拖出后复制到目标位置"
        }
    }
}

/// 临时暂存项目只描述当前会话引用及可展示状态，不直接访问文件系统。
struct TemporaryTrayItem: Identifiable {
    let url: URL
    let transferMode: TemporaryTrayTransferMode
    var isAvailable: Bool

    var id: String {
        url.path
    }

    var displayName: String {
        url.lastPathComponent
    }
}

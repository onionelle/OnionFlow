import Foundation

/// 表示单行歌词的模型，包含时间戳和歌词文本内容。
struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval // 时间戳（以秒为单位）
    let text: String       // 歌词内容
}

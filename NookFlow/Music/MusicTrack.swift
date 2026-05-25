import Foundation

// 当前加载曲目的轻量模型；标题只来自文件名，不读取 metadata。
struct MusicTrack: Equatable {
    let url: URL
    let title: String
    let duration: TimeInterval
    init(url: URL, duration: TimeInterval) {
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.duration = duration
    }
}

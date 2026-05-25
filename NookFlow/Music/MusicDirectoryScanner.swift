import Foundation
import UniformTypeIdentifiers

// 扫描目录第一层的音频文件；不递归、不读取 metadata，避免把轻量播放列表做成资料库。
struct MusicDirectoryScanner {
    private let supportedExtensions: Set<String> = [
        "mp3",
        "m4a",
        "wav",
        "aiff",
        "caf"
    ]
    private let fileManager: FileManager
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    func audioFiles(in directoryURL: URL) -> [URL] {
        let didStartAccess = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }
        let urls = (try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { isAudioFile($0) }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }
    func isAudioFile(_ url: URL) -> Bool {
        guard isRegularFile(url) else { return false }
        let fileExtension = url.pathExtension.lowercased()
        if supportedExtensions.contains(fileExtension) {
            return true
        }
        // 扩展名不在白名单时，用系统 UTType 兜底识别其他音频格式。
        guard let type = UTType(filenameExtension: fileExtension) else { return false }
        return type.conforms(to: .audio)
    }
    private func isRegularFile(_ url: URL) -> Bool {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey]) else { return false }
        return values.isRegularFile == true
    }
}

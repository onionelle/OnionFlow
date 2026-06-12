import Foundation
import UniformTypeIdentifiers

// 扫描目录第一层的音频文件；不递归、不读取 metadata，避免把轻量播放列表做成资料库。
struct MusicDirectoryScanner {
    private let supportedExtensions: Set<String> = [
        "mp3",
        "m4a",
        "wav",
        "aiff",
        "caf",
        "flac"
    ]
    private let fileManager: FileManager
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func canImportToPlaylist(_ url: URL) -> Bool {
        // 在 macOS 沙盒下，拖放悬停阶段（Hover）系统尚未授予对外部 URL 的访问权限，
        // 此时直接调用 fileManager.fileExists 检查外部路径将始终返回 false 导致悬停热区无法亮起。
        // 因此，这里仅根据路径后缀进行快速内存判定：
        // 1. 如果后缀为空，我们假定它是一个待导入的文件夹/目录。
        // 2. 如果后缀不为空，通过后缀或 UTType 判定其是否为音频文件。
        let fileExtension = url.pathExtension.lowercased()
        if fileExtension.isEmpty {
            return true
        }
        return isAudioFile(url)
    }

    func audioFilesToImport(from url: URL) -> [URL] {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }
        return isDirectory.boolValue ? audioFiles(in: url) : (isAudioFile(url) ? [url] : [])
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
            .filter { isAudioFile($0) && isRegularFile($0) }
            .sorted { lhs, rhs in
                lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
    }
    func isAudioFile(_ url: URL) -> Bool {
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

import AppKit
import UniformTypeIdentifiers

// 只负责系统文件选择面板；播放列表处理和播放控制在 ViewModel / Controller。
@MainActor
final class MusicFilePicker {
    private let allowedContentTypes: [UTType] = [
        "mp3",
        "m4a",
        "wav",
        "aiff",
        "caf"
    ]
    .compactMap { UTType(filenameExtension: $0) }
    + [.audio]

    func pickAudioFilesAndDirectories() async -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedContentTypes
        panel.title = "Add Music Files or Folders"
        panel.prompt = "Add"
        // accessory app 没有普通前台窗口，显示 NSOpenPanel 前先激活应用。
        NSApp.activate()
        // NSOpenPanel 可能在显示时重设层级；在 begin 异步渲染循环开始时补一次置顶。
        panel.level = .screenSaver
        DispatchQueue.main.async {
            panel.level = .screenSaver
            panel.orderFrontRegardless()
        }
        return await withCheckedContinuation { continuation in
            panel.begin { response in
                if response == .OK {
                    continuation.resume(returning: panel.urls)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

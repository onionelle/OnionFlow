import Foundation
import CoreServices
import UniformTypeIdentifiers

// 负责底层音频文件夹的 FSEvents 递归监听与异步扫描，过滤非音频与临时文件，防止阻塞主线程。
final class MusicFolderMonitor {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "onion.folder-monitor", qos: .utility)
    
    // 当监听到目录有音频文件新增时，回调新增的文件URL列表
    var onAudioFilesAdded: (([URL]) -> Void)?
    
    private let supportedExtensions: Set<String> = ["mp3", "m4a", "wav", "aiff", "caf", "flac"]
    private var currentPath: String?

    func start(path: String) {
        // 自动将 ~ 解析为绝对路径
        let absolutePath = NSString(string: path).expandingTildeInPath
        if absolutePath == currentPath && stream != nil { return }
        
        stop()
        currentPath = absolutePath
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDir), isDir.boolValue else {
            return
        }
        
        let pathsToWatch = [absolutePath] as CFArray
        
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let monitor = Unmanaged<MusicFolderMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            
            // FSEvents 扫描过滤逻辑
            monitor.processEvents(paths: paths, flags: eventFlags, count: numEvents)
        }
        
        // 监听文件级事件
        let flags = UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // 降低频率，延迟1秒合并回调，降低电量消耗
            FSEventStreamCreateFlags(flags)
        )
        
        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            
            // 首次全量扫描
            queue.async {
                self.performFullScan(at: absolutePath)
            }
        }
    }
    
    func stop() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            self.currentPath = nil
        }
    }
    
    private func processEvents(paths: [String], flags: UnsafePointer<FSEventStreamEventFlags>, count: Int) {
        var newAudioUrls: [URL] = []
        
        for i in 0..<count {
            let path = paths[i]
            let flag = flags[i]
            
            // 过滤出文件的新增/修改事件 (kFSEventStreamEventFlagItemCreated 或 kFSEventStreamEventFlagItemRenamed 等)
            let isFile = (flag & UInt32(kFSEventStreamEventFlagItemIsFile)) != 0
            if isFile {
                let url = URL(fileURLWithPath: path)
                if isValidAudioFile(url) {
                    newAudioUrls.append(url)
                }
            } else {
                // 如果是目录变更，递归扫描该目录
                let url = URL(fileURLWithPath: path)
                let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                while let fileUrl = enumerator?.nextObject() as? URL {
                    if isValidAudioFile(fileUrl) {
                        newAudioUrls.append(fileUrl)
                    }
                }
            }
        }
        
        if !newAudioUrls.isEmpty {
            DispatchQueue.main.async {
                self.onAudioFilesAdded?(newAudioUrls)
            }
        }
    }
    
    private func performFullScan(at path: String) {
        let url = URL(fileURLWithPath: path)
        var newAudioUrls: [URL] = []
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        while let fileUrl = enumerator?.nextObject() as? URL {
            if isValidAudioFile(fileUrl) {
                newAudioUrls.append(fileUrl)
            }
        }
        if !newAudioUrls.isEmpty {
            DispatchQueue.main.async {
                self.onAudioFilesAdded?(newAudioUrls)
            }
        }
    }
    
    private func isValidAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        // 严格过滤临时文件
        if ext == "crdownload" || ext == "download" || ext == "tmp" || ext == "part" {
            return false
        }
        
        var isSupportedAudio = supportedExtensions.contains(ext)
        if !isSupportedAudio {
            if let type = UTType(filenameExtension: ext), type.conforms(to: .audio) {
                isSupportedAudio = true
            }
        }
        
        // 检查是否为支持的格式，并且文件确实存在
        if isSupportedAudio {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                return true
            }
        }
        return false
    }
}

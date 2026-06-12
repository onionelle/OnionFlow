import Foundation
import Combine

@MainActor
final class OnlineDownloadManager: ObservableObject {
    static let shared = OnlineDownloadManager()
    
    @Published var downloadingSongIDs: Set<Int> = []
    @Published var downloadProgresses: [Int: Double] = [:]
    @Published var downloadedBaseFilenames: Set<String> = []
    @Published var downloadErrors: [Int: String] = [:]
    
    private var observations: [Int: NSKeyValueObservation] = [:]
    
    private init() {
        refreshDownloadedFiles()
    }
    
    func refreshDownloadedFiles() {
        let autoListenPathStr = UserDefaults.standard.string(forKey: "autoListenPath") ?? "~/Music"
        let expandedPath = NSString(string: autoListenPathStr).expandingTildeInPath
        let neteaseDir = URL(fileURLWithPath: expandedPath).appendingPathComponent("OnionFlow Downloads").appendingPathComponent("Netease")
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: neteaseDir.path) else { return }
        
        var baseNames = Set<String>()
        for file in files {
            let baseName = (file as NSString).deletingPathExtension
            baseNames.insert(baseName)
        }
        
        Task { @MainActor in
            self.downloadedBaseFilenames = baseNames
        }
    }
    
    func isDownloaded(song: NeteaseSong) -> Bool {
        let safeArtist = song.artistName.replacingOccurrences(of: "/", with: "&").replacingOccurrences(of: ":", with: "-")
        let safeTitle = song.name.replacingOccurrences(of: "/", with: "&").replacingOccurrences(of: ":", with: "-")
        let baseFilename = "\(safeTitle) - \(safeArtist)"
        return downloadedBaseFilenames.contains(baseFilename)
    }
    
    func download(song: NeteaseSong) async throws {
        // Prevent duplicate downloads
        guard !downloadingSongIDs.contains(song.id) else { return }
        downloadingSongIDs.insert(song.id)
        downloadProgresses[song.id] = 0.0
        downloadErrors.removeValue(forKey: song.id)
        
        defer {
            downloadingSongIDs.remove(song.id)
            downloadProgresses.removeValue(forKey: song.id)
            observations.removeValue(forKey: song.id)
        }
        
        // Fetch direct URL
        let response = try await NeteaseAPIClient.shared.fetchSongURL(id: "\(song.id)")
        guard let urlString = response.data?.first?.url, let url = URL(string: urlString.replacingOccurrences(of: "http://", with: "https://")) else {
            throw NSError(domain: "OnlineDownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无下载链接或需 VIP"])
        }
        
        // Find path
        let autoListenPathStr = UserDefaults.standard.string(forKey: "autoListenPath") ?? "~/Music"
        let expandedPath = NSString(string: autoListenPathStr).expandingTildeInPath
        let autoListenDir = URL(fileURLWithPath: expandedPath).appendingPathComponent("OnionFlow Downloads").appendingPathComponent("Netease")
        
        if !FileManager.default.fileExists(atPath: autoListenDir.path) {
            try FileManager.default.createDirectory(at: autoListenDir, withIntermediateDirectories: true)
        }
        
        // File extension
        let fileExtension = url.pathExtension.isEmpty ? "mp3" : url.pathExtension
        let safeArtist = song.artistName.replacingOccurrences(of: "/", with: "&").replacingOccurrences(of: ":", with: "-")
        let safeTitle = song.name.replacingOccurrences(of: "/", with: "&").replacingOccurrences(of: ":", with: "-")
        
        let filename = "\(safeTitle) - \(safeArtist).\(fileExtension)"
        let destinationURL = autoListenDir.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            // Already downloaded
            return
        }
        
        // Start download using URLSessionTask and KVO
        let (persistentTempURL, urlResponse): (URL, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                let persistent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                do {
                    if FileManager.default.fileExists(atPath: persistent.path) {
                        try FileManager.default.removeItem(at: persistent)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: persistent)
                    continuation.resume(returning: (persistent, response))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            let observation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    self?.downloadProgresses[song.id] = fraction
                }
            }
            self.observations[song.id] = observation
            task.resume()
        }
        
        defer {
            try? FileManager.default.removeItem(at: persistentTempURL)
        }
        
        guard let httpResponse = urlResponse as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "OnlineDownloadManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "下载失败"])
        }
        
        try FileManager.default.moveItem(at: persistentTempURL, to: destinationURL)
        refreshDownloadedFiles()
        
        // (Optional) We could theoretically write ID3 tags here, but we will rely on filename parsing for now.
    }
}

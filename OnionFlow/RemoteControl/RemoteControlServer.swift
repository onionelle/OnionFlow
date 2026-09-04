import Darwin
import Combine
import Foundation
import IOKit.pwr_mgt
import Network

@MainActor
final class RemoteControlServer: ObservableObject {
    @Published private(set) var localURL = "http://localhost:17777"

    private let port: NWEndpoint.Port = 17777
    private weak var musicViewModel: MusicPlayerViewModel?
    private var listener: NWListener?
    private let listenerQueue = DispatchQueue(label: "onion.remote-control.listener")
    private var discoveryTrackCache: [String: [RemoteDiscoveryTrack]] = [:]

    init(musicViewModel: MusicPlayerViewModel) {
        self.musicViewModel = musicViewModel
        if UserDefaults.standard.bool(forKey: "remoteControlEnabled") {
            refreshLocalURL()
        } else {
            localURL = "未开启网页遥控"
        }
        Task {
            await DownloadManager.shared.setOnDownloadCompleted { url in
                Task { @MainActor in
                    musicViewModel.addFilesOrDirectoriesToPlaylist(from: [url])
                }
            }
        }
    }

    var isRunning: Bool { listener != nil }

    func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            let listener = try NWListener(using: parameters, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handle(connection)
                }
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    DiagnosticLogService.shared.log("remote.listener.failed", [
                        "error": error.localizedDescription
                    ])
                }
            }
            listener.start(queue: listenerQueue)
            self.listener = listener
            refreshLocalURL()
        } catch {
            localURL = "遥控器启动失败"
            DiagnosticLogService.shared.log("remote.start.failed", [
                "error": error.localizedDescription
            ])
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        localURL = "未开启网页遥控"
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: listenerQueue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            Task { @MainActor in
                self?.respond(to: data, connection: connection)
            }
        }
    }

    private func respond(to data: Data?, connection: NWConnection) {
        guard let data, let request = String(data: data, encoding: .utf8) else {
            send(status: "400 Bad Request", body: "Bad Request", contentType: "text/plain; charset=utf-8", on: connection)
            return
        }

        let firstLine = request.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else {
            send(status: "400 Bad Request", body: "Bad Request", contentType: "text/plain; charset=utf-8", on: connection)
            return
        }

        let method = parts[0]
        let target = parts[1]
        let components = URLComponents(string: "http://onion.local\(target)")
        let path = components?.path ?? "/"
        let queryItems = components?.queryItems ?? []
        
        let reqComponents = request.components(separatedBy: "\r\n\r\n")
        let bodyString = reqComponents.count > 1 ? reqComponents[1] : ""

        switch (method, path) {
        case ("GET", "/"):
            send(status: "200 OK", body: htmlPage, contentType: "text/html; charset=utf-8", on: connection)
        case ("GET", "/api/state"):
            sendJSON(statePayload(), on: connection)
        case (_, "/api/play-pause"):
            musicViewModel?.togglePlayPause()
            sendJSON(statePayload(), on: connection)
        case (_, "/api/playback-mode/toggle"):
            musicViewModel?.togglePlaybackMode()
            sendJSON(statePayload(), on: connection)
        case (_, "/api/previous"):
            musicViewModel?.playPreviousTrack()
            sendJSON(statePayload(), on: connection)
        case (_, "/api/next"):
            musicViewModel?.playNextTrack()
            sendJSON(statePayload(), on: connection)
        case (_, "/api/volume"):
            if let rawValue = queryItems.first(where: { $0.name == "value" })?.value,
               let value = Double(rawValue) {
                musicViewModel?.volume = min(max(value, 0), 1)
            }
            sendJSON(statePayload(), on: connection)
        case ("GET", "/api/audio-output"):
            sendJSON(audioOutputPayload(), on: connection)
        case (_, "/api/audio-output"):
            let uid = queryItems.first(where: { $0.name == "uid" })?.value ?? ""
            UserDefaults.standard.set(uid, forKey: "preferredAudioOutputDeviceUID")
            let didSelect = uid.isEmpty || AudioOutputDeviceService.selectOutputDevice(uid: uid)
            sendJSON(audioOutputPayload(message: didSelect ? "输出设备已更新" : "设备暂未出现在系统输出列表中"), on: connection)

        case ("GET", "/api/bluetooth"):
            sendJSON(bluetoothPayload(), on: connection)
        case (_, "/api/bluetooth/connect"):
            let address = queryItems.first(where: { $0.name == "address" })?.value ?? ""
            let success = AudioOutputDeviceService.connectBluetoothDevice(address: address)
            sendJSON(["ok": success, "message": success ? "正在尝试连接蓝牙设备..." : "蓝牙连接请求失败"], on: connection)
        case (_, "/api/bluetooth/disconnect"):
            let address = queryItems.first(where: { $0.name == "address" })?.value ?? ""
            let success = AudioOutputDeviceService.disconnectBluetoothDevice(address: address)
            sendJSON(["ok": success, "message": success ? "已发起蓝牙断开请求..." : "蓝牙断开请求失败"], on: connection)
        case (_, "/api/play"):
            if let rawIndex = queryItems.first(where: { $0.name == "index" })?.value,
               let index = Int(rawIndex),
               let viewModel = musicViewModel {
                let type = queryItems.first(where: { $0.name == "type" })?.value
                let isOnline = type == "online" || (type == nil && viewModel.playlistMode == .online)
                
                if isOnline {
                    if index >= 0 && index < viewModel.activeOnlinePlaylist.count {
                        viewModel.playOnlineSong(at: index)
                    }
                } else {
                    if index >= 0 && index < viewModel.playlist.count {
                        viewModel.playTrack(at: index)
                    }
                }
            }
            sendJSON(statePayload(), on: connection)
        case (_, "/api/remove"):
            if let rawIndex = queryItems.first(where: { $0.name == "index" })?.value,
               let index = Int(rawIndex),
               let viewModel = musicViewModel {
                let isOnlineStr = queryItems.first(where: { $0.name == "online" })?.value
                let isOnline = isOnlineStr == "true" || (isOnlineStr == nil && viewModel.playlistMode == .online)
                
                if isOnline {
                    if index >= 0 && index < viewModel.activeOnlinePlaylist.count {
                        viewModel.removeOnlineTrack(at: index)
                    }
                } else {
                    if index >= 0 && index < viewModel.playlist.count {
                        let shouldTrash = queryItems.first(where: { $0.name == "trash" })?.value == "true"
                        if shouldTrash {
                            let url = viewModel.playlist[index]
                            if url.isFileURL {
                                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                            }
                        }
                        viewModel.removeTrack(at: index)
                    }
                }
            }
            sendJSON(statePayload(), on: connection)
        case (_, "/api/sleep"):
            if musicViewModel?.state == .playing {
                musicViewModel?.togglePlayPause()
            }
            sendJSON(["ok": true, "message": "Mac 即将进入睡眠"], on: connection)
            sleepMac()
            
        case ("GET", "/api/search"):
            let query = queryItems.first(where: { $0.name == "q" })?.value ?? ""
            Task {
                do {
                    let results = try await NeteaseAPI.shared.search(query: query)
                    let items = results.map { [
                        "id": $0.id,
                        "title": $0.title,
                        "uploader": $0.uploader,
                        "duration": $0.duration,
                        "url": $0.url
                    ] }
                    
                    if let viewModel = self.musicViewModel {
                        let songs = results.map { res in
                            NeteaseSong(
                                id: Int(res.id) ?? 0,
                                name: res.title,
                                ar: [NeteaseArtist(id: 0, name: res.uploader)],
                                al: nil,
                                dt: Int(res.duration * 1000)
                            )
                        }
                        Task { @MainActor in
                            viewModel.selectedChartId = "search"
                            viewModel.onlinePlaylist = songs
                        }
                    }
                    
                    self.sendJSON(["results": items], on: connection)
                } catch {
                    self.sendJSON(["error": "Search failed"], on: connection)
                }
            }
            return
            
        case ("GET", "/api/discovery/playlist"):
            let id = queryItems.first(where: { $0.name == "id" })?.value ?? ""
            let forceRefresh = queryItems.first(where: { $0.name == "refresh" })?.value == "true"
            if forceRefresh, let viewModel = self.musicViewModel {
                Task { @MainActor in
                    viewModel.resetOnlineFailureState()
                }
            }
            let cacheKey = "playlist:\(id)"
            if !forceRefresh, let cachedItems = discoveryTrackCache[cacheKey] {
                if let viewModel = self.musicViewModel {
                    let songs = cachedItems.map { item in
                        NeteaseSong(
                            id: Int(item.id) ?? 0,
                            name: item.title,
                            ar: [NeteaseArtist(id: 0, name: item.uploader)],
                            al: nil,
                            dt: Int(item.duration * 1000)
                        )
                    }
                    Task { @MainActor in
                        viewModel.selectedChartId = id
                        viewModel.onlinePlaylist = songs
                    }
                }
                sendJSON(["results": cachedItems.map(\.payload)], on: connection)
                return
            }
            
            Task {
                do {
                    let response = try await NeteaseAPIClient.shared.fetchPlaylistDetail(id: id)
                    guard let tracks = response.playlist?.tracks else {
                        self.sendJSON(["error": "歌单数据为空"], on: connection)
                        return
                    }
                    let items = tracks.map { RemoteDiscoveryTrack(song: $0) }
                    self.discoveryTrackCache[cacheKey] = items
                    
                    if let viewModel = self.musicViewModel {
                        Task { @MainActor in
                            viewModel.selectedChartId = id
                            viewModel.onlinePlaylist = tracks
                        }
                    }
                    
                    self.sendJSON(["results": items.map(\.payload)], on: connection)
                } catch {
                    if let cachedItems = self.discoveryTrackCache[cacheKey] {
                        if let viewModel = self.musicViewModel {
                            let songs = cachedItems.map { item in
                                NeteaseSong(
                                    id: Int(item.id) ?? 0,
                                    name: item.title,
                                    ar: [NeteaseArtist(id: 0, name: item.uploader)],
                                    al: nil,
                                    dt: Int(item.duration * 1000)
                                )
                            }
                            Task { @MainActor in
                                viewModel.selectedChartId = id
                                viewModel.onlinePlaylist = songs
                            }
                        }
                        self.sendJSON(["results": cachedItems.map(\.payload), "cached": true], on: connection)
                    } else {
                        self.sendJSON(["error": "加载失败: \(error.localizedDescription)"], on: connection)
                    }
                }
            }
            return
            
        case ("GET", "/api/discovery/simi"):
            Task {
                let activeSongId: Int? = await MainActor.run {
                    guard let musicViewModel = self.musicViewModel,
                          musicViewModel.playlistMode == .online,
                          let activeIndex = musicViewModel.currentOnlineIndex,
                          musicViewModel.activeOnlinePlaylist.indices.contains(activeIndex) else {
                        return nil
                    }
                    return musicViewModel.activeOnlinePlaylist[activeIndex].id
                }
                
                guard let songId = activeSongId else {
                    self.sendJSON(["error": "请先在 Mac 客户端播放一首在线发现列表 of 歌曲，以获取相似推荐。"], on: connection)
                    return
                }
                let forceRefresh = queryItems.first(where: { $0.name == "refresh" })?.value == "true"
                if forceRefresh, let viewModel = self.musicViewModel {
                    Task { @MainActor in
                        viewModel.resetOnlineFailureState()
                    }
                }
                let cacheKey = "simi:\(songId)"
                if !forceRefresh, let cachedItems = self.discoveryTrackCache[cacheKey] {
                    if let viewModel = self.musicViewModel {
                        let songs = cachedItems.map { item in
                            NeteaseSong(
                                id: Int(item.id) ?? 0,
                                name: item.title,
                                ar: [NeteaseArtist(id: 0, name: item.uploader)],
                                al: nil,
                                dt: Int(item.duration * 1000)
                            )
                        }
                        Task { @MainActor in
                            viewModel.selectedChartId = "simi"
                            viewModel.onlinePlaylist = songs
                        }
                    }
                    self.sendJSON(["results": cachedItems.map(\.payload)], on: connection)
                    return
                }
                
                do {
                    let simiRes = try await NeteaseAPIClient.shared.fetchSimiSongs(songId: String(songId))
                    guard let simiSongs = simiRes.songs else {
                        self.sendJSON(["error": "未获取到相似歌曲"], on: connection)
                        return
                    }
                    let tracks = simiSongs.map { $0.toNeteaseSong() }
                    let items = tracks.map { RemoteDiscoveryTrack(song: $0) }
                    self.discoveryTrackCache[cacheKey] = items
                    
                    if let viewModel = self.musicViewModel {
                        Task { @MainActor in
                            viewModel.selectedChartId = "simi"
                            viewModel.onlinePlaylist = tracks
                        }
                    }
                    
                    self.sendJSON(["results": items.map(\.payload)], on: connection)
                } catch {
                    if let cachedItems = self.discoveryTrackCache[cacheKey] {
                        if let viewModel = self.musicViewModel {
                            let songs = cachedItems.map { item in
                                NeteaseSong(
                                    id: Int(item.id) ?? 0,
                                    name: item.title,
                                    ar: [NeteaseArtist(id: 0, name: item.uploader)],
                                    al: nil,
                                    dt: Int(item.duration * 1000)
                                )
                            }
                            Task { @MainActor in
                                viewModel.selectedChartId = "simi"
                                viewModel.onlinePlaylist = songs
                            }
                        }
                        self.sendJSON(["results": cachedItems.map(\.payload), "cached": true], on: connection)
                    } else {
                        self.sendJSON(["error": "获取相似歌曲失败: \(error.localizedDescription)"], on: connection)
                    }
                }
            }
            return
            
        case (_, "/api/play-online"):
            let idStr = queryItems.first(where: { $0.name == "id" })?.value ?? ""
            let name = queryItems.first(where: { $0.name == "name" })?.value ?? ""
            let artist = queryItems.first(where: { $0.name == "artist" })?.value ?? ""
            let durationStr = queryItems.first(where: { $0.name == "duration" })?.value ?? ""
            let indexStr = queryItems.first(where: { $0.name == "index" })?.value ?? ""
            
            if let id = Int(idStr), let viewModel = musicViewModel {
                let duration = Double(durationStr)
                let song = NeteaseSong(
                    id: id,
                    name: name,
                    ar: [NeteaseArtist(id: 0, name: artist)],
                    al: nil,
                    dt: duration != nil ? Int(duration! * 1000) : nil
                )
                if let index = Int(indexStr), viewModel.onlinePlaylist.indices.contains(index), viewModel.onlinePlaylist[index].id == id {
                    viewModel.playOnlineSong(at: index)
                } else {
                    viewModel.playOnlineSongDirectly(song)
                }
            }
            sendJSON(statePayload(), on: connection)
            return
            
        case (_, "/api/download"):
            let url = queryItems.first(where: { $0.name == "url" })?.value ?? ""
            let title = queryItems.first(where: { $0.name == "title" })?.value ?? "Unknown"
            Task {
                if url.hasPrefix("netease:") {
                    let id = String(url.dropFirst("netease:".count))
                    await DownloadManager.shared.downloadNetease(id: id, title: title)
                } else {
                    await DownloadManager.shared.download(url: url)
                }
                self.sendJSON(["status": "started"], on: connection)
            }
            return
            
        case ("GET", "/api/download-status"):
            Task {
                let status = await DownloadManager.shared.getStatus()
                self.sendJSON(status, on: connection)
            }
            return
            
        case ("GET", "/api/settings/cookie"):
            let currentCookie = NeteaseAPI.shared.cookieStr
            self.sendJSON(["cookie": currentCookie], on: connection)
            return
            
        case ("POST", "/api/settings/cookie"):
            var newCookie = bodyString
            if newCookie.isEmpty {
                newCookie = queryItems.first(where: { $0.name == "cookie" })?.value ?? ""
            }
            if !newCookie.isEmpty {
                NeteaseAPI.shared.cookieStr = newCookie
                self.sendJSON(["status": "saved"], on: connection)
            } else {
                self.sendJSON(["error": "Empty cookie"], on: connection)
            }
            return
            
        default:
            send(status: "404 Not Found", body: "Not Found", contentType: "text/plain; charset=utf-8", on: connection)
        }
    }

    private func sendJSON(_ payload: [String: Any], on connection: NWConnection) {
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data("{}".utf8)
        send(status: "200 OK", data: data, contentType: "application/json; charset=utf-8", on: connection)
    }

    private func send(status: String, body: String, contentType: String, on connection: NWConnection) {
        send(status: status, data: Data(body.utf8), contentType: contentType, on: connection)
    }

    private func send(status: String, data: Data, contentType: String, on connection: NWConnection) {
        var headers = "HTTP/1.1 \(status)\r\n"
        headers += "Content-Type: \(contentType)\r\n"
        headers += "Content-Length: \(data.count)\r\n"
        headers += "Cache-Control: no-store\r\n"
        headers += "Access-Control-Allow-Origin: *\r\n"
        headers += "Connection: close\r\n\r\n"

        var response = Data(headers.utf8)
        response.append(data)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func statePayload() -> [String: Any] {
        guard let musicViewModel else {
            return [
                "state": "idle",
                "playlistMode": "local",
                "localPlaylist": [],
                "onlinePlaylist": [],
                "playlist": [],
                "lyrics": ["state": "idle", "lines": []]
            ]
        }

        musicViewModel.showLyrics()
        let localPlaylist = musicViewModel.playlist.enumerated().map { index, url in
            [
                "index": index,
                "title": url.deletingPathExtension().lastPathComponent,
                "isCurrent": index == musicViewModel.currentIndex && musicViewModel.playlistMode == .local,
                "isOnline": false,
                "isFailed": musicViewModel.failedLocalURLs.contains(url)
            ]
        }
        let onlinePlaylist = musicViewModel.activeOnlinePlaylist.enumerated().map { index, song in
            [
                "index": index,
                "title": "\(song.name) - \(song.artistName)",
                "isCurrent": index == musicViewModel.currentOnlineIndex && musicViewModel.playlistMode == .online,
                "isOnline": true
            ]
        }

        var currentOnlineSongId: Int? = nil
        if musicViewModel.playlistMode == .online,
           let index = musicViewModel.currentOnlineIndex,
           musicViewModel.activeOnlinePlaylist.indices.contains(index) {
            currentOnlineSongId = musicViewModel.activeOnlinePlaylist[index].id
        }

        return [
            "state": String(describing: musicViewModel.state),
            "isPlaying": musicViewModel.state == .playing,
            "title": musicViewModel.titleText,
            "artist": musicViewModel.currentTrack?.artist ?? "",
            "currentTime": musicViewModel.currentTime,
            "duration": musicViewModel.duration,
            "currentTimeText": musicViewModel.currentTimeText,
            "durationText": musicViewModel.durationText,
            "volume": musicViewModel.volume,
            "playbackMode": musicViewModel.playbackModeText,
            "playlistMode": musicViewModel.playlistMode == .online ? "online" : "local",
            "currentOnlineSongId": currentOnlineSongId ?? 0,
            "failedOnlineSongIDs": Array(musicViewModel.failedOnlineSongIDs),
            "onlineSongFailureMessages": musicViewModel.onlineSongFailureMessages.reduce(into: [String: String]()) { dict, pair in
                dict[String(pair.key)] = pair.value
            },
            "localPlaylist": localPlaylist,
            "onlinePlaylist": onlinePlaylist,
            "playlist": musicViewModel.playlistMode == .online ? onlinePlaylist : localPlaylist,
            "lyrics": lyricsPayload(from: musicViewModel.lyricsViewModel)
        ]
    }

    private func audioOutputPayload(message: String = "") -> [String: Any] {
        let preferredUID = UserDefaults.standard.string(forKey: "preferredAudioOutputDeviceUID") ?? ""
        let devices = AudioOutputDeviceService.outputDevices()

        return [
            "preferredUID": preferredUID,
            "message": message,
            "devices": devices.map { ["id": $0.id, "name": $0.name] }
        ]
    }

    private func bluetoothPayload() -> [String: Any] {
        let devices = AudioOutputDeviceService.pairedBluetoothAudioDevices()
        let items = devices.map { [
            "address": $0.address,
            "name": $0.name,
            "isConnected": $0.isConnected
        ] }
        return ["devices": items]
    }

    private func lyricsPayload(from lyricsViewModel: LyricsViewModel) -> [String: Any] {
        let currentIndex = lyricsViewModel.currentLineIndex
        let lines: [[String: Any]]
        if let currentIndex {
            let lowerBound = max(lyricsViewModel.lyricLines.startIndex, currentIndex - 6)
            let upperBound = min(lyricsViewModel.lyricLines.endIndex, currentIndex + 7)
            lines = lyricsViewModel.lyricLines[lowerBound..<upperBound].enumerated().map { offset, line in
                let absoluteIndex = lowerBound + offset
                return [
                    "index": absoluteIndex,
                    "text": line.text.isEmpty ? "..." : line.text,
                    "isCurrent": absoluteIndex == currentIndex
                ]
            }
        } else {
            lines = lyricsViewModel.lyricLines.prefix(13).enumerated().map { index, line in
                [
                    "index": index,
                    "text": line.text.isEmpty ? "..." : line.text,
                    "isCurrent": false
                ]
            }
        }

        let stateText: String
        switch lyricsViewModel.state {
        case .idle:
            stateText = "idle"
        case .loading:
            stateText = "loading"
        case .onlineDisabled:
            stateText = "onlineDisabled"
        case .candidates:
            stateText = "candidates"
        case .success:
            stateText = "success"
        case .failed:
            stateText = "failed"
        case .noLyrics:
            stateText = "noLyrics"
        }

        return [
            "state": stateText,
            "currentIndex": currentIndex ?? NSNull(),
            "lines": lines
        ]
    }

    private func refreshLocalURL() {
        localURL = "http://\(Self.localIPv4Address() ?? "localhost"):\(port.rawValue)"
    }

    private func sleepMac() {
        // 先返回 HTTP 响应，再轻微延迟触发 system 睡眠，避免浏览器收到半截响应。
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["sleepnow"]
            try? process.run()
        }
    }

    private static func localIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        for pointer in sequence(first: firstInterface, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, !isLoopback, interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            var address = interface.ifa_addr.pointee
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                &address,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }

    private var htmlPage: String {
        """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
          <title>Onion Remote</title>
          <style>
            :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif; --accent: #55f0a8; --bg: #050506; --panel: rgba(18,18,22,0.86); --panel-strong: rgba(10,10,12,0.92); --stroke: rgba(255,255,255,0.08); --muted: rgba(255,255,255,0.48); --text: rgba(255,255,255,0.88); }
            * { box-sizing: border-box; }
            body { margin: 0; height: 100vh; height: 100dvh; overflow: hidden; background: radial-gradient(circle at 50% -18%, rgba(85,240,168,0.12), transparent 24%), linear-gradient(180deg, #111217 0%, var(--bg) 58%); color: #f7f7f7; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; padding-top: max(env(safe-area-inset-top), 18px); padding-bottom: max(env(safe-area-inset-bottom), 18px); }
            button, input, select, textarea { font: inherit; }
            main { width: min(430px, calc(100vw - 24px)); display: flex; flex-direction: column; gap: 12px; flex: 1; min-height: 0; }
            h1 { font-size: 16px; margin: 0; font-weight: 600; letter-spacing: 0; color: var(--text); }
            header { display: flex; justify-content: space-between; align-items: center; padding: 0 2px; min-height: 34px; }
            .brand { display: flex; align-items: center; gap: 9px; min-width: 0; }
            .brand-mark { width: 17px; height: 17px; border-radius: 5px; background: linear-gradient(145deg, rgba(85,240,168,0.9), rgba(55,188,126,0.72)); box-shadow: 0 0 14px rgba(85,240,168,0.28); display: grid; place-items: center; flex-shrink: 0; }
            .brand-mark::after { content: ""; width: 7px; height: 7px; border-radius: 2px; background: #06120b; opacity: 0.88; }
            .header-actions { display: flex; gap: 7px; align-items: center; }
            .card { background: var(--panel); backdrop-filter: blur(22px); -webkit-backdrop-filter: blur(22px); border: 1px solid var(--stroke); border-radius: 18px; box-shadow: 0 14px 38px rgba(0,0,0,0.32); }
            .hero { text-align: center; padding: 18px 18px 16px; }
            .title { font-size: 18px; font-weight: 600; line-height: 1.28; margin-bottom: 4px; color: rgba(255,255,255,0.92); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .status { color: var(--muted); font-size: 12px; margin-bottom: 18px; min-height: 16px; }
            .controls { display: grid; grid-template-columns: 44px 44px 62px 44px 44px; justify-content: center; align-items: center; gap: 8px; margin-bottom: 18px; width: 100%; }

            .icon-btn { width: 38px; height: 38px; border: 1px solid transparent; background: transparent; color: rgba(255,255,255,0.78); font-size: 20px; cursor: pointer; display: grid; place-items: center; border-radius: 50%; transition: background 0.16s, color 0.16s, border-color 0.16s, transform 0.12s; padding: 0; }
            .icon-btn:active { background: rgba(255,255,255,0.1); transform: scale(0.96); }
            .mode-btn { width: 44px !important; height: 28px !important; border-radius: 8px !important; background: rgba(255,255,255,0.07) !important; color: rgba(255,255,255,0.66) !important; font-size: 11px !important; font-weight: 600 !important; }
            .play-btn { width: 58px; height: 58px; border: none; background: var(--accent); color: #020403; cursor: pointer; display: grid; place-items: center; border-radius: 50%; box-shadow: 0 10px 28px rgba(85,240,168,0.24); transition: transform 0.1s, filter 0.16s; padding-left: 3px; }
            .play-btn.paused { padding-left: 0; }
            .play-btn:active { transform: scale(0.95); }
            .volume { display: grid; grid-template-columns: 20px 1fr 36px; gap: 10px; align-items: center; color: var(--muted); font-size: 12px; padding: 0 4px; }
            .volume-icon { color: rgba(255,255,255,0.48); display: grid; place-items: center; }
            input[type=range] { -webkit-appearance: none; width: 100%; height: 4px; background: rgba(255,255,255,0.12); border-radius: 99px; outline: none; }
            input[type=range]::-webkit-slider-thumb { -webkit-appearance: none; width: 15px; height: 15px; border-radius: 50%; background: var(--accent); cursor: pointer; box-shadow: 0 0 0 4px rgba(85,240,168,0.1), 0 2px 8px rgba(0,0,0,0.45); border: 1px solid rgba(255,255,255,0.35); }
            input:focus, select:focus, textarea:focus { border-color: rgba(85,240,168,0.36) !important; box-shadow: 0 0 0 3px rgba(85,240,168,0.08); }

            .header-btn { width: 34px; height: 34px; border: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.05); color: rgba(255,255,255,0.72); border-radius: 50%; cursor: pointer; display: grid; place-items: center; transition: all 0.2s ease; outline: none; backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); padding: 0; }
            .header-btn:hover { background: rgba(255,255,255,0.12); color: #fff; border-color: rgba(255,255,255,0.15); }
            .header-btn:active { transform: scale(0.95); background: rgba(255,255,255,0.08); }

            .modal-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.4); backdrop-filter: blur(0px); -webkit-backdrop-filter: blur(0px); display: grid; place-items: center; z-index: 10000; opacity: 0; pointer-events: none; transition: all 0.3s ease; }
            .modal-overlay.active { opacity: 1; pointer-events: auto; backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); }
            .modal-content { width: min(390px, calc(100vw - 28px)); max-height: 90vh; overflow-y: auto; transform: scale(0.9) translateY(20px); transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1); background: rgba(13,13,16,0.94); border: 1px solid rgba(255,255,255,0.1); box-shadow: 0 20px 50px rgba(0,0,0,0.5); padding: 18px; border-radius: 18px; }
            .modal-overlay.active .modal-content { transform: scale(1) translateY(0); }
            .modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
            .modal-header h2 { margin: 0; font-size: 15px; font-weight: 600; color: var(--text); }
            .modal-close { background: transparent; border: none; color: rgba(255,255,255,0.4); font-size: 20px; cursor: pointer; transition: color 0.2s; padding: 0; width: 32px; height: 32px; display: grid; place-items: center; border-radius: 50%; }
            .modal-close:hover { color: #fff; background: rgba(255,255,255,0.08); }

            .settings { border-radius: 20px; }
            .setting-row { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid rgba(255,255,255,0.06); gap: 12px; }
            .setting-row:last-child { border-bottom: none; padding-bottom: 4px; }
            .setting-row > span { font-size: 13px; color: rgba(255,255,255,0.78); white-space: nowrap; }
            .setting-row button, .setting-row select { height: 32px; border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; color: white; background: rgba(255,255,255,0.055); font-size: 12.5px; padding: 0 10px; flex-shrink: 0; outline: none; }
            .setting-row.stacked { flex-direction: column; align-items: stretch; gap: 10px; }
            .setting-row.stacked > span { align-self: flex-start; }
            #audioOutput { flex-grow: 1; min-width: 0; }
            .small-btn { padding: 0 10px; white-space: nowrap; font-weight: 500; height: 32px; border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; color: white; background: rgba(255,255,255,0.055); font-size: 12.5px; cursor: pointer; transition: all 0.2s; }
            .small-btn:hover { background: rgba(255,255,255,0.12); }
            .small-btn:active { transform: scale(0.97); }
            .danger { color: #ff453a !important; border-color: rgba(255,69,58,0.25) !important; background: rgba(255,69,58,0.1) !important; }
            .danger:hover { background: rgba(255,69,58,0.2) !important; }

            .dl-btn { width: 20px; height: 20px; border-radius: 50%; border: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.05); color: rgba(255,255,255,0.65); display: grid; place-items: center; cursor: pointer; transition: all 0.2s ease; outline: none; flex-shrink: 0; margin-right: 6px; padding: 0; }
            .dl-btn:hover:not(:disabled) { background: rgba(255,255,255,0.12); color: #fff; border-color: rgba(255,255,255,0.15); }
            .dl-btn:active:not(:disabled) { transform: scale(0.92); }
            .dl-btn:disabled { cursor: default; }
            .spinner { animation: spin 1s linear infinite; }
            @keyframes spin { to { transform: rotate(360deg); } }

            .segmented-control { display: grid; grid-template-columns: repeat(3, 1fr); background: rgba(255,255,255,0.045); border: 1px solid rgba(255,255,255,0.07); padding: 3px; margin-bottom: 10px; flex-shrink: 0; gap: 2px; width: 100%; border-radius: 12px; }
            .seg-btn { height: 30px; border: none; background: transparent; color: rgba(255,255,255,0.48); font-size: 12px; border-radius: 9px; font-weight: 500; transition: all 0.18s ease; cursor: pointer; padding: 0 4px; display: flex; align-items: center; justify-content: center; gap: 5px; outline: none; min-width: 0; }
            .seg-btn:hover { color: rgba(255,255,255,0.85); background: rgba(255,255,255,0.045); }
            .seg-btn.active { color: var(--accent); background: rgba(85,240,168,0.12); }
            .playlist-tabs { display: flex; background: transparent; border-bottom: 1px solid rgba(255,255,255,0.08); padding: 0; margin-bottom: 10px; flex-shrink: 0; gap: 14px; width: 100%; justify-content: flex-start; }
            .playlist-tab-btn { height: 28px; border: none; background: transparent; color: rgba(255,255,255,0.48); font-size: 11px; border-radius: 0; font-weight: 400; transition: all 0.2s ease; cursor: pointer; padding: 0 2px; display: flex; align-items: center; gap: 4px; border-bottom: 2px solid transparent; outline: none; }
            .playlist-tab-btn:hover { color: rgba(255,255,255,0.85); }
            .playlist-tab-btn.active { color: var(--accent); border-bottom: 2px solid var(--accent); }
            .tabs-container { display: flex; flex-direction: column; flex: 1; min-height: 0; }
            .content-panel { padding: 0; overflow: hidden; flex: 1; min-height: 0; border-radius: 16px; }
            .panel { display: none; height: 100%; overflow: auto; }
            .panel.active { display: block; }
            .lyrics { padding: 18px; text-align: center; display: flex; flex-direction: column; justify-content: center; min-height: 100%; }
            .lyric { min-height: 26px; color: rgba(255,255,255,.34); font-size: 13px; line-height: 1.42; display: flex; align-items: center; justify-content: center; padding: 4px 0; transition: all 0.3s ease; }
            .lyric.current { color: var(--accent); font-size: 15px; font-weight: 600; text-shadow: 0 0 18px rgba(85,240,168,0.24); transform: scale(1.03); }
            .playlist { padding: 6px; }
            .track { width: 100%; text-align: left; min-height: 26px; border: none; border-radius: 7px; background: transparent; padding: 3px 8px; color: rgba(255,255,255,.75); font-size: 12.5px; transition: background 0.2s; cursor: pointer; }
            .track:active { background: rgba(255,255,255,0.08); }
            .track.current { color: var(--accent); background: rgba(85,240,168,0.1); font-weight: 600; }
            .discovery-btn { height: 26px; padding: 0 10px; border-radius: 7px; border: none; background: rgba(255,255,255,0.055); color: rgba(255,255,255,0.52); font-size: 11.5px; font-weight: 500; cursor: pointer; white-space: nowrap; transition: all 0.2s; outline: none; }
            .discovery-btn:active { background: rgba(255,255,255,0.12); }
            .discovery-btn.active { background: rgba(85,240,168,0.15) !important; color: var(--accent) !important; }
            .discovery-refresh-btn { width: 26px; height: 26px; border-radius: 7px; border: none; background: rgba(255,255,255,0.055); color: rgba(255,255,255,0.52); cursor: pointer; transition: all 0.2s; outline: none; display: grid; place-items: center; padding: 0; flex-shrink: 0; }
            .discovery-refresh-btn:active { background: rgba(255,255,255,0.12); color: var(--accent); }
            .text-input { border: 1px solid rgba(255,255,255,0.1); background: rgba(255,255,255,0.055); color: white; outline: none; font-size: 12.5px; }
            .primary-btn { border: none; background: var(--accent); color: #020403; font-weight: 650; cursor: pointer; font-size: 12.5px; }
          </style>
        </head>
        <body>
          <main>
            <header>
              <div class="brand">
                <span class="brand-mark" aria-hidden="true"></span>
                <h1>Onion Remote</h1>
              </div>
              <div class="header-actions">
                <button class="header-btn" onclick="openSettings()" title="设置">
                  <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="3"></circle>
                    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
                  </svg>
                </button>
                <button class="header-btn" onclick="sleepMac()" title="让 Mac 睡眠">
                  <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
                  </svg>
                </button>
              </div>
            </header>

            <div class="card hero">
              <div id="title" class="title">未播放</div>
              <div id="state" class="status">连接中...</div>

              <div class="controls">
                <button id="mode" class="icon-btn mode-btn" onclick="call('/api/playback-mode/toggle')">循环</button>
                <button class="icon-btn" onclick="call('/api/previous')" title="上一首"><svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z"/></svg></button>
                <button id="play" class="play-btn" onclick="call('/api/play-pause')" title="播放 / 暂停"><svg viewBox="0 0 24 24" width="30" height="30" fill="currentColor"><path d="M8 5v14l11-7z"/></svg></button>
                <button class="icon-btn" onclick="call('/api/next')" title="下一首"><svg viewBox="0 0 24 24" width="22" height="22" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg></button>
                <div style="width: 44px;"></div>
              </div>

              <div class="volume">
                <span class="volume-icon"><svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor"><path d="M4 9v6h4l5 4V5L8 9H4zm12.5 3a4.5 4.5 0 0 0-2.5-4.03v8.06A4.5 4.5 0 0 0 16.5 12z"/></svg></span>
                <input id="volume" type="range" min="0" max="1" step="0.01" oninput="setVolume(this.value)">
                <span id="volumeText">100%</span>
              </div>
            </div>

            <div class="tabs-container">
              <div class="segmented-control">
                <button id="lyricsTab" class="seg-btn active" onclick="setTab('lyrics')">
                  <svg viewBox="0 0 24 24" width="12" height="12" fill="currentColor" style="opacity: 0.85;"><path d="M21.99 4c0-1.1-.89-2-1.99-2H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h14l4 4-.01-18zM6 6h12v2H6V6zm12 8H6v-2h12v2zm0-3H6V9h12v2z"/></svg>歌词
                </button>
                <button id="playlistTab" class="seg-btn" onclick="setTab('playlist')">
                  <svg viewBox="0 0 24 24" width="12" height="12" fill="currentColor" style="opacity: 0.85;"><path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h6V3h-8z"/></svg>本地曲库
                  <span id="localPlaylistBadge" style="display: none; background: rgba(85,240,168,0.12); color: var(--accent); font-size: 10px; padding: 1px 5px; border-radius: 8px; margin-left: 4px; font-weight: 500;">0</span>
                </button>
                <button id="searchTab" class="seg-btn" onclick="setTab('search')">
                  <svg viewBox="0 0 24 24" width="12" height="12" fill="currentColor" style="opacity: 0.85;"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z"/></svg>线上发现
                </button>
              </div>
              <div class="card content-panel">
                <section id="lyricsPanel" class="panel active">
                  <div id="lyrics" class="lyrics"><div class="lyric">歌词同步中...</div></div>
                </section>
                <section id="playlistPanel" class="panel">
                  <div style="padding: 12px 12px 8px 12px; position: sticky; top: 0; background: rgba(0,0,0,0.82); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); z-index: 10; border-bottom: 1px solid rgba(255,255,255,0.04);">
                    <input id="playlistSearchInput" class="text-input" type="text" placeholder="模糊搜索歌曲..." style="width: 100%; height: 32px; border-radius: 9px; padding: 0 10px;" oninput="filterPlaylist()">
                  </div>
                  <div id="playlist" class="playlist"></div>
                </section>
                <section id="searchPanel" class="panel">
                  <div style="display: flex; flex-direction: column; min-height: 100%;">
                    <div style="position: sticky; top: 0; z-index: 10; padding: 12px 12px 8px 12px; background: rgba(0,0,0,0.82); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); border-bottom: 1px solid rgba(255,255,255,0.04);">
                      <div style="display: flex; gap: 7px; margin-bottom: 10px;">
                        <input type="hidden" id="searchSource" value="netease">
                        <input id="searchInput" class="text-input" type="text" placeholder="输入歌名、歌手..." style="flex: 1; height: 32px; border-radius: 9px; padding: 0 10px;" onkeypress="if(event.key === 'Enter') performSearch()">
                        <button class="primary-btn" onclick="performSearch()" style="height: 32px; padding: 0 12px; border-radius: 9px;">搜索</button>
                      </div>
                      <div style="display: flex; gap: 6px; overflow-x: auto; padding-bottom: 4px; -webkit-overflow-scrolling: touch;">
                        <button class="discovery-btn" onclick="loadDiscovery('3778678', this)">热歌</button>
                        <button class="discovery-btn" onclick="loadDiscovery('3779629', this)">新歌</button>
                        <button class="discovery-btn" onclick="loadDiscovery('19723756', this)">飙升</button>
                        <button class="discovery-btn" onclick="loadDiscovery('2884035', this)">原创</button>
                        <button class="discovery-btn" onclick="loadDiscovery('simi', this)">相似</button>
                        <button class="discovery-refresh-btn" onclick="refreshDiscovery()" title="刷新当前发现列表"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 0 1-15.5 6.2"></path><path d="M3 12A9 9 0 0 1 18.5 5.8"></path><path d="M18 2v4h4"></path><path d="M6 22v-4H2"></path></svg></button>
                      </div>
                    </div>
                    <div id="searchResults" style="display: flex; flex-direction: column; padding: 6px;">
                      <div style="text-align: center; color: rgba(255,255,255,0.4); margin-top: 30px; font-size: 13px;">网易云音乐检索<br><br>输入歌名、歌手，极速检索下载</div>
                    </div>
                  </div>
                </section>
              </div>
            </div>
          </main>

          <!-- Settings Modal -->
          <div id="settingsModal" class="modal-overlay" onclick="closeSettingsOnOuterClick(event)">
            <div class="modal-content card" onclick="event.stopPropagation()">
              <div class="modal-header">
                <h2>系统设置</h2>
                <button class="modal-close" onclick="closeSettings()">✕</button>
              </div>
              <div class="settings">
                <div class="setting-row">
                  <span>输出设备</span>
                  <select id="audioOutput" onchange="setAudioOutput(this.value)">
                    <option value="">跟随系统</option>
                  </select>
                </div>
                <div class="setting-row stacked">
                  <span>蓝牙音频</span>
                  <select id="bluetoothDevices" style="width: 100%;">
                    <option value="">未找到设备</option>
                  </select>
                  <div style="display: flex; gap: 8px; width: 100%; margin-top: 2px;">
                    <button class="small-btn" onclick="connectBluetooth()" style="flex: 1;">连接</button>
                    <button class="small-btn danger" onclick="disconnectBluetooth()" style="flex: 1;">断开</button>
                  </div>
                </div>
                <div class="setting-row stacked" style="margin-top: 12px; border-top: 1px solid rgba(255,255,255,0.05); padding-top: 12px;">
                  <div style="display: flex; justify-content: space-between; align-items: center; width: 100%;">
                    <span>网易云 VIP Cookie</span>
                    <a href="#" onclick="alert('如何获取 Cookie：\n1. 在电脑浏览器登录网易云音乐网页版 (music.163.com)\n2. 按 F12 打开开发者工具，切换到 Network (网络) 标签\n3. 刷新网页，点击任意请求，在 Headers (标头) 里找到 Cookie 字段\n4. 复制整个 Cookie 的值并粘贴到下方')" style="color: var(--accent); font-size: 12px; text-decoration: none;">获取教程</a>
                  </div>
                  <textarea id="neteaseCookie" class="text-input" placeholder="在此粘贴网易云 Cookie，例如: os=pc;appver=;MUSIC_U=..." style="width: 100%; height: 58px; border-radius: 9px; color: #fff; padding: 8px; font-size: 11.5px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; resize: none; margin-top: 6px;"></textarea>
                  <button class="small-btn primary-btn" onclick="saveNeteaseCookie(this)" style="width: 100%; margin-top: 6px; border: none;">保存授权</button>
                </div>
              </div>
            </div>
          </div>

          <script>
            let volumeTimer = null;
            let activeTab = 'lyrics';
            let activeDiscovery = { type: '3778678', element: null };
            let lastLocalCurrentIndex = null;
            let lastOnlineCurrentSongId = null;
            let pendingScrollTab = null;
            let audioOutputRefreshInterval = 5000;
            let audioOutput = document.getElementById('audioOutput');
            let audioOutputState = { lastRefresh: 0, isEditing: false };
            let bluetoothState = { lastRefresh: 0, isEditing: false };

            function getFailureInfo(errorMsg) {
                if (!errorMsg) return { label: ' [失败]', color: '#fc4747' };
                if (errorMsg.includes('超时')) {
                    return { label: ' [超时]', color: '#fc992e' };
                } else if (errorMsg.includes('版权') || errorMsg.includes('VIP')) {
                    return { label: ' [VIP/版权]', color: '#fc4747' };
                } else {
                    return { label: ' [失败]', color: '#fc4747' };
                }
            }

            function fuzzyMatch(pattern, str) {
                let pIdx = 0, sIdx = 0;
                const p = pattern.toLowerCase(), s = str.toLowerCase();
                while (pIdx < p.length && sIdx < s.length) {
                    if (p[pIdx] === s[sIdx]) pIdx++;
                    sIdx++;
                }
                return pIdx === p.length;
            }

            function filterPlaylist() {
                const searchInput = document.getElementById('playlistSearchInput');
                if (!searchInput) return;
                const searchStr = searchInput.value.trim();
                const playlist = document.getElementById('playlist');
                if (!playlist) return;
                Array.from(playlist.children).forEach(row => {
                    const btn = row.querySelector('.track');
                    if (btn) {
                        const titleText = btn.textContent.replace(/^\\d+\\.\\s/, '');
                        row.style.display = (searchStr === '' || fuzzyMatch(searchStr, titleText)) ? 'flex' : 'none';
                    }
                });
            }

            function scrollCurrentTrackIntoView(tab) {
              requestAnimationFrame(() => {
                const selector = tab === 'playlist' ? '#playlist .track.current' : '#searchResults .track.current';
                const currentTrack = document.querySelector(selector);
                if (currentTrack) {
                  currentTrack.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
              });
            }

            function scheduleCurrentTrackScroll(tab) {
              pendingScrollTab = tab;
              scrollCurrentTrackIntoView(tab);
            }

            async function call(path) {
              const response = await fetch(path, { method: 'POST' });
              render(await response.json());
            }
            
            function escapeHTML(value) {
              return String(value ?? '').replace(/[&<>"']/g, char => ({
                '&': '&amp;',
                '<': '&lt;',
                '>': '&gt;',
                '"': '&quot;',
                "'": '&#39;'
              }[char]));
            }

            function parseLocalTrack(title) {
              const separators = [" - ", " – ", " — "];
              for (const sep of separators) {
                const parts = title.split(sep);
                if (parts.length >= 2) {
                  const song = parts[0].trim();
                  const artist = parts.slice(1).join(sep).trim();
                  if (song && artist) {
                    return { title: song, artist: artist };
                  }
                }
              }
              return { title: title, artist: null };
            }

            function copyTextToClipboard(text) {
              if (navigator.clipboard && window.isSecureContext) {
                return navigator.clipboard.writeText(text);
              } else {
                const textArea = document.createElement("textarea");
                textArea.value = text;
                textArea.style.position = "fixed";
                textArea.style.left = "-999999px";
                textArea.style.top = "-999999px";
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                return new Promise((resolve, reject) => {
                  try {
                    const successful = document.execCommand('copy');
                    if (successful) {
                      resolve();
                    } else {
                      reject(new Error('Copy failed'));
                    }
                  } catch (err) {
                    reject(err);
                  }
                  document.body.removeChild(textArea);
                });
              }
            }
            
            function renderSearchStatus(message, color = 'rgba(255,255,255,0.5)') {
              return '<div style="text-align: center; color: ' + color + '; padding: 22px 18px; font-size: 12px; line-height: 1.45;">' + escapeHTML(message) + '</div>';
            }

            function setTab(tab) {
              activeTab = tab;
              document.getElementById('lyricsTab').classList.toggle('active', tab === 'lyrics');
              document.getElementById('playlistTab').classList.toggle('active', tab === 'playlist');
              document.getElementById('searchTab').classList.toggle('active', tab === 'search');
              document.getElementById('lyricsPanel').classList.toggle('active', tab === 'lyrics');
              document.getElementById('playlistPanel').classList.toggle('active', tab === 'playlist');
              document.getElementById('searchPanel').classList.toggle('active', tab === 'search');

              if (tab === 'playlist') {
                pendingScrollTab = null;
                scrollCurrentTrackIntoView('playlist');
              } else if (tab === 'search') {
                pendingScrollTab = 'search';
                scrollCurrentTrackIntoView('search');
              }

              if (tab === 'search') {
                const results = document.getElementById('searchResults');
                if (results && results.innerHTML.includes('网易云音乐检索')) {
                  const hotBtn = document.querySelector('.discovery-btn');
                  loadDiscovery('3778678', hotBtn);
                }
              }
            }

            function openSettings() {
              document.getElementById('settingsModal').classList.add('active');
              refreshAudioOutput();
              refreshBluetooth();
              fetchNeteaseCookie();
            }

            function closeSettings() {
              document.getElementById('settingsModal').classList.remove('active');
            }

            function closeSettingsOnOuterClick(event) {
              if (event.target === document.getElementById('settingsModal')) {
                closeSettings();
              }
            }

            async function sleepMac() {
              await fetch('/api/sleep', { method: 'POST' });
              document.getElementById('state').textContent = 'Mac mini 即将进入睡眠';
            }

            function setVolume(value) {
              document.getElementById('volumeText').textContent = Math.round(value * 100) + '%';
              clearTimeout(volumeTimer);
              volumeTimer = setTimeout(() => call('/api/volume?value=' + encodeURIComponent(value)), 90);
            }

            async function refresh() {
              try {
                const response = await fetch('/api/state');
                render(await response.json());
                const now = Date.now();
                const isModalOpen = document.getElementById('settingsModal').classList.contains('active');
                if (isModalOpen) {
                  if (now - audioOutputState.lastRefresh > audioOutputRefreshInterval && !audioOutputState.isEditing) {
                    refreshAudioOutput();
                  }
                  if (now - bluetoothState.lastRefresh > audioOutputRefreshInterval && !bluetoothState.isEditing) {
                    refreshBluetooth();
                  }
                }
              } catch {
                document.getElementById('state').textContent = '连接断开';
              }
            }

            async function refreshAudioOutput() {
              audioOutputState.lastRefresh = Date.now();
              const response = await fetch('/api/audio-output');
              renderAudioOutput(await response.json());
            }

            async function setAudioOutput(uid) {
              const response = await fetch('/api/audio-output?uid=' + encodeURIComponent(uid), { method: 'POST' });
              renderAudioOutput(await response.json());
            }

            async function refreshBluetooth() {
              bluetoothState.lastRefresh = Date.now();
              const response = await fetch('/api/bluetooth');
              const data = await response.json();
              const select = document.getElementById('bluetoothDevices');
              const currentValue = select.value;
              select.innerHTML = '';
              if (data.devices.length === 0) {
                select.innerHTML = '<option value="">未找到蓝牙音频设备</option>';
                return;
              }
              data.devices.forEach(device => {
                const option = document.createElement('option');
                option.value = device.address;
                option.textContent = device.name + (device.isConnected ? ' [已连接]' : '');
                select.appendChild(option);
              });
              if (Array.from(select.options).some(o => o.value === currentValue)) {
                  select.value = currentValue;
              }
            }

            async function connectBluetooth() {
              const address = document.getElementById('bluetoothDevices').value;
              if (!address) return;
              document.getElementById('state').textContent = '正在发起蓝牙连接...';
              const response = await fetch('/api/bluetooth/connect?address=' + encodeURIComponent(address), { method: 'POST' });
              const data = await response.json();
              document.getElementById('state').textContent = data.message;
              setTimeout(refreshBluetooth, 2000);
            }

            async function disconnectBluetooth() {
              const address = document.getElementById('bluetoothDevices').value;
              if (!address) return;
              document.getElementById('state').textContent = '正在发起蓝牙断开...';
              const response = await fetch('/api/bluetooth/disconnect?address=' + encodeURIComponent(address), { method: 'POST' });
              const data = await response.json();
              document.getElementById('state').textContent = data.message;
              setTimeout(refreshBluetooth, 2000);
            }

            function renderAudioOutput(data) {
              audioOutput.innerHTML = '<option value="">跟随系统</option>';
              data.devices.forEach(device => {
                const option = document.createElement('option');
                option.value = device.id;
                option.textContent = device.name;
                audioOutput.appendChild(option);
              });
              audioOutput.value = data.preferredUID || '';
            }

            function render(data) {
              document.getElementById('state').textContent = data.isPlaying ? '播放中 ' + data.currentTimeText + ' / ' + data.durationText : '已暂停 ' + data.currentTimeText + ' / ' + data.durationText;
              document.getElementById('title').textContent = data.artist ? data.title + ' - ' + data.artist : data.title;

              const playBtn = document.getElementById('play');
              playBtn.innerHTML = data.isPlaying ? '<svg viewBox="0 0 24 24" width="30" height="30" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>' : '<svg viewBox="0 0 24 24" width="30" height="30" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>';
              playBtn.classList.toggle('paused', data.isPlaying);

              document.getElementById('volume').value = data.volume;
              document.getElementById('volumeText').textContent = Math.round(data.volume * 100) + '%';
              const modeMap = { '列表循环': '循环', '单曲循环': '单曲', '随机播放': '随机' };
              if (document.getElementById('mode') && data.playbackMode) {
                document.getElementById('mode').textContent = modeMap[data.playbackMode] || '循环';
              }
              renderLyrics(data.lyrics);

              window.lastState = data;

              // Update the local playlist count badge
              const localPlaylistCount = data.localPlaylist ? data.localPlaylist.length : 0;
              const badge = document.getElementById('localPlaylistBadge');
              if (badge) {
                if (localPlaylistCount > 0) {
                  badge.textContent = localPlaylistCount;
                  badge.style.display = 'inline-flex';
                } else {
                  badge.style.display = 'none';
                }
              }

              const list = data.localPlaylist;
              const playlist = document.getElementById('playlist');
              playlist.innerHTML = '';

              if (!list || list.length === 0) {
                playlist.innerHTML = '<div style="text-align: center; color: rgba(255,255,255,0.4); padding: 30px 0;">列表为空</div>';
              } else {
                list.forEach(item => {
                  const row = document.createElement('div');
                  row.style.display = 'flex';
                  row.style.alignItems = 'center';
                  row.style.borderBottom = '1px solid rgba(255,255,255,0.03)';

                  const button = document.createElement('button');
                  button.className = 'track' + (item.isCurrent ? ' current' : '');
                  button.style.flex = '1';
                  button.style.width = 'auto';
                  button.style.textAlign = 'left';
                  button.style.overflow = 'hidden';
                  button.style.textOverflow = 'ellipsis';
                  button.style.whiteSpace = 'nowrap';
                  const isFailed = item.isFailed;
                  let indexColor = 'rgba(255,255,255,0.3)';
                  let indexOpacity = '1';
                  let titleColor = item.isCurrent ? 'var(--accent)' : 'rgba(255,255,255,0.85)';
                  let titleOpacity = '1';
                  let artistColor = 'rgba(255,255,255,0.45)';
                  let artistOpacity = '1';
                  let failLabelHtml = '';

                  if (isFailed) {
                    const failColor = '#fc4747'; // Coral Red
                    indexColor = failColor;
                    indexOpacity = '0.48';
                    titleColor = failColor;
                    titleOpacity = '0.68';
                    artistColor = failColor;
                    artistOpacity = '0.35';
                    failLabelHtml = '<span class="fail-label" style="color: ' + failColor + '; opacity: 0.75; font-size: 11px; font-weight: 600; margin-left: 4px;"> [未找到/不支持]</span>';
                  }

                  const trackInfo = parseLocalTrack(item.title);
                  const artistHtml = trackInfo.artist ? '<span style="color: ' + artistColor + '; opacity: ' + artistOpacity + '; font-size: 12.5px; font-weight: normal;"> - ' + escapeHTML(trackInfo.artist) + '</span>' : '';
                  button.innerHTML = '<span class="track-index" style="color: ' + indexColor + '; opacity: ' + indexOpacity + '; font-size: 12.5px; margin-right: 6px; font-family: monospace; font-style: italic;">' + (item.index + 1) + '.</span>' +
                    '<span class="result-title" style="color: ' + titleColor + '; opacity: ' + titleOpacity + '; font-weight: 500;">' + escapeHTML(trackInfo.title) + '</span>' +
                    artistHtml +
                    failLabelHtml;
                  button.onclick = () => call('/api/play?type=local&index=' + item.index);

                  const copyBtn = document.createElement('button');
                  copyBtn.className = 'icon-btn';
                  copyBtn.style.width = '26px';
                  copyBtn.style.height = '26px';
                  copyBtn.style.color = 'rgba(255,255,255,0.4)';
                  copyBtn.style.marginRight = '4px';
                  copyBtn.style.transition = 'color 0.15s ease';
                  copyBtn.title = '复制歌名';
                  copyBtn.innerHTML = '<svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display: block; margin: auto;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
                  let isCopied = false;
                  copyBtn.onmouseover = () => { if (!isCopied) copyBtn.style.color = 'rgba(255,255,255,0.85)'; };
                  copyBtn.onmouseout = () => { if (!isCopied) copyBtn.style.color = 'rgba(255,255,255,0.4)'; };
                  copyBtn.onclick = (e) => {
                      e.stopPropagation();
                      copyTextToClipboard(item.title).then(() => {
                          isCopied = true;
                          copyBtn.style.color = '#34c759';
                          setTimeout(() => {
                              isCopied = false;
                              copyBtn.style.color = 'rgba(255,255,255,0.4)';
                          }, 1000);
                      }).catch(err => {
                          console.error('Failed to copy: ', err);
                      });
                  };

                  const delBtn = document.createElement('button');
                  delBtn.className = 'icon-btn';
                  delBtn.style.width = '26px';
                  delBtn.style.height = '26px';
                  delBtn.style.fontSize = '12px';
                  delBtn.style.color = 'rgba(255,255,255,0.4)';
                  delBtn.style.marginRight = '6px';
                  delBtn.textContent = '✕';
                  delBtn.onclick = (e) => {
                      e.stopPropagation();

                      const existing = document.getElementById('custom-dropdown');
                      if (existing) existing.remove();

                      const menu = document.createElement('div');
                      menu.id = 'custom-dropdown';

                      const rect = delBtn.getBoundingClientRect();
                      let topPos = rect.bottom + 4;
                      if (topPos + 80 > window.innerHeight) {
                          topPos = rect.top - 80 - 4;
                      }

                      menu.style.cssText = 'position: fixed; top: ' + topPos + 'px; right: ' + (window.innerWidth - rect.right) + 'px; background: rgba(30,30,30,0.95); border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; padding: 4px; z-index: 10000; box-shadow: 0 4px 12px rgba(0,0,0,0.5); backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px); min-width: 140px; display: flex; flex-direction: column;';

                      const createMenuBtn = (text, color, isTrash) => {
                          const b = document.createElement('button');
                          b.textContent = text;
                          b.style.cssText = 'background: transparent; color: ' + color + '; border: none; padding: 8px 12px; text-align: left; border-radius: 4px; font-size: 13px; cursor: pointer; transition: 0.1s;';
                          b.onmouseover = () => b.style.background = 'rgba(255,255,255,0.1)';
                          b.onmouseout = () => b.style.background = 'transparent';
                          b.onclick = (ev) => {
                              ev.stopPropagation();
                              menu.remove();
                              call('/api/remove?online=false&index=' + item.index + '&trash=' + isTrash);
                          };
                          return b;
                      };

                      menu.appendChild(createMenuBtn('仅从列表中移除', 'white', false));
                      menu.appendChild(createMenuBtn('同时移至废纸篓', '#ff453a', true));

                      document.body.appendChild(menu);

                      const closeMenu = () => {
                          if (menu.parentNode) menu.remove();
                          document.removeEventListener('click', closeMenu);
                      };
                      setTimeout(() => document.addEventListener('click', closeMenu), 0);
                  };

                  row.appendChild(button);
                  row.appendChild(copyBtn);
                  row.appendChild(delBtn);
                  playlist.appendChild(row);
                });
              }
              filterPlaylist();
              const currentLocalItem = list && list.find(item => item.isCurrent);
              const currentLocalIndex = currentLocalItem ? currentLocalItem.index : null;
              if (data.playlistMode === 'local' && currentLocalIndex !== lastLocalCurrentIndex) {
                lastLocalCurrentIndex = currentLocalIndex;
                scheduleCurrentTrackScroll('playlist');
              }

              // Highlight active online song in the search/discovery results list
              const searchItems = document.querySelectorAll('#searchResults > div');
              searchItems.forEach(item => {
                  const songId = item.getAttribute('data-song-id');
                  const isCurrent = data.playlistMode === 'online' && String(songId) === String(data.currentOnlineSongId);
                  const isFailed = data.failedOnlineSongIDs && data.failedOnlineSongIDs.includes(Number(songId));
                  const trackBtn = item.querySelector('.track');
                  if (trackBtn) {
                      trackBtn.classList.toggle('current', isCurrent);
                      const titleSpan = trackBtn.querySelector('.result-title');
                      const uploaderSpan = trackBtn.querySelector('.result-uploader');
                      const idxSpan = trackBtn.querySelector('.track-index');
                      let failLabelSpan = trackBtn.querySelector('.fail-label');
                      
                      // Remove warning icon ⚠️ if any was there
                      let failIconSpan = trackBtn.querySelector('.fail-icon');
                      if (failIconSpan) failIconSpan.remove();

                      if (isFailed) {
                          const errorMsg = data.onlineSongFailureMessages && data.onlineSongFailureMessages[songId] ? data.onlineSongFailureMessages[songId] : '';
                          const failInfo = getFailureInfo(errorMsg);
                          
                          if (titleSpan) {
                              titleSpan.style.color = failInfo.color;
                              titleSpan.style.opacity = '0.68';
                          }
                          if (uploaderSpan) {
                              uploaderSpan.style.color = failInfo.color;
                              uploaderSpan.style.opacity = '0.35';
                          }
                          if (idxSpan) {
                              idxSpan.style.color = failInfo.color;
                              idxSpan.style.opacity = '0.48';
                          }
                          
                          if (!failLabelSpan) {
                              failLabelSpan = document.createElement('span');
                              failLabelSpan.className = 'fail-label';
                              failLabelSpan.style.cssText = 'font-size: 11px; font-weight: 600; margin-left: 4px;';
                              if (uploaderSpan) {
                                  uploaderSpan.after(failLabelSpan);
                              } else {
                                  trackBtn.appendChild(failLabelSpan);
                              }
                          }
                          failLabelSpan.style.color = failInfo.color;
                          failLabelSpan.style.opacity = '0.75';
                          failLabelSpan.textContent = failInfo.label;
                          
                          trackBtn.title = '';
                      } else {
                          if (titleSpan) {
                              titleSpan.style.color = isCurrent ? 'var(--accent)' : 'rgba(255,255,255,0.85)';
                              titleSpan.style.opacity = '1';
                          }
                          if (uploaderSpan) {
                              uploaderSpan.style.color = 'rgba(255,255,255,0.45)';
                              uploaderSpan.style.opacity = '1';
                          }
                          if (idxSpan) {
                              idxSpan.style.color = 'rgba(255,255,255,0.3)';
                              idxSpan.style.opacity = '1';
                          }
                          if (failLabelSpan) {
                              failLabelSpan.remove();
                          }
                          trackBtn.title = '播放 ' + (titleSpan ? titleSpan.textContent : '');
                      }
                  }
                  const dlBtn = item.querySelector('.dl-btn');
                  if (dlBtn) {
                      if (isFailed) {
                          dlBtn.disabled = true;
                          dlBtn.title = '';
                      }
                  }
              });
              const currentOnlineSongId = data.playlistMode === 'online' ? String(data.currentOnlineSongId || '') : null;
              if (currentOnlineSongId && currentOnlineSongId !== lastOnlineCurrentSongId) {
                lastOnlineCurrentSongId = currentOnlineSongId;
                scheduleCurrentTrackScroll('search');
              }
              if (pendingScrollTab) {
                scrollCurrentTrackIntoView(pendingScrollTab);
                pendingScrollTab = null;
              }
            }

            function renderLyrics(lyrics) {
              const container = document.getElementById('lyrics');
              container.innerHTML = '';
              if (!lyrics || lyrics.state === 'idle') {
                container.innerHTML = '<div class="lyric">选择歌曲后显示歌词</div>';
                return;
              }
              if (lyrics.state === 'loading') {
                container.innerHTML = '<div class="lyric">歌词加载中...</div>';
                return;
              }
              if (lyrics.state === 'onlineDisabled') {
                container.innerHTML = '<div class="lyric">未找到本地歌词，联网匹配已关闭</div>';
                return;
              }
              if (lyrics.state === 'noLyrics') {
                container.innerHTML = '<div class="lyric">暂无歌词</div>';
                return;
              }
              if (lyrics.state === 'failed') {
                container.innerHTML = '<div class="lyric">歌词获取失败</div>';
                return;
              }
              if (lyrics.state === 'candidates') {
                container.innerHTML = '<div class="lyric">需要在 Mac 上选择歌词候选</div>';
                return;
              }
              if (!lyrics.lines || lyrics.lines.length === 0) {
                container.innerHTML = '<div class="lyric">暂无歌词</div>';
                return;
              }
              lyrics.lines.forEach(line => {
                const item = document.createElement('div');
                item.className = 'lyric' + (line.isCurrent ? ' current' : '');
                item.textContent = line.text;
                container.appendChild(item);
              });
            }

            refresh();
            refreshAudioOutput();
            refreshBluetooth();
            fetchNeteaseCookie();

            async function fetchNeteaseCookie() {
              try {
                const res = await fetch('/api/settings/cookie');
                const data = await res.json();
                if (data.cookie) {
                  document.getElementById('neteaseCookie').value = data.cookie;
                }
              } catch (e) { console.error(e); }
            }

            async function saveNeteaseCookie(btn) {
              const cookie = document.getElementById('neteaseCookie').value.trim();
              const originalText = btn.textContent;
              btn.textContent = '保存中...';
              try {
                await fetch('/api/settings/cookie', { method: 'POST', body: cookie });
                btn.textContent = '保存成功';
                setTimeout(() => btn.textContent = originalText, 2000);
              } catch (e) {
                btn.textContent = '保存失败';
                setTimeout(() => btn.textContent = originalText, 2000);
              }
            }

            async function performSearch() {
              const query = document.getElementById('searchInput').value.trim();
              const source = document.getElementById('searchSource').value;
              if (!query) return;

              // Unhighlight discovery buttons
              const buttons = document.querySelectorAll('.discovery-btn');
              buttons.forEach(btn => btn.classList.remove('active'));

              const container = document.getElementById('searchResults');
              container.innerHTML = renderSearchStatus('正在搜索网易云音乐...');

              try {
                const response = await fetch('/api/search?q=' + encodeURIComponent(query) + '&source=' + source);
                const data = await response.json();
                renderSearchResults(data.results || []);
              } catch {
                container.innerHTML = renderSearchStatus('搜索失败，请检查网络后重试', '#ff453a');
              }
            }

            async function loadDiscovery(type, element, forceRefresh = false) {
              activeDiscovery.type = type;
              if (element) {
                activeDiscovery.element = element;
              }
              
              const buttons = document.querySelectorAll('.discovery-btn');
              buttons.forEach(btn => btn.classList.remove('active'));
              if (activeDiscovery.element) {
                activeDiscovery.element.classList.add('active');
              }

              const container = document.getElementById('searchResults');
              container.innerHTML = renderSearchStatus('正在获取排行榜...');

              try {
                let url = '';
                if (type === 'simi') {
                  url = '/api/discovery/simi';
                } else {
                  url = '/api/discovery/playlist?id=' + type;
                }
                url += (url.includes('?') ? '&' : '?') + '_t=' + Date.now();
                if (forceRefresh) {
                  url += '&refresh=true';
                }
                const response = await fetch(url);
                const data = await response.json();
                if (data.error) {
                  container.innerHTML = renderSearchStatus(data.error, '#ff453a');
                } else {
                  renderSearchResults(data.results || []);
                }
              } catch (err) {
                container.innerHTML = renderSearchStatus('获取失败，请检查网络后重试', '#ff453a');
              }
            }
            
            function refreshDiscovery() {
              loadDiscovery(activeDiscovery.type, activeDiscovery.element, true);
            }

            function renderSearchResults(results) {
              const container = document.getElementById('searchResults');
              container.innerHTML = '';
              if (results.length === 0) {
                container.innerHTML = renderSearchStatus('未找到相关资源');
                return;
              }

              results.forEach((res, index) => {
                const row = document.createElement('div');
                row.setAttribute('data-song-id', res.id);
                row.style.display = 'flex';
                row.style.alignItems = 'center';
                row.style.borderBottom = '1px solid rgba(255,255,255,0.03)';

                const isCurrent = window.lastState && window.lastState.playlistMode === 'online' && String(res.id) === String(window.lastState.currentOnlineSongId);
                const isFailed = window.lastState && window.lastState.failedOnlineSongIDs && window.lastState.failedOnlineSongIDs.includes(Number(res.id));

                const button = document.createElement('button');
                button.className = 'track' + (isCurrent ? ' current' : '');
                button.style.flex = '1';
                button.style.width = 'auto';
                button.style.textAlign = 'left';
                button.style.overflow = 'hidden';
                button.style.textOverflow = 'ellipsis';
                button.style.whiteSpace = 'nowrap';

                let indexColor = 'rgba(255,255,255,0.3)';
                let indexOpacity = '1';
                let titleColor = isCurrent ? 'var(--accent)' : 'rgba(255,255,255,0.85)';
                let titleOpacity = '1';
                let uploaderColor = 'rgba(255,255,255,0.45)';
                let uploaderOpacity = '1';
                let failLabelHtml = '';

                if (isFailed) {
                  const errorMsg = (window.lastState && window.lastState.onlineSongFailureMessages && window.lastState.onlineSongFailureMessages[res.id]) || '';
                  const failInfo = getFailureInfo(errorMsg);
                  indexColor = failInfo.color;
                  indexOpacity = '0.48';
                  titleColor = failInfo.color;
                  titleOpacity = '0.68';
                  uploaderColor = failInfo.color;
                  uploaderOpacity = '0.35';
                  failLabelHtml = '<span class="fail-label" style="color: ' + failInfo.color + '; opacity: 0.75; font-size: 11px; font-weight: 600; margin-left: 4px;">' + failInfo.label + '</span>';
                }

                button.innerHTML = '<span class="track-index" style="color: ' + indexColor + '; opacity: ' + indexOpacity + '; font-size: 12.5px; margin-right: 6px; font-family: monospace; font-style: italic;">' + (index + 1) + '.</span>' +
                  '<span class="result-title" style="color: ' + titleColor + '; opacity: ' + titleOpacity + '; font-weight: 500;">' + escapeHTML(res.title) + '</span>' +
                  '<span class="result-uploader" style="color: ' + uploaderColor + '; opacity: ' + uploaderOpacity + '; font-size: 12.5px; font-weight: normal;"> - ' + escapeHTML(res.uploader) + '</span>' +
                  failLabelHtml;
                
                if (isFailed) {
                  button.title = '';
                } else {
                  button.title = '播放 ' + res.title;
                }
                button.onclick = () => playOnlineDirect(res.id, res.title, res.uploader, res.duration, index);

                const btn = document.createElement('button');
                btn.id = 'dl-' + btoa(res.url).replace(/=/g, '');
                btn.className = 'dl-btn';
                if (isFailed) {
                  btn.setAttribute('data-failed', 'true');
                  btn.disabled = true;
                  btn.style.background = 'rgba(255,69,58,0.12)';
                  btn.style.color = '#ff453a';
                  btn.style.borderColor = 'rgba(255,69,58,0.2)';
                  btn.style.cursor = 'default';
                  btn.title = '';
                  btn.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="#ff453a" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>';
                } else {
                  btn.onclick = () => downloadSong(res.url, btn.id, res.title + ' - ' + res.uploader);
                  btn.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>';
                }

                row.appendChild(button);
                row.appendChild(btn);
                container.appendChild(row);
              });
              if (pendingScrollTab === 'search') {
                scrollCurrentTrackIntoView('search');
                pendingScrollTab = null;
              }
            }

            async function downloadSong(url, btnId, title) {
              const btn = document.getElementById(btnId);
              if (!btn) return;

              btn.innerHTML = '<svg class="spinner" viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"></circle><path d="M12 2a10 10 0 0 1 10 10" stroke-width="2.5"></path></svg>';
              btn.style.background = 'rgba(255,255,255,0.05)';
              btn.style.color = 'rgba(255,255,255,0.4)';
              btn.disabled = true;

              await fetch('/api/download?url=' + encodeURIComponent(url) + '&title=' + encodeURIComponent(title || 'Unknown'), { method: 'POST' });

              refreshDownloadStatus();
            }

            async function playOnlineDirect(id, name, artist, duration, index) {
              const path = '/api/play-online?id=' + encodeURIComponent(id) +
                           '&name=' + encodeURIComponent(name) +
                           '&artist=' + encodeURIComponent(artist) +
                           '&duration=' + encodeURIComponent(duration || '0') +
                           '&index=' + index;
              const res = await fetch(path, { method: 'POST' });
              const data = await res.json();
              render(data);
            }

            async function refreshDownloadStatus() {
              if (activeTab !== 'search') return;
              try {
                const response = await fetch('/api/download-status');
                const statusDict = await response.json();

                Object.keys(statusDict).forEach(url => {
                  const btnId = 'dl-' + btoa(url).replace(/=/g, '');
                  const btn = document.getElementById(btnId);
                  if (btn) {
                    if (btn.getAttribute('data-failed') === 'true') {
                      btn.disabled = true;
                      btn.style.background = 'rgba(255,69,58,0.12)';
                      btn.style.color = '#ff453a';
                      btn.style.borderColor = 'rgba(255,69,58,0.2)';
                      btn.style.cursor = 'default';
                      btn.title = '播放失败，无法下载';
                      btn.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="#ff453a" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>';
                      return;
                    }
                    const status = statusDict[url];
                    if (status === 'completed') {
                      btn.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
                      btn.style.background = 'rgba(85,240,168,0.12)';
                      btn.style.color = 'var(--accent)';
                      btn.disabled = true;
                    } else if (status.startsWith('failed')) {
                      btn.innerHTML = '<svg viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="#ff453a" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>';
                      btn.style.background = 'rgba(255,69,58,0.12)';
                      btn.style.color = '#ff453a';
                      btn.disabled = false;

                      const errorMsg = status.includes(':') ? status.split(':', 2)[1] : '未知错误';
                      btn.onclick = () => {
                          alert(errorMsg);
                      };
                    } else if (status === 'downloading') {
                      btn.innerHTML = '<svg class="spinner" viewBox="0 0 24 24" width="10" height="10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"></circle><path d="M12 2a10 10 0 0 1 10 10" stroke-width="2.5"></path></svg>';
                      btn.style.background = 'rgba(255,255,255,0.05)';
                      btn.style.color = 'rgba(255,255,255,0.4)';
                      btn.disabled = true;
                    }
                  }
                });
              } catch {}
            }

            setInterval(() => {
                refresh();
                refreshDownloadStatus();
            }, 1000);

            audioOutput.addEventListener('focus', () => { audioOutputState.isEditing = true; });
            audioOutput.addEventListener('blur', () => { audioOutputState.isEditing = false; });
            document.getElementById('bluetoothDevices').addEventListener('focus', () => { bluetoothState.isEditing = true; });
            document.getElementById('bluetoothDevices').addEventListener('blur', () => { bluetoothState.isEditing = false; });
          </script>
        </body>
        </html>
        """
    }
}

struct SearchResult: Codable {
    let id: String
    let title: String
    let uploader: String
    let duration: Double
    let url: String
}

private struct RemoteDiscoveryTrack {
    let id: String
    let title: String
    let uploader: String
    let duration: Double
    let url: String
    
    init(song: NeteaseSong) {
        self.id = String(song.id)
        self.title = song.name
        self.uploader = song.artistName
        self.duration = Double(song.dt ?? 0) / 1000.0
        self.url = "netease:\(song.id)"
    }
    
    var payload: [String: Any] {
        [
            "id": id,
            "title": title,
            "uploader": uploader,
            "duration": duration,
            "url": url
        ]
    }
}

actor DownloadManager {
    static let shared = DownloadManager()
    
    private let downloadDirectory: URL
    private var downloadTasks: [String: String] = [:] // url -> status
    
    var onDownloadCompleted: ((URL) -> Void)?
    
    func setOnDownloadCompleted(_ handler: @escaping (URL) -> Void) {
        self.onDownloadCompleted = handler
    }
    
    init() {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        downloadDirectory = musicDir.appendingPathComponent("OnionFlow Downloads")
        try? FileManager.default.createDirectory(at: downloadDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    private var executableURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("OnionFlow/yt-dlp")
    }

    private func ensureYtDlpExists() async throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let onionDir = appSupport.appendingPathComponent("OnionFlow")
        if !fileManager.fileExists(atPath: onionDir.path) {
            try fileManager.createDirectory(at: onionDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let url = executableURL
        if fileManager.fileExists(atPath: url.path) {
            return
        }
        
        guard let downloadUrl = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos") else { return }
        let (tempURL, _) = try await URLSession.shared.download(from: downloadUrl)
        try fileManager.moveItem(at: tempURL, to: url)
        
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
    }

    func search(query: String) async throws -> [SearchResult] {
        try await ensureYtDlpExists()
        
        let process = Process()
        process.executableURL = executableURL
        // "ytsearch5:query" fetches top 5 results from youtube
        process.arguments = ["ytsearch5:\(query)", "--dump-json", "--no-playlist", "--ignore-errors", "--no-check-certificates"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()
        
        let output = String(data: data, encoding: .utf8) ?? ""
        
        var results: [SearchResult] = []
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            if let lineData = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
               let id = json["id"] as? String,
               let title = json["title"] as? String,
               let uploader = json["uploader"] as? String,
               let duration = json["duration"] as? Double,
               let url = json["webpage_url"] as? String {
                results.append(SearchResult(id: id, title: title, uploader: uploader, duration: duration, url: url))
            }
        }
        return results
    }
    
    func download(url: String) {
        guard downloadTasks[url] == nil || downloadTasks[url] == "failed" else { return }
        downloadTasks[url] = "downloading"
        
        Task {
            do {
                try await self.ensureYtDlpExists()
                
                let process = Process()
                process.executableURL = executableURL
                
                // Set output template
                let youtubeDirectory = downloadDirectory.appendingPathComponent("YouTube")
                try? FileManager.default.createDirectory(at: youtubeDirectory, withIntermediateDirectories: true, attributes: nil)
                let outputTemplate = youtubeDirectory.appendingPathComponent("%(title)s.%(ext)s").path
                process.arguments = [
                    "-f", "bestaudio[ext=m4a]",
                    "--newline",
                    "--no-check-certificates",
                    "-o", outputTemplate,
                    url
                ]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                
                let errorPipe = Pipe()
                process.standardError = errorPipe
                
                // Keep readability handler but discard output to prevent pipe deadlock
                pipe.fileHandleForReading.readabilityHandler = { _ in }
                
                try process.run()
                process.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                
                let errData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
                let errorString = String(data: errData, encoding: .utf8) ?? ""
                if !errorString.isEmpty {
                    let logUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("OnionFlow/ytdlp_error.log")
                    try? errorString.write(to: logUrl, atomically: true, encoding: .utf8)
                }
                
                if process.terminationStatus == 0 {
                    await setStatus(for: url, status: "completed")
                    
                    if let latestFile = getLatestDownloadedM4A() {
                        DispatchQueue.main.async {
                            self.onDownloadCompleted?(latestFile)
                        }
                    }
                } else {
                    DiagnosticLogService.shared.log("download.ytdlp.failed", [
                        "status": String(process.terminationStatus)
                    ])
                    await setStatus(for: url, status: "failed")
                }
            } catch {
                DiagnosticLogService.shared.log("download.ytdlp.failed", [
                    "error": error.localizedDescription
                ])
                await setStatus(for: url, status: "failed")
            }
        }
    }
    
    private func setStatus(for url: String, status: String) {
        downloadTasks[url] = status
    }
    
    func downloadNetease(id: String, title: String) async {
        let urlKey = "netease:\(id)"
        guard downloadTasks[urlKey] == nil || downloadTasks[urlKey] == "failed" else { return }
        downloadTasks[urlKey] = "downloading"
        
        do {
            let songUrlStr = try await NeteaseAPI.shared.getSongUrl(id: id)
            guard let songUrl = URL(string: songUrlStr) else { throw NSError(domain: "DownloadManager", code: 1, userInfo: nil) }
            
            let ext = songUrl.pathExtension.isEmpty ? "mp3" : songUrl.pathExtension
            let safeTitle = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
            
            let neteaseDirectory = downloadDirectory.appendingPathComponent("Netease")
            try? FileManager.default.createDirectory(at: neteaseDirectory, withIntermediateDirectories: true, attributes: nil)
            
            let destURL = neteaseDirectory.appendingPathComponent("\(safeTitle).\(ext)")
            
            if FileManager.default.fileExists(atPath: destURL.path) {
                self.downloadTasks[urlKey] = "completed"
                self.onDownloadCompleted?(destURL)
                return
            }
            
            let (tempURL, response) = try await URLSession.shared.download(from: songUrl)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "DownloadManager", code: 2, userInfo: nil)
            }
            
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            
            self.downloadTasks[urlKey] = "completed"
            self.onDownloadCompleted?(destURL)
            
        } catch {
            DiagnosticLogService.shared.log("download.netease.failed", [
                "songID": id,
                "error": error.localizedDescription
            ])
            self.downloadTasks[urlKey] = "failed:\(error.localizedDescription)"
        }
    }

    func getStatus() async -> [String: String] {
        return downloadTasks
    }
    
    private func getLatestDownloadedM4A() -> URL? {
        do {
            let youtubeDirectory = downloadDirectory.appendingPathComponent("YouTube")
            let files = try FileManager.default.contentsOfDirectory(at: youtubeDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            let m4aFiles = files.filter { $0.pathExtension.lowercased() == "m4a" }
            return m4aFiles.max { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return dateA < dateB
            }
        } catch {
            return nil
        }
    }
}

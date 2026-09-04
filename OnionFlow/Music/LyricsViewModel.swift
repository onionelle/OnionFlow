import Combine
import Foundation
import SwiftUI

/// 歌词状态入口：按调用方触发检查歌词，且只有用户允许时才进入在线检索。
@MainActor
final class LyricsViewModel: ObservableObject {
    @Published private(set) var lyricLines: [LyricLine] = []
    @Published private(set) var currentLineIndex: Int?
    @Published private(set) var state: LyricsState = .idle
    @Published private(set) var isSlowLoading: Bool = false
    @Published private(set) var loadingCountdown: Int = 60

    enum LyricsState: Equatable {
        case idle
        case loading
        case onlineDisabled
        case candidates([OnlineLyricsCandidate])
        case success
        case failed(String)
        case noLyrics
    }

    @AppStorage("onlineLyricsEnabled") private var onlineLyricsEnabled = false
    private let service: LyricsService
    private var currentTrackURL: URL?
    private var latestPlaybackTime: TimeInterval = 0
    private var lyricsBeforeRematch: [LyricLine]?
    private var loadTask: Task<Void, Never>?

    var canCancelCandidateSelection: Bool {
        if case .candidates = state {
            return lyricsBeforeRematch != nil
        }
        return false
    }

    init(service: LyricsService? = nil) {
        self.service = service ?? LyricsService()
    }

    func setCurrentTrack(_ track: MusicTrack?) {
        guard currentTrackURL != track?.url else { return }
        loadTask?.cancel()
        currentTrackURL = track?.url
        latestPlaybackTime = 0
        lyricsBeforeRematch = nil
        lyricLines = []
        currentLineIndex = nil
        state = .idle
        isSlowLoading = false
        loadingCountdown = 60
    }

    func loadLyrics(for track: MusicTrack?) {
        guard let track else {
            clear()
            return
        }
        if currentTrackURL == track.url && state != .idle {
            return
        }
        setCurrentTrack(track)
        beginLoading(for: track, useStoredLyrics: true)
    }

    func retry(for track: MusicTrack?) {
        guard let track else { return }
        lyricsBeforeRematch = nil
        beginLoading(for: track, useStoredLyrics: false, searchMode: .automatic)
    }

    func rematch(for track: MusicTrack?) {
        guard let track else { return }
        lyricsBeforeRematch = state == .success ? lyricLines : nil
        beginLoading(for: track, useStoredLyrics: false, searchMode: .userSelection)
    }

    func select(_ candidate: OnlineLyricsCandidate, for track: MusicTrack?) {
        guard let track else { return }
        lyricsBeforeRematch = nil
        loadTask?.cancel()
        state = .loading
        isSlowLoading = false
        loadingCountdown = 60
        loadTask = Task {
            let timerTask = Task {
                while !Task.isCancelled && loadingCountdown > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if !Task.isCancelled {
                        loadingCountdown -= 1
                    }
                }
            }
            let hintTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 秒超时
                if !Task.isCancelled {
                    isSlowLoading = true
                }
            }
            defer {
                hintTask.cancel()
                timerTask.cancel()
                isSlowLoading = false
            }
            let result = await service.downloadLyrics(for: candidate, track: track)
            guard !Task.isCancelled && currentTrackURL == track.url else { return }
            apply(result)
        }
    }

    func importLocalLyrics(from url: URL, for track: MusicTrack?) {
        guard let track else { return }
        guard let lines = service.importLyricsFile(url, for: track) else {
            DiagnosticLogService.shared.log("lyrics.import.failed", url: url)
            state = .failed("无法读取所选 LRC 文件")
            return
        }
        lyricsBeforeRematch = nil
        showLyrics(lines)
    }

    func cancelCandidateSelection() {
        guard let lines = lyricsBeforeRematch else { return }
        lyricsBeforeRematch = nil
        showLyrics(lines)
    }

    func clear() {
        loadTask?.cancel()
        currentTrackURL = nil
        latestPlaybackTime = 0
        lyricsBeforeRematch = nil
        lyricLines = []
        currentLineIndex = nil
        state = .idle
        isSlowLoading = false
        loadingCountdown = 60
    }

    func updateTime(_ time: TimeInterval) {
        latestPlaybackTime = time
        guard state == .success, !lyricLines.isEmpty else {
            if currentLineIndex != nil {
                currentLineIndex = nil
            }
            return
        }

        var foundIndex: Int?
        for index in lyricLines.indices {
            if time >= lyricLines[index].time {
                foundIndex = index
            } else {
                break
            }
        }
        if currentLineIndex != foundIndex {
            currentLineIndex = foundIndex
        }
    }

    private func beginLoading(
        for track: MusicTrack,
        useStoredLyrics: Bool,
        searchMode: LyricsSearchMode = .automatic
    ) {
        loadTask?.cancel()
        currentTrackURL = track.url
        lyricLines = []
        currentLineIndex = nil
        state = .loading
        isSlowLoading = false
        loadingCountdown = 60

        loadTask = Task {
            let timerTask = Task {
                while !Task.isCancelled && loadingCountdown > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if !Task.isCancelled {
                        loadingCountdown -= 1
                    }
                }
            }
            let hintTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 秒超时
                if !Task.isCancelled {
                    isSlowLoading = true
                }
            }
            defer {
                hintTask.cancel()
                timerTask.cancel()
                isSlowLoading = false
            }

            if useStoredLyrics, let lines = service.loadStoredLyrics(for: track) {
                hintTask.cancel()
                guard !Task.isCancelled && currentTrackURL == track.url else { return }
                showLyrics(lines)
                return
            }
            guard onlineLyricsEnabled else {
                hintTask.cancel()
                guard !Task.isCancelled && currentTrackURL == track.url else { return }
                state = .onlineDisabled
                return
            }
            let result = await service.searchOnlineLyrics(for: track, mode: searchMode)
            hintTask.cancel()
            guard !Task.isCancelled && currentTrackURL == track.url else { return }
            apply(result)
        }
    }

    private func apply(_ result: OnlineLyricsResult) {
        switch result {
        case .lyrics(let lines):
            showLyrics(lines)
        case .candidates(let candidates):
            state = .candidates(candidates)
        case .noLyrics:
            state = .noLyrics
        case .failed(let message):
            state = .failed(message)
        }
    }

    private func showLyrics(_ lines: [LyricLine]) {
        lyricLines = lines
        state = .success
        updateTime(latestPlaybackTime)
    }
}

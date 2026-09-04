import SwiftUI

/// 歌词展示组件：滚动歌词、联网关闭提示和用户确认的在线候选均收敛在同一标签页。
struct MusicLyricsView: View {
    @ObservedObject var lyricsViewModel: LyricsViewModel
    let onRetry: () -> Void
    let onChooseLocalLyrics: () -> Void
    let onRematch: () -> Void
    let onSelectCandidate: (OnlineLyricsCandidate) -> Void
    let onCancelSelection: () -> Void

    private let musicAccentColor = Color(red: 0.16, green: 0.82, blue: 0.50)

    var body: some View {
        Group {
            switch lyricsViewModel.state {
            case .idle:
                messageStateView(icon: "music.note.list", title: "选择歌曲后查看歌词")
            case .loading:
                loadingStateView()
            case .onlineDisabled:
                messageStateView(
                    icon: "network.slash",
                    title: "未找到本地歌词",
                    detail: "联网匹配歌词已在设置中关闭",
                    primaryTitle: "选择本地歌词",
                    primaryAction: onChooseLocalLyrics
                )
            case .noLyrics:
                messageStateView(
                    icon: "music.note.list",
                    title: "暂无匹配歌词",
                    primaryTitle: "选择本地歌词",
                    primaryAction: onChooseLocalLyrics,
                    secondaryTitle: "重新搜索",
                    secondaryAction: onRetry
                )
            case .failed(let message):
                messageStateView(
                    icon: "exclamationmark.circle",
                    title: "获取歌词失败",
                    detail: message,
                    primaryTitle: "重试",
                    primaryAction: onRetry,
                    secondaryTitle: "选择本地歌词",
                    secondaryAction: onChooseLocalLyrics
                )
            case .candidates(let candidates):
                candidateList(candidates)
            case .success:
                lyricsScrollView()
                    .overlay(alignment: .topTrailing) {
                        actionButton(title: "重新匹配", action: onRematch)
                            .padding(.top, 5)
                            .padding(.trailing, 8)
                    }
            }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }

    private func lyricsScrollView() -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    Spacer().frame(height: 46)
                    ForEach(Array(lyricsViewModel.lyricLines.enumerated()), id: \.offset) { index, line in
                        let isActive = index == lyricsViewModel.currentLineIndex

                        if line.text.isEmpty {
                            // 空歌词行折叠为精致的呼吸三点占位符，支持激活联动高亮
                            HStack(spacing: 4) {
                                Circle().fill(isActive ? musicAccentColor : Color.white.opacity(0.18))
                                    .frame(width: 3, height: 3)
                                Circle().fill(isActive ? musicAccentColor : Color.white.opacity(0.18))
                                    .frame(width: 3, height: 3)
                                Circle().fill(isActive ? musicAccentColor : Color.white.opacity(0.18))
                                    .frame(width: 3, height: 3)
                            }
                            .frame(height: 14)
                            .scaleEffect(isActive ? 1.15 : 1.0)
                            .id(index)
                        } else {
                            let isLongLine = line.text.count > 38
                            Text(line.text)
                                .font(.system(size: isActive ? 11 : 9, weight: .regular))
                                .foregroundStyle(isActive ? musicAccentColor : .white.opacity(0.48))
                                .lineLimit(isActive ? nil : (isLongLine ? 1 : nil))
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .id(index)
                        }
                    }
                    Spacer().frame(height: 46)
                }
            }
            .onChange(of: lyricsViewModel.currentLineIndex) { _, newIndex in
                if let newIndex {
                    withAnimation(.spring(response: 0.40, dampingFraction: 0.82)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onAppear {
                if let currentLineIndex = lyricsViewModel.currentLineIndex {
                    proxy.scrollTo(currentLineIndex, anchor: .center)
                }
            }
        }
        .mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
                Rectangle().fill(Color.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 24)
            }
        )
    }

    private func candidateList(_ candidates: [OnlineLyricsCandidate]) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("请选择匹配的在线歌词")
                    .font(.system(size: 9, weight: .regular))
                    .tracking(0.28)
                    .foregroundStyle(.white.opacity(0.36))
                Spacer()
                if lyricsViewModel.canCancelCandidateSelection {
                    actionButton(title: "返回", action: onCancelSelection)
                }
                actionButton(title: "本地 LRC", action: onChooseLocalLyrics)
            }
            .padding(.horizontal, 8)
            .padding(.top, 5)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(candidates) { candidate in
                        Button {
                            onSelectCandidate(candidate)
                        } label: {
                            HStack(spacing: 8) {
                                Text(candidate.title)
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .lineLimit(1)
                                Text(candidate.detailText)
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.40))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Color.white.opacity(0.035))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func loadingStateView() -> some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .colorScheme(.dark)

            Text(lyricsViewModel.isSlowLoading ? "正在获取同步歌词 (网络较慢，请稍候 \(lyricsViewModel.loadingCountdown)s)..." : "正在获取同步歌词...")
                .font(.system(size: 9, weight: .regular))
                .tracking(0.28)
                .foregroundStyle(Color.white.opacity(0.36))

            if lyricsViewModel.isSlowLoading {
                VStack(spacing: 4) {
                    Text("提示：若网络较慢，您也可以导入本地 LRC 歌词")
                        .font(.system(size: 8, weight: .regular))
                        .tracking(0.22)
                        .foregroundStyle(Color.white.opacity(0.22))

                    Button("导入本地歌词", action: onChooseLocalLyrics)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(musicAccentColor)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(musicAccentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: lyricsViewModel.isSlowLoading)
    }

    private func messageStateView(
        icon: String,
        title: String,
        detail: String? = nil,
        primaryTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 5) {
            IslandEmptyHint(
                title: title,
                subtitle: detail,
                icon: icon
            )
            if let primaryTitle, let primaryAction {
                HStack(spacing: 6) {
                    actionButton(title: primaryTitle, action: primaryAction)
                    if let secondaryTitle, let secondaryAction {
                        actionButton(title: secondaryTitle, action: secondaryAction)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 9, weight: .regular))
            .foregroundStyle(musicAccentColor)
            .buttonStyle(.plain)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(musicAccentColor.opacity(0.1))
            .clipShape(Capsule())
    }
}

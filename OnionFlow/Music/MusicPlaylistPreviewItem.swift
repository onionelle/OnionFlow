import AppKit
import SwiftUI

struct PulseDot: View {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.8

    var body: some View {
        ZStack {
            Circle()
                .fill(musicAccentColor)
                .frame(width: 5, height: 5)

            Circle()
                .stroke(musicAccentColor, lineWidth: 1.5)
                .frame(width: 9, height: 9)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        scale = 1.6
                        opacity = 0
                    }
                }
        }
        .frame(width: 10, height: 10)
    }
}

/// 播放动作与删除热区分离，避免点击删除时误触当前行播放。
struct MusicPlaylistPreviewItem: View {
    let url: URL
    let currentIndex: Int?
    let index: Int
    let isFailed: Bool
    let onPlay: (Int) -> Void
    let onRemove: (Int) -> Void

    @State private var isHovered = false
    @State private var isDeleteHovered = false
    @State private var showDeleteConfirmation = false

    private var isCurrentTrack: Bool {
        currentIndex == index
    }

    private var failureColor: Color {
        Color(red: 0.98, green: 0.28, blue: 0.28) // Coral Red
    }

    private var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    private var parsedTrackInfo: (title: String, artist: String?) {
        let filename = url.deletingPathExtension().lastPathComponent
        let separators = [" - ", " – ", " — "]
        for separator in separators {
            let components = filename.components(separatedBy: separator)
            if components.count >= 2 {
                let first = components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let second = components.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                if !first.isEmpty && !second.isEmpty {
                    return (first, second)
                }
            }
        }
        return (filename, nil)
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onPlay(index)
            } label: {
                HStack(alignment: .center, spacing: 6) {
                    Group {
                        if isCurrentTrack {
                            PulseDot()
                                .frame(width: 8)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 9.2, weight: .regular, design: .monospaced))
                                .italic()
                                .foregroundStyle(isFailed ? failureColor.opacity(0.48) : Color.white.opacity(0.30))
                        }
                    }
                    .frame(width: 20, alignment: .trailing)

                    let trackInfo = parsedTrackInfo
                    Text(trackInfo.title)
                        .font(.system(size: 9.8, weight: .regular))
                        .foregroundStyle(isFailed ? failureColor.opacity(0.68) : (isCurrentTrack ? musicAccentColor : Color.white.opacity(0.64)))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let artist = trackInfo.artist {
                        Text("- " + artist)
                            .font(.system(size: 9.8, weight: .regular))
                            .foregroundStyle(isFailed ? failureColor.opacity(0.35) : Color.white.opacity(0.30))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    if isFailed {
                        Text(" [未找到/不支持]")
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(failureColor.opacity(0.75))
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .offset(y: 1.0)
            }
            .buttonStyle(.plain)
            .frame(height: 17)
            .accessibilityLabel("播放 \(title)")

            ZStack {
                Group {
                    Menu {
                        Button("仅从列表中移除") {
                            onRemove(index)
                        }
                        Button("同时移至废纸篓", role: .destructive) {
                            onRemove(index)
                            if url.isFileURL {
                                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                            }
                        }
                    } label: {
                        Color.white.opacity(0.001)
                            .frame(width: 20, height: 17)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .buttonStyle(.plain)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(deleteButtonForeground)
                        .allowsHitTesting(false)
                }
                .opacity(isHovered || isDeleteHovered ? 1 : 0)
                
                if isFailed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(failureColor)
                        .opacity(isHovered || isDeleteHovered ? 0 : 1)
                }
            }
            .frame(width: 20, height: 17)
            .contentShape(Rectangle())
            .accessibilityLabel("删除曲目")
            .onHover { hovering in
                isDeleteHovered = hovering
            }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: isDeleteHovered)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 17, alignment: .center)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isHovered ? Color.white.opacity(0.04) : (isCurrentTrack ? Color.white.opacity(0.015) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }

    private var deleteButtonForeground: Color {
        isDeleteHovered ? Color(red: 0.96, green: 0.38, blue: 0.38).opacity(0.90) : Color.white.opacity(0.38)
    }
}

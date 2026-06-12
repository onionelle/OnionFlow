import AppKit
import SwiftUI

/// 在固定高度内提供稳定可拖动热区，只在松开时将最终进度交给播放器 seek。
struct MusicTimelineSlider: View {
    let progress: Double
    let isEnabled: Bool
    let onScrubbingChanged: (Double) -> Void
    let onScrubbingEnded: (Double) -> Void

    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 10
    @State private var localDragProgress: Double?
    @State private var isHovering = false

    private var safeProgress: Double {
        min(max(localDragProgress ?? progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let filledWidth = width * safeProgress
            // knob 夹在轨道范围内，避免进度位于两端时露出容器边界。
            let knobX = min(max(filledWidth - knobSize / 2, 0), width - knobSize)
            let isDragging = localDragProgress != nil

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(isEnabled ? 0.12 : 0.06))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isEnabled ? 0.90 : 0.30),
                                Color.white.opacity(isEnabled ? 0.70 : 0.20)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: isEnabled ? max(trackHeight, filledWidth) : 0, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Color.black.opacity(isEnabled ? 0.35 : 0), radius: 3, y: 1)
                    .offset(x: knobX)
                    .opacity(isEnabled && (isHovering || isDragging) ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering || isDragging)
            }
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        let nextProgress = min(max(value.location.x / width, 0), 1)
                        localDragProgress = nextProgress
                        onScrubbingChanged(nextProgress)
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        let nextProgress = min(max(value.location.x / width, 0), 1)
                        localDragProgress = nil
                        onScrubbingEnded(nextProgress)
                    }
            )
        }
        .frame(height: 22)
        .opacity(isEnabled ? 1 : 0.62)
    }
}

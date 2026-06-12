import SwiftUI

/// 快捷启动独立呈现 App 槽位；由 expanded 容器组合，不依赖音乐播放业务。
struct QuickLaunchView: View {
    @ObservedObject var viewModel: QuickLaunchViewModel

    var body: some View {
        dropZone
    }

    private var dropZone: some View {
        ZStack {
            GeometryReader { geometry in
                let itemSpacing = launcherItemSpacing(width: geometry.size.width)

                if viewModel.isEmpty && !viewModel.isDropTargeted {
                    emptyState
                        .frame(width: geometry.size.width, height: 36)
                } else {
                    HStack(spacing: itemSpacing) {
                        ForEach(0..<viewModel.slotCount, id: \.self) { index in
                            ZStack {
                                if highlightedSlotIndex == index {
                                    placeholder(isDropTarget: true)
                                } else if viewModel.slots[index] == nil {
                                    placeholder(isDropTarget: false)
                                }

                                if let path = viewModel.slots[index] {
                                    QuickLaunchItemView(path: path, slotIndex: index, viewModel: viewModel)

                                    if highlightedSlotIndex == index && viewModel.draggedSourceSlot != index {
                                        occupiedTargetOutline
                                    }
                                }
                            }
                            .frame(width: 32, height: 32)
                        }
                    }
                    .frame(width: geometry.size.width, height: 36, alignment: .leading)
                }
            }
            .frame(height: 36)
        }
        .frame(height: 36)
        // AppKit 路由使用实际视图热区，避免依赖硬编码坐标。
        .overlay(
            DropFrameReporter { frame in
                viewModel.dropFrame = frame
            }
        )
        .padding(.horizontal, 6)
    }

    private var highlightedSlotIndex: Int? {
        guard let targetIndex = viewModel.dropInsertionIndex else { return nil }
        return min(max(targetIndex, 0), viewModel.slotCount - 1)
    }

    private var emptyState: some View {
        VStack(spacing: 2) {
            Text("拖入常用 App")
                .font(.system(size: 9.6, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.52))
            Text("用于快速打开，也可稍后调整位置")
                .font(.system(size: 8.2, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.30))
        }
    }

    private func placeholder(isDropTarget: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(
                isDropTarget
                    ? Color.white.opacity(0.08)
                    : Color.white.opacity(viewModel.isDropTargeted ? 0.028 : 0.018)
            )
            .frame(width: 32, height: 32)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isDropTarget
                            ? Color.white.opacity(0.32)
                            : Color.white.opacity(viewModel.isDropTargeted ? 0.13 : 0.085),
                        style: StrokeStyle(lineWidth: 0.7, dash: [3, 3])
                    )
            }
            .overlay {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(
                        isDropTarget
                            ? Color.white.opacity(0.62)
                            : Color.white.opacity(0.18)
                    )
            }
            .shadow(
                color: isDropTarget ? Color.white.opacity(0.12) : .clear,
                radius: 4
            )
            .contentShape(Rectangle())
    }

    private var occupiedTargetOutline: some View {
        RoundedRectangle(cornerRadius: 7)
            .stroke(Color.white.opacity(0.32), lineWidth: 1.1)
            .frame(width: 32, height: 32)
            .shadow(color: Color.white.opacity(0.12), radius: 4)
            .allowsHitTesting(false)
    }

    private func launcherItemSpacing(width: CGFloat) -> CGFloat {
        let itemWidth: CGFloat = 32
        let maxItemCount = CGFloat(viewModel.slotCount)
        let availableSpacing = width - itemWidth * maxItemCount
        return max(6, availableSpacing / (maxItemCount - 1))
    }
}

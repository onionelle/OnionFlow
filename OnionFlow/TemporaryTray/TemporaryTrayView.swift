import AppKit
import SwiftUI

/// 临时暂存独立呈现文件引用；由 expanded 容器组合，不依赖音乐播放业务。
struct TemporaryTrayView: View {
    @ObservedObject var viewModel: TemporaryTrayViewModel
    @State private var isTrashHovered = false
    private let dropTargetBottomExtension: CGFloat = 16

    var body: some View {
        dropZone
    }

    private var dropZone: some View {
        ZStack(alignment: .bottom) {

            if viewModel.items.isEmpty {
                VStack(spacing: 2) {
                    Text(viewModel.isDropTargeted ? "松开以加入临时暂存" : "直接拖入为移动，按 Option 为复制")
                        .font(.system(size: 9.6, weight: .regular))
                        .foregroundStyle(Color.white.opacity(viewModel.isDropTargeted ? 0.70 : 0.52))

                    Text("稍后可拖出到 Finder 或其他 App")
                        .font(.system(size: 8.2, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 4) {
                        ForEach(viewModel.items) { item in
                            TemporaryTrayItemView(item: item, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                }
                .frame(height: 60)
                .padding(.bottom, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 108)
        // 遵循 DESIGN.md 规范：非拖拽悬停状态下取消静态外框背景，直接融入黑底；
        // 仅在拖拽悬停时展示符合单色灰度（Monochromatic Gray）主题的半透明背景反馈。
        .background(
            Group {
                if viewModel.isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 108 + dropTargetBottomExtension)
                        .offset(y: dropTargetBottomExtension / 2)
                }
            }
        )
        // 遵循 DESIGN.md 规范：取消静态边框线；
        // 仅在拖拽悬停（isDropTargeted 为真）时，展示极简单色灰度主题的虚线描边作为反馈。
        .overlay(
            Group {
                if viewModel.isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            Color.white.opacity(0.24),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 0, dash: [4, 4], dashPhase: 0)
                        )
                        .frame(height: 108 + dropTargetBottomExtension)
                        .offset(y: dropTargetBottomExtension / 2)
                }
            }
            .allowsHitTesting(false)
        )
        .contentShape(Rectangle())
        .overlay {
            if !viewModel.items.isEmpty {
                TemporaryTrayMarqueeSelectionView(viewModel: viewModel)
            }
        }
        // 遵循 SwiftUI 最佳实践：框选矩形仅在 .overlay 辅助层中按需载入并使用 position 定位。
        // 这可以将其从底部的 ScrollView 及文件卡片的主布局流（ZStack 容器基线）中完全剥离解耦，
        // 从而彻底防止在鼠标按下（mouseDown）启动框选时对 ZStack 底部基线对齐产生影响，根治图标下移或跳动。
        .overlay {
            if let selectionRect = viewModel.selectionRect {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .frame(width: selectionRect.width, height: selectionRect.height)
                    .position(x: selectionRect.midX, y: selectionRect.midY)
                    .allowsHitTesting(false)
            }
        }
        .overlay(
            DropFrameReporter { frame in
                viewModel.dropFrame = frame
            }
        )
        // 顶部横向一体化控制栏：100% 还原用户截图设计
        .overlay(alignment: .top) {
            if !viewModel.items.isEmpty {
                HStack(alignment: .center) {
                    // 左侧胶囊标题/HUD选择计数
                    Group {
                        if let statusText = viewModel.statusText {
                            HStack(spacing: 3.5) {
                                Image(systemName: viewModel.statusIsSelectionWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 7.2))
                                Text(statusText)
                                    .font(.system(size: 8))
                            }
                            .foregroundStyle(viewModel.statusIsSelectionWarning ? Color(red: 0.98, green: 0.42, blue: 0.42) : Color.white.opacity(0.85))
                            .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        } else if !viewModel.selectedItemIDs.isEmpty {
                            Text("已选 \(viewModel.selectedItemIDs.count) 项")
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                                .transition(.opacity.combined(with: .scale(scale: 0.88)))
                        } else {
                            HStack(spacing: 4.5) {
                                Image(systemName: "tray.fill")
                                    .font(.system(size: 8))
                                Text("临时暂存")
                                    .font(.system(size: 8.5))
                            }
                            .foregroundStyle(Color.white.opacity(0.85))
                            .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.24, dampingFraction: 0.82), value: viewModel.statusText)
                    .animation(.spring(response: 0.24, dampingFraction: 0.82), value: viewModel.selectedItemIDs.count)
                    .padding(.leading, 7)

                    Spacer()

                    // 右侧垃圾桶清空按钮
                    Button {
                        viewModel.clearItems()
                    } label: {
                        Image(systemName: isTrashHovered ? "trash.fill" : "trash")
                            .font(.system(size: 9.6, weight: .regular))
                            .foregroundStyle(isTrashHovered ? Color(red: 0.98, green: 0.35, blue: 0.35) : Color.white.opacity(0.48))
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 7)
                    .onHover { hovering in
                        isTrashHovered = hovering
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .onAppear {
            viewModel.refreshAvailability()
        }
    }
}

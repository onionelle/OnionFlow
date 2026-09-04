import AppKit
import SwiftUI

struct TemporaryTrayItemView: View {
    let item: TemporaryTrayItem
    @ObservedObject var viewModel: TemporaryTrayViewModel
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    Image(nsImage: viewModel.image(for: item))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .opacity(item.isAvailable ? 1 : 0.42)

                    if !item.isAvailable {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.46))
                            .background(Circle().fill(Color.black.opacity(0.78)))
                    } else {
                        modeBadge
                    }
                }

                Text(item.displayName)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(item.isAvailable ? 0.62 : 0.34))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 52)
            }
            .frame(width: 58, height: 48)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        viewModel.isSelected(item.id)
                            ? Color.white.opacity(0.08)
                            : (isHovered ? Color.white.opacity(0.05) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        viewModel.isSelected(item.id)
                            ? Color.white.opacity(0.32)
                            : Color.clear,
                        lineWidth: 1.2
                    )
            )
            .overlay(alignment: .topLeading) {
                selectedBadge
                    .scaleEffect(viewModel.isSelected(item.id) ? 1.0 : 0.01)
                    .opacity(viewModel.isSelected(item.id) ? 1.0 : 0.0)
                    .allowsHitTesting(viewModel.isSelected(item.id))
            }
            .overlay {
                if item.isAvailable {
                    TemporaryTrayDragSource(
                        item: item,
                        viewModel: viewModel,
                        previewImage: viewModel.image(for: item)
                    )
                }
            }
            .help("\(item.displayName)\n\(item.transferMode.helpText)\n\(item.url.path)")

            Button {
                viewModel.removeItem(id: item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .regular))
                    .foregroundStyle(isDeleteHovered ? Color(red: 0.98, green: 0.42, blue: 0.42) : Color.white.opacity(0.28))
                    .frame(width: 14, height: 14)
                    .background(
                        Circle()
                            .fill(isDeleteHovered ? Color(red: 0.98, green: 0.35, blue: 0.35).opacity(0.16) : Color.black.opacity(0.44))
                    )
            }
            .buttonStyle(.plain)
            .help("从临时暂存移除")
            .opacity(isDeleteHovered ? 1 : 0.36)
            .onHover { hovering in
                isDeleteHovered = hovering
            }
            .zIndex(1)
        }
        .frame(width: 58, height: 48)
        .opacity(viewModel.draggedItemIDs.contains(item.id) ? 0.35 : 1)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .onAppear {
            viewModel.loadPreview(for: item)
        }
        .overlay(
            DropFrameReporter { frame in
                let trayFrame = viewModel.dropFrame
                guard !trayFrame.isEmpty else { return }
                viewModel.setItemFrame(
                    id: item.id,
                    frame: CGRect(
                        x: frame.minX - trayFrame.minX,
                        y: frame.minY - trayFrame.minY,
                        width: frame.width,
                        height: frame.height
                    )
                )
            }
        )
    }

    private var modeBadge: some View {
        HStack(spacing: 1) {
            Image(systemName: item.transferMode.systemImage)
                .font(.system(size: 6, weight: .regular))
            Text(item.transferMode.label)
                .font(.system(size: 6, weight: .regular))
        }
        .foregroundStyle(Color.black.opacity(0.85))
        .padding(.horizontal, 3)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(modeBadgeBgColor)
        )
        .offset(x: 3, y: 2)
    }

    private var modeBadgeBgColor: Color {
        modeBadgeColor.opacity(0.88)
    }

    private var modeBadgeColor: Color {
        switch item.transferMode {
        case .move:
            return Color(red: 0.92, green: 0.32, blue: 0.32)
        case .copy:
            return Color(red: 0.32, green: 0.78, blue: 0.52)
        }
    }

    private var selectedBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 6, weight: .regular))
            .foregroundStyle(Color.black.opacity(0.85))
            .frame(width: 12, height: 12)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
            )
            .shadow(color: Color.white.opacity(0.12), radius: 2)
            .offset(x: -2, y: -2)
    }
}

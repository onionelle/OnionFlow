import AppKit
import SwiftUI

struct QuickLaunchItemView: View {
    let path: String
    let slotIndex: Int
    @ObservedObject var viewModel: QuickLaunchViewModel
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: viewModel.icon(for: path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 38, height: 38)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
                .scaleEffect(isHovered ? 1.04 : 1)
                .offset(y: isHovered ? -2 : 0)
                .opacity(viewModel.draggedSourceSlot == slotIndex ? 0.28 : (isHovered ? 1.0 : 0.48))
                .grayscale(isHovered ? 0 : 0.35)
                .help(viewModel.displayName(for: path))
                .overlay {
                    QuickLaunchDragSource(
                        path: path,
                        slotIndex: slotIndex,
                        icon: viewModel.icon(for: path),
                        viewModel: viewModel
                    )
                }

            if isHovered && viewModel.draggedSourceSlot == nil {
                Button {
                    viewModel.removeApp(path: path)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isDeleteHovered ? Color(red: 0.95, green: 0.28, blue: 0.28).opacity(0.72) : Color.black.opacity(0.65))
                            .frame(width: 14, height: 14)
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .regular))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .onHover { hovering in
                    isDeleteHovered = hovering
                }
            }
        }
        .frame(width: 32, height: 32)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .onChange(of: viewModel.draggedSourceSlot) { _, sourceSlot in
            if sourceSlot != nil {
                isHovered = false
                isDeleteHovered = false
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isHovered)
    }
}

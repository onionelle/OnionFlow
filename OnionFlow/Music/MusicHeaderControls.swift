import AppKit
import SwiftUI

struct MusicMiniTrashButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: isHovered ? "trash.fill" : "trash")
                    .font(.system(size: 8, weight: .regular))
                Text("Clear")
                    .font(.system(size: 9, weight: .regular))
            }
            .foregroundStyle(isHovered ? Color(red: 0.98, green: 0.35, blue: 0.35) : Color.white.opacity(0.48))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isHovered ? Color.black.opacity(0.24) : Color.clear)
            )
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

struct MusicMiniAddButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .regular))
                Text("Add")
                    .font(.system(size: 9, weight: .regular))
            }
            .foregroundStyle(isHovered ? Color(red: 0.16, green: 0.82, blue: 0.50) : Color.white.opacity(0.48))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isHovered ? Color.black.opacity(0.24) : Color.clear)
            )
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

struct MusicMiniSearchButton: View {
    let action: () -> Void
    @State private var isHovered = false
    let isActive: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 8, weight: .regular))
                Text("Search")
                    .font(.system(size: 9, weight: .regular))
            }
            .foregroundStyle((isHovered || isActive) ? Color(red: 0.40, green: 0.60, blue: 1.0) : Color.white.opacity(0.48))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill((isHovered || isActive) ? Color.black.opacity(0.24) : Color.clear)
            )
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

struct MusicButtonHoverEffect: ViewModifier {
    let fill: Color
    @State private var isHovered = false

    init(fill: Color = Color.white.opacity(0.14)) {
        self.fill = fill
    }

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(isHovered ? fill : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                isHovered = false
            }
    }
}

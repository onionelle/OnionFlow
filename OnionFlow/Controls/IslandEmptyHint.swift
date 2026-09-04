import SwiftUI

/// 展开态空提示：播放列表、快捷启动、临时暂存共用。
struct IslandEmptyHint: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var isHighlighted: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(isHighlighted ? 0.32 : 0.20))
                    .padding(.bottom, 2)
            }

            Text(title)
                .font(IslandTypography.hint)
                .foregroundStyle(Color.white.opacity(isHighlighted ? 0.50 : 0.38))

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(IslandTypography.micro)
                    .foregroundStyle(Color.white.opacity(0.24))
            }
        }
        .multilineTextAlignment(.center)
    }
}

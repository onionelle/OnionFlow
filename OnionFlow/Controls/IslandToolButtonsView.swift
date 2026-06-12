import SwiftUI

// island 右侧工具组。设置和退出通过 IslandViewModel 回调回到 App 入口层。
struct IslandToolButtonsView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    private let spacing: CGFloat = 5
    @State private var isHoveringVolume = false
    
    private var volumeIcon: String {
        if musicViewModel.isMuted || musicViewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if musicViewModel.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if musicViewModel.volume < 0.67 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    private var volumeTitle: String {
        if musicViewModel.isMuted {
            return "取消静音"
        } else {
            return "音量: \(Int(musicViewModel.volume * 100))%"
        }
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            // 声音调节复合区域：悬停时平滑展出微型音量条
            HStack(spacing: 4) {
                if isHoveringVolume {
                    VolumeSlider(volume: Binding(
                        get: { musicViewModel.volume },
                        set: { musicViewModel.volume = $0 }
                    ))
                    .frame(width: 60)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                IslandToolButton(
                    systemName: volumeIcon,
                    title: volumeTitle,
                    isActive: musicViewModel.isMuted
                ) {
                    musicViewModel.toggleMute()
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isHoveringVolume = hovering
                }
            }
            
            IslandToolButton(
                systemName: "gearshape.fill",
                title: viewModel.isSettingsPresented ? "关闭设置" : "打开设置"
            ) {
                viewModel.openSettings()
            }
            IslandToolButton(
                systemName: "power",
                title: "退出 Onion"
            ) {
                viewModel.requestQuit()
            }
        }
        .frame(height: viewModel.collapsedHeight)
    }
}

// 专为顶部工具栏定制的超微型音量条
private struct VolumeSlider: View {
    @Binding var volume: Double
    @State private var localDragVolume: Double? = nil
    @State private var isHoveringTrack = false
    
    private var activeVolume: Double {
        localDragVolume ?? volume
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let filledWidth = width * activeVolume
            
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)
                
                // 激活填充：荧光青绿到天蓝渐变配色
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.88, blue: 0.70),
                                Color(red: 0.18, green: 0.68, blue: 0.90)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, filledWidth), height: 4)
                
                // 拖拽滑块（仅在 Hover 或 Dragging 时显式露出，减少常态视觉噪音）
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.black.opacity(0.4), radius: 2)
                    .offset(x: min(max(filledWidth - 4.0, 0), width - 8))
                    .opacity(isHoveringTrack || localDragVolume != nil ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHoveringTrack || localDragVolume != nil)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHoveringTrack = hovering
                if hovering {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let locationX = value.location.x
                        let calculatedVolume = min(max(Double(locationX / width), 0.0), 1.0)
                        localDragVolume = calculatedVolume
                        volume = calculatedVolume
                    }
                    .onEnded { _ in
                        localDragVolume = nil
                    }
            )
        }
        .frame(height: 22)
    }
}

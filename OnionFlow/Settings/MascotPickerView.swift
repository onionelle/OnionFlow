import SwiftUI

/// 无边框设置窗口只在自绘标题栏提供拖动能力，避免内容区操作误移动窗口。
private struct TitleBarDragView: NSViewRepresentable {
    final class DragNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> DragNSView {
        let view = DragNSView()
        return view
    }

    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

private struct SettingsHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Mascot 设置面板，集中管理角色、氛围背景与扩展功能开关。
struct MascotPickerView: View {
    /// 关闭回调
    let onClose: () -> Void
    let onHeightChange: (CGFloat) -> Void

    @AppStorage("mascotKind") private var selectedKindRawValue = "pixelPuppy"
    @AppStorage("backgroundNebulaEnabled") private var backgroundNebulaEnabled = false
    @AppStorage("backgroundParticlesEnabled") private var backgroundParticlesEnabled = false
    @AppStorage("backgroundNebulaTheme") private var backgroundNebulaThemeRawValue = "charcoal"
    @AppStorage("nebulaThemeEnabled") private var nebulaThemeEnabled = true
    @AppStorage("fetchOnlineLyrics") private var fetchOnlineLyrics = true
    @AppStorage("onlineLyricsEnabled") private var onlineLyricsEnabled = false
    @AppStorage("remoteControlEnabled") private var remoteControlEnabled = true
    @AppStorage("autoListenEnabled") private var autoListenEnabled = false
    @AppStorage("autoListenPath") private var autoListenPath = "~/Music"
    @AppStorage("spectrumStyle") private var spectrumStyle = "columns"
    @AppStorage("NeteaseCookie") private var neteaseCookie = ""
    @AppStorage("PlaybackTimeoutSeconds") private var playbackTimeoutSeconds = 20.0
    @AppStorage("diagnosticLoggingEnabled") private var diagnosticLoggingEnabled = true

    @State private var hoveredKind: MascotKind? = nil
    @State private var hoveredStyle: SpectrumStyle? = nil
    @State private var editingListenPath = ""
    @State private var isListenPathValid = true

    private var selectedNebulaTheme: NebulaTheme {
        NebulaTheme(rawValue: backgroundNebulaThemeRawValue) ?? .charcoal
    }

    private let mascotColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // 无边框 NSPanel 没有系统标题栏，这一行是唯一的窗口拖动热区。
                HStack(alignment: .top, spacing: 10) {
                    ZStack(alignment: .leading) {
                        TitleBarDragView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Onion 设置")
                                .font(IslandTypography.display)
                                .foregroundStyle(.white)

                            Text("个性化角色、外观与播放器功能")
                                .font(IslandTypography.body)
                                            .foregroundStyle(.white.opacity(0.36))
                        }
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())

                    // 独立设计的关闭按钮
                    CloseButton(action: onClose)
                }
                .padding(.bottom, 8)

                // 角色选择标题
                Text("常驻角色")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    .padding(.leading, 2)

                // 角色数量变化后让网格和外层 NSPanel 跟随内容自然收缩。
                LazyVGrid(columns: mascotColumns, spacing: 10) {
                    ForEach(MascotKind.allCases, id: \.rawValue) { kind in
                        mascotCard(for: kind)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

                // 频谱选择标题
                Text("频谱视觉风格")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    .padding(.leading, 2)

                // 4列紧凑网格（1行频谱风格）
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(SpectrumStyle.allCases) { style in
                        SpectrumStyleCard(
                            style: style,
                            spectrumStyle: $spectrumStyle,
                            hoveredStyle: $hoveredStyle
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

                // 精致的分割线
                LinearGradient(
                    colors: [.clear, .white.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.6)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("偏好设置")
                        .font(IslandTypography.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.bottom, 4)
                        .padding(.leading, 2)

                    VStack(spacing: 0) {
                        nebulaThemeSection

                        Divider()
                            .background(Color.white.opacity(0.08))

                        onlineLyricsSection

                        Divider()
                            .background(Color.white.opacity(0.08))

                        remoteControlSection
                        
                        Divider()
                            .background(Color.white.opacity(0.08))

                        autoListenSection
                        
                        Divider()
                            .background(Color.white.opacity(0.08))

                        neteaseCookieSection

                        Divider()
                            .background(Color.white.opacity(0.08))

                        playbackTimeoutSection
                    }
                    .padding(.horizontal, 12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("性能与效果")
                        .font(IslandTypography.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.bottom, 4)
                        .padding(.leading, 2)

                    VStack(spacing: 0) {
                        dynamicParticlesSection

                        Divider()
                            .background(Color.white.opacity(0.08))

                        diagnosticLoggingSection
                    }
                    .padding(.horizontal, 12)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24) // 优化边距安全区，仍然非常宽敞
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(settingsBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                .allowsHitTesting(false)
        )
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        // 透明内容空白也应由设置页接收，避免点击落到下方 island。
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {}
        .clipShape(RoundedRectangle(cornerRadius: 16)) // 全局圆角裁剪，四角完全一致
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: SettingsHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SettingsHeightPreferenceKey.self) { height in
            onHeightChange(height)
        }
        .onHover { hovering in
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .onAppear {
            if MascotKind(rawValue: selectedKindRawValue) == nil {
                selectedKindRawValue = MascotKind.pixelPuppy.rawValue
            }
            if playbackTimeoutSeconds < 10.0 {
                playbackTimeoutSeconds = 10.0
            } else if playbackTimeoutSeconds > 120.0 {
                playbackTimeoutSeconds = 120.0
            }
        }
    }

    private var settingsBackground: some View {
        ZStack {
            if backgroundNebulaEnabled {
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedNebulaTheme.baseBackground)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.06))
            }

            if backgroundNebulaEnabled {
                ZStack {
                    Circle()
                        .fill(selectedNebulaTheme.color1)
                        .frame(width: 260, height: 260)
                        .blur(radius: 50)
                        .offset(x: -100, y: 80)

                    Circle()
                        .fill(selectedNebulaTheme.color2)
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .offset(x: 100, y: -80)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .drawingGroup()
        .allowsHitTesting(false)
    }

    // ==========================================
    // 偏好设置子视图分段 - 提升 Swift 编译性能
    // ==========================================

    @ViewBuilder
    private var nebulaThemeSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.16, green: 0.82, blue: 0.50).opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "paintpalette")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color(red: 0.16, green: 0.82, blue: 0.50))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("氛围背景")
                    .font(IslandTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                Text("展开时展示渐变氛围背景")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $backgroundNebulaEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.16, green: 0.82, blue: 0.50)))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 8)

        if backgroundNebulaEnabled {
            HStack(spacing: 8) {
                ForEach(NebulaTheme.allCases) { theme in
                    ThemeSelectorButton(
                        theme: theme,
                        isSelected: backgroundNebulaThemeRawValue == theme.rawValue,
                        action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                backgroundNebulaThemeRawValue = theme.rawValue
                            }
                        }
                    )
                }
            }
            .padding(.leading, 40)
            .padding(.bottom, 10)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var onlineLyricsSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.18, green: 0.68, blue: 0.90).opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "network")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color(red: 0.18, green: 0.68, blue: 0.90))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("联网匹配歌词")
                    .font(IslandTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                Text("无本地歌词时允许在线搜索")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer()

            Toggle("", isOn: $onlineLyricsEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.18, green: 0.68, blue: 0.90)))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var remoteControlSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.95, green: 0.60, blue: 0.20).opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "candybarphone")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color(red: 0.95, green: 0.60, blue: 0.20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("网页遥控服务端")
                    .font(IslandTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                Text("开启后可通过浏览器远程控制播放器")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer()

            Toggle("", isOn: $remoteControlEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.95, green: 0.60, blue: 0.20)))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var autoListenSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.90, green: 0.35, blue: 0.50).opacity(0.1))
                        .frame(width: 28, height: 28)

                    Image(systemName: "folder.badge.plus")
                        .font(IslandTypography.body)
                        .foregroundStyle(Color(red: 0.90, green: 0.35, blue: 0.50))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("自动监听目录")
                        .font(IslandTypography.body)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("后台自动发现并导入新歌曲")
                        .font(IslandTypography.caption)
                            .foregroundStyle(.white.opacity(0.42))
                }

                Spacer()

                Toggle("", isOn: $autoListenEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.90, green: 0.35, blue: 0.50)))
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            .padding(.vertical, 6)

            if autoListenEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("监听路径 (如 ~/Music)", text: $editingListenPath)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(IslandTypography.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.white.opacity(0.03))
                        .cornerRadius(3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isListenPathValid ? Color.white.opacity(0.08) : Color.red.opacity(0.6), lineWidth: 0.5)
                        )
                        .onChange(of: editingListenPath) { newValue in
                            validateAndSavePath(newValue)
                        }
                    
                    if isListenPathValid {
                        Text("✓ 路径有效，已自动保存")
                            .font(IslandTypography.caption)
                            .foregroundStyle(Color(red: 0.16, green: 0.82, blue: 0.50))
                    } else {
                        Text("✗ 目录不存在或不是文件夹")
                            .font(IslandTypography.caption)
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                }
                .padding(.bottom, 6)
                .padding(.leading, 40)
            }
        }
        .onAppear {
            editingListenPath = autoListenPath
            validateAndSavePath(editingListenPath, save: false)
        }
    }

    private func validateAndSavePath(_ path: String, save: Bool = true) {
        let absolutePath = NSString(string: path).expandingTildeInPath
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: absolutePath, isDirectory: &isDir), isDir.boolValue {
            isListenPathValid = true
            if save && autoListenPath != path {
                autoListenPath = path
            }
        } else {
            isListenPathValid = false
        }
    }

    // ==========================================
    // 性能与效果子视图分段 - 提升 Swift 编译性能
    // ==========================================

    @ViewBuilder
    private var neteaseCookieSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.90, green: 0.20, blue: 0.20).opacity(0.1))
                        .frame(width: 28, height: 28)

                    Image(systemName: "music.note")
                        .font(IslandTypography.body)
                        .foregroundStyle(Color(red: 0.90, green: 0.20, blue: 0.20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("网易云 Cookie")
                        .font(IslandTypography.body)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("用于获取无损音质与私人推荐，留空则仅获取公开数据")
                        .font(IslandTypography.caption)
                            .foregroundStyle(.white.opacity(0.42))
                }

                Spacer()
            }
            .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 4) {
                TextEditor(text: $neteaseCookie)
                    .font(IslandTypography.mono)
                    .foregroundStyle(.white.opacity(0.7))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(height: 60)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .padding(.bottom, 6)
            .padding(.leading, 40)
        }
    }

    // ==========================================
    // 性能与效果子视图分段 - 提升 Swift 编译性能
    // ==========================================

    @ViewBuilder
    private var dynamicParticlesSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.16, green: 0.82, blue: 0.50).opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "sparkles")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color(red: 0.16, green: 0.82, blue: 0.50))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("动态粒子")
                    .font(IslandTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                Text("展开时展示漂浮粒子，关闭可降低 GPU 占用")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $backgroundParticlesEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.16, green: 0.82, blue: 0.50)))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var diagnosticLoggingSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.62, green: 0.70, blue: 0.82).opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "doc.text")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color(red: 0.62, green: 0.70, blue: 0.82))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("诊断日志")
                    .font(IslandTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                Text("记录播放、权限和崩溃等到本地文件，关闭后不再写入")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $diagnosticLoggingEnabled)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.62, green: 0.70, blue: 0.82)))
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .padding(.vertical, 6)
    }

    // ==========================================
    // 角色与辅助颜色
    // ==========================================

    /// 精巧紧凑的单卡组件 (宽 82, High 66)
    @ViewBuilder
    private func mascotCard(for kind: MascotKind) -> some View {
        let selected = selectedKindRawValue == kind.rawValue
        let isHovered = hoveredKind == kind
        let shouldAnimatePreview = isHovered
        let themeColor = glowColor(for: kind)

        VStack(spacing: 3) {
            // 头像微盒背景 (Mascot 大小优化至超精细 32pt 规格)
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 32, height: 32)

                MascotView(kind: kind, state: .idle, size: 28, isStatic: !shouldAnimatePreview)
                    .frame(width: 26, height: 26)
            }
            .padding(.top, 5)

            Text(kind.displayName)
                .font(IslandTypography.body)
                .foregroundStyle(selected ? themeColor : .white.opacity(0.80))
                .padding(.bottom, 4)
        }
        .frame(height: 66)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? themeColor.opacity(0.08) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    selected ? themeColor.opacity(0.85) : (isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08)),
                    lineWidth: selected ? 1.2 : 0.6
                )
        )
        // 选中时亮起对应 Mascot 专属色彩的散射呼吸背光
        .shadow(color: selected ? themeColor.opacity(0.24) : Color.clear, radius: 8, y: 2)
        // 物理悬浮弹跳
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .offset(y: isHovered ? -2.5 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            selectedKindRawValue = kind.rawValue
        }
        .onHover { hovering in
            hoveredKind = hovering ? kind : nil
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }

    /// Mascot 对应主色调，用于卡片边框、高亮名称 and 独特的散射阴影
    private func glowColor(for kind: MascotKind) -> Color {
        switch kind {
        case .ghost:
            return Color(red: 0.68, green: 0.45, blue: 0.90) // 幽暗魔力紫
        case .pixelGhost:
            return Color(red: 0.55, green: 0.82, blue: 1.0) // 冰蓝像素光
        case .pixelCrab:
            return Color(red: 0.98, green: 0.36, blue: 0.26) // 复古红橘色
        case .pixelPuppy:
            return Color(red: 0.90, green: 0.65, blue: 0.28) // 太妃金黄色
        }
    }

    @ViewBuilder
    private var playbackTimeoutSection: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: "timer")
                    .font(IslandTypography.body)
                    .foregroundStyle(Color.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("网络连接超时")
                    .font(IslandTypography.body)
                    .foregroundStyle(.white.opacity(0.85))

                Text("在线播放及缓冲的等待时间限制")
                    .font(IslandTypography.caption)
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer(minLength: 8)

            CompactSettingsSlider(
                value: $playbackTimeoutSeconds,
                range: 10...120,
                step: 1,
                tint: Color.orange
            )

            Text("\(Int(playbackTimeoutSeconds))秒")
                .font(IslandTypography.mono)
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

}

/// 设置行内的细滑条，避开系统 Slider 过大圆钮破坏单行节奏。
private struct CompactSettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color

    private let thumbSize: CGFloat = 10
    private let trackHeight: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let travel = max(width - thumbSize, 0)
            let x = travel * min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: trackHeight)
                Capsule()
                    .fill(tint)
                    .frame(width: x + thumbSize / 2, height: trackHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.28), radius: 1, y: 0.5)
                    .offset(x: x)
            }
            .frame(width: width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        update(at: drag.location.x, width: width)
                    }
            )
        }
        .frame(width: 76, height: 22)
    }

    private func update(at locationX: CGFloat, width: CGFloat) {
        let travel = max(width - thumbSize, 1)
        let clamped = min(max(locationX - thumbSize / 2, 0), travel) / travel
        let raw = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
        let stepped = (raw / step).rounded() * step
        value = min(max(stepped, range.lowerBound), range.upperBound)
    }
}

/// 频谱样式单卡组件 - 独立 Struct 完美突破 Swift 复杂布局的类型检测瓶颈
struct SpectrumStyleCard: View {
    let style: SpectrumStyle
    @Binding var spectrumStyle: String
    @Binding var hoveredStyle: SpectrumStyle?

    var body: some View {
        let selected = spectrumStyle == style.rawValue
        let isHovered = hoveredStyle == style
        let shouldAnimatePreview = isHovered
        let themeColor = Color(red: 0.16, green: 0.82, blue: 0.50) // 频谱专属翡翠绿

        let cardContent = VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 48, height: 24)

                SpectrumPreviewView(style: style, isAnimated: shouldAnimatePreview)
                    .allowsHitTesting(false)
            }
            .padding(.top, 5)

            Text(style.displayName)
                .font(IslandTypography.body)
                .foregroundStyle(selected ? themeColor : .white.opacity(0.80))
                .padding(.bottom, 4)
        }

        let cardBackground = RoundedRectangle(cornerRadius: 8)
            .fill(selected ? themeColor.opacity(0.08) : Color.white.opacity(0.02))

        let cardBorder = RoundedRectangle(cornerRadius: 8)
            .stroke(
                selected ? themeColor.opacity(0.85) : (isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08)),
                lineWidth: selected ? 1.2 : 0.6
            )

        return cardContent
            .frame(height: 66)
            .frame(maxWidth: .infinity)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: selected ? themeColor.opacity(0.24) : Color.clear, radius: 8, y: 2)
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .offset(y: isHovered ? -2.5 : 0)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.76)) {
                    spectrumStyle = style.rawValue
                }
            }
            .onHover { hovering in
                hoveredStyle = hovering ? style : nil
                if hovering {
                    NSCursor.arrow.set()
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
            .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

/// 频谱实时动能物理预览器 - 彻底释放编译压力，防 typecheck 超时
struct SpectrumPreviewView: View {
    let style: SpectrumStyle
    let isAnimated: Bool

    var body: some View {
        Group {
            if isAnimated {
                TimelineView(.periodic(from: Date(), by: 1.0 / 12.0)) { timeline in
                    previewCanvas(for: style, time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                previewCanvas(for: style, time: 0)
            }
        }
        .frame(width: 30, height: 14)
    }

    private func previewCanvas(for style: SpectrumStyle, time: TimeInterval) -> some View {
        Canvas { context, size in
            let baseColor = Color(red: 0.16, green: 0.82, blue: 0.50)
            let highlightColor = Color(red: 0.55, green: 1.0, blue: 0.78)
            let centerY = size.height / 2.0

            // 使用数学公式为预览界面生成动能跳跃频率信号
            let bass = CGFloat(0.4 + 0.6 * pow(max(0.0, sin(time * .pi * 3.0)), 2.0))
            let mid = CGFloat(0.3 + 0.7 * abs(sin(time * .pi * 4.8 + 1.0)))
            let treble = CGFloat(0.2 + 0.8 * abs(cos(time * .pi * 8.5)))
            let lowMid = CGFloat(0.3 + 0.7 * pow(max(0.0, cos(time * .pi * 3.6)), 2.0))
            let highMid = CGFloat(0.4 + 0.6 * abs(sin(time * .pi * 6.5)))

            switch style {
            case .columns:
                let baseline = size.height - 1.5
                let xPositions: [CGFloat] = [3, 9, 15, 21, 27]
                let factors: [CGFloat] = [bass, lowMid, mid, highMid, treble]

                var glowContext = context
                glowContext.addFilter(.shadow(color: baseColor.opacity(0.50), radius: 2.0, x: 0, y: 0))

                for i in 0..<5 {
                    let x = xPositions[i]
                    let maxJumpHeight = size.height - 3.5
                    let barHeight = max(1.5, factors[i] * maxJumpHeight)

                    var barPath = Path()
                    barPath.move(to: CGPoint(x: x, y: baseline))
                    barPath.addLine(to: CGPoint(x: x, y: baseline - barHeight))

                    glowContext.stroke(
                        barPath,
                        with: .color(baseColor.opacity(0.78)),
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                    )

                    context.stroke(
                        barPath,
                        with: .color(highlightColor),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                }

            case .wave:
                var glowContext = context
                glowContext.addFilter(.shadow(color: baseColor.opacity(0.60), radius: 2.5, x: 0, y: 0))

                var path = Path()
                let step: CGFloat = 1.0
                var started = false

                for x in stride(from: 2.0, through: 28.0, by: step) {
                    let normX = (x - 2.0) / 26.0

                    let amp1 = bass * 4.0 * sin(normX * .pi * 2.0 - time * 6.0)
                    let amp2 = mid * 2.5 * sin(normX * .pi * 4.5 + time * 9.0)
                    let amp3 = treble * 1.2 * sin(normX * .pi * 8.0 - time * 16.0)

                    let y = centerY + amp1 + amp2 + amp3

                    if !started {
                        path.move(to: CGPoint(x: x, y: y))
                        started = true
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                glowContext.stroke(
                    path,
                    with: .color(baseColor.opacity(0.80)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )

                context.stroke(
                    path,
                    with: .color(highlightColor),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                )

            case .breathing:
                let baseW: CGFloat = 11.0
                let baseH: CGFloat = 5.5

                let w = baseW * (1.0 + bass * 0.7)
                let h = baseH * (1.0 + mid * 0.4)

                let rect = CGRect(x: size.width/2.0 - w/2.0, y: centerY - h/2.0, width: w, height: h)

                var glowContext = context
                let glowRadius = 3.0 + bass * 3.5
                glowContext.addFilter(.shadow(color: baseColor.opacity(0.45 + bass * 0.45), radius: glowRadius, x: 0, y: 0))

                let haloRect = rect.insetBy(dx: -1.5 - bass * 2.0, dy: -1.0 - bass * 1.0)
                glowContext.fill(
                    Path(roundedRect: haloRect, cornerRadius: haloRect.height / 2.0),
                    with: .color(baseColor.opacity(0.24 - bass * 0.10))
                )

                context.fill(
                    Path(roundedRect: rect, cornerRadius: rect.height / 2.0),
                    with: .color(highlightColor)
                )

            case .pulse:
                let xPositions: [CGFloat] = [3, 9, 15, 21, 27]
                let factors: [CGFloat] = [bass, lowMid, mid, highMid, treble]

                var glowContext = context
                glowContext.addFilter(.shadow(color: baseColor.opacity(0.55), radius: 2.0, x: 0, y: 0))

                for i in 0..<5 {
                    let x = xPositions[i]
                    let maxHalfHeight = (size.height - 3.5) / 2.0
                    let halfHeight = max(1.0, factors[i] * maxHalfHeight)

                    var barPath = Path()
                    barPath.move(to: CGPoint(x: x, y: centerY - halfHeight))
                    barPath.addLine(to: CGPoint(x: x, y: centerY + halfHeight))

                    glowContext.stroke(
                        barPath,
                        with: .color(baseColor.opacity(0.78)),
                        style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                    )

                    context.stroke(
                        barPath,
                        with: .color(highlightColor),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                }
            }
        }
    }
}


// 独立高光关闭按钮
private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color(red: 0.95, green: 0.28, blue: 0.28) : Color.white.opacity(0.08))
                    .frame(width: 20, height: 20)

                Image(systemName: "xmark")
                    .font(IslandTypography.caption)
                    .foregroundStyle(isHovered ? .white : Color.white.opacity(0.40))
            }
        }
        .buttonStyle(.plain)
        .help("关闭面板")
        .accessibilityLabel("关闭面板")
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

// 独立设计的星云渐变背景选择按钮，支持高保真悬浮 (Hover) 和选中动画反馈
private struct ThemeSelectorButton: View {
    let theme: NebulaTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: theme.previewGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .stroke(
                                Color.white.opacity(isSelected ? 0.95 : (isHovered ? 0.6 : 0.20)),
                                lineWidth: isSelected ? 1.5 : 0.8
                            )
                    )
                    .shadow(
                        color: theme.previewGradientColors[0].opacity(isSelected ? 0.6 : (isHovered ? 0.4 : 0)),
                        radius: isSelected ? 3 : (isHovered ? 2 : 0)
                    )
            }
            .scaleEffect(isHovered ? 1.15 : (isSelected ? 1.08 : 1.0))
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isHovered)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isSelected)
        }
        .buttonStyle(.plain)
        .help(theme.name)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

# ARCHITECTURE

## 目标

本文档用于说明 Onion Flow（简称 Onion）当前 macOS MVP 迭代阶段的基本架构、主要职责划分，以及后续扩展方向。

当前项目采用：

- `SwiftUI` 负责主要界面
- `AppKit` 负责顶部 floating panel 管理
- `ObservableObject` 负责基础状态驱动
- `AVPlayer` 负责本地文件和在线音频 URL 播放
- `URLSession` 负责歌词检索和网易云相关网络请求
- `Network` 负责局域网网页遥控器的 HTTP 监听

## 架构概览

当前结构可以理解为 5 层：

1. 应用入口层
2. 窗口控制层
3. 状态管理层
4. 视图渲染层
5. 局域网遥控层

## 1. 应用入口层

文件：

- `OnionFlowApp.swift`

职责：

- 启动应用
- 初始化 `AppDelegate`
- 创建 `IslandViewModel`
- 创建 `MusicPlayerViewModel`
- 创建 `QuickLaunchViewModel`
- 创建 `TemporaryTrayViewModel`
- 创建并启动 `RemoteControlServer`
- 挂载 `MenuBarExtra`
- 提供 menu bar app 入口

当前实现思路：

- 使用 `@NSApplicationDelegateAdaptor` 接入 `AppDelegate`
- 在 `applicationDidFinishLaunching` 中创建顶部 island panel
- 在 `applicationDidFinishLaunching` 中启动局域网网页遥控器，并在菜单栏显示访问地址

## 2. 窗口控制层

文件：

- `FloatingPanelController.swift`
- `IslandDropCoordinator.swift`

职责：

- 创建和持有 `NSPanel`
- 控制 floating panel 显示
- 负责顶部位置计算
- 根据 ViewModel 的 panel 尺寸更新窗口 frame
- 将 `MusicPlayerViewModel`、`QuickLaunchViewModel` 与 `TemporaryTrayViewModel` 透传给 `ContentView`
- 通过自定义 `IslandPanel` 处理透明面板点击 warning
- 通过自定义 hosting view 限制透明区域的 hit-test
- expanded 期间通过自定义 hosting view 放行透明区域 hit-test，避免遮挡桌面或其它 App
- expanded 期间由 `IslandHostingView` 接收 AppKit 拖拽事件，并交给 `IslandDropCoordinator` 按命中区域分发至播放列表、快捷启动或临时暂存
- 打开 `NSOpenPanel` 等 Onion 发起的系统面板后恢复 island 层级
- 文件选择器进入 modal event loop 后由 `MusicFilePicker` 异步提升层级，确保添加歌曲面板显示在 island 上方
- `IslandDropCoordinator` 单独协调 expanded 内播放列表、快捷启动和临时暂存的 AppKit 投放判定及动作分发，不参与窗口 frame 计算

当前设计原则：

- `NSPanel` 使用透明背景
- 面板本身不承担业务逻辑
- 所有尺寸数据从 `IslandViewModel` 获取
- 音乐 ViewModel 只透传，不参与 frame、屏幕和层级计算

当前已覆盖：

- 多显示器支持
- 窗口层级和交互策略优化
- 内部点击收起完成后窗口缩回 compact 尺寸
- 点击桌面或其它 App 不触发收起；expanded 透明区域由自定义 hosting view 放行 hit-test，避免阻挡鼠标事件
- 添加歌曲 `NSOpenPanel` 不隐藏、不移动 island；通过异步置顶文件选择器解决系统面板和 statusBar island 的层级冲突

## 3. 状态管理层

文件：

- `IslandViewModel.swift`
- `Music/MusicPlayerViewModel.swift`
- `QuickLaunch/QuickLaunchViewModel.swift`
- `TemporaryTray/TemporaryTrayViewModel.swift`

职责：

- 管理是否展开
- 管理两阶段展开所需的窗口保留状态
- 提供 compact / expanded 的 island 和 panel 尺寸参数
- 在 panel 尺寸变化时通知窗口控制层刷新布局
- 通过回调把打开设置和退出请求交给 App 入口处理

当前主要字段类型：

- 展开状态：`isExpanded`
- 窗口保留状态：`reservesExpandedWindow`
- 尺寸数据：`collapsedWidth`、`expandedWidth`、`collapsedHeight`、`expandedHeight`

当前通信方式：

- `onLayoutChange` 闭包
- `onOpenSettings` / `onRequestQuit` 闭包
- 当 `reservesExpandedWindow` 变化时触发窗口布局更新
- `isExpanded` 只驱动 SwiftUI 壳体动画，不直接触发 AppKit frame 更新
- 工具按钮不直接持有 AppKit 对象，通过 ViewModel 回调进入 App 入口层

当前已覆盖：

- 空 UI 状态管理
- 两阶段展开：先保留 expanded 窗口，再展开 SwiftUI 壳体
- 内部点击收起完成后延迟缩回 AppKit 窗口
- 点击桌面或其它 App 不改变 `isExpanded`

MusicPlayerViewModel 职责：

- 管理当前曲目、播放状态、当前进度和时间文本
- 管理本地 / 线上播放模式、当前播放列表、当前播放索引和播放模式
- 调用 `MusicFilePicker` 选择本地音频文件或目录
- 调用 `MusicDirectoryScanner` 从目录中筛选支持的音频文件
- 接收文件选择器或拖拽传入的 URL，统一过滤、去重并追加到播放列表
- 调用 `MusicPlaylistStore` 保存和恢复轻量播放列表状态
- 调用 `MusicPlayerController` 播放、暂停、回到开头和 seek
- 调用 `OnlineMusicService` 获取网易云用户歌单、在线歌曲播放 URL，并触发可选边听边存
- 仅在内存中缓存线上发现歌曲列表、当前线上播放列表和在线播放失败状态；退出 App 或刷新列表后清空，不写入 `playlist.json`
- 不处理 island 尺寸、窗口定位或展开 / 收起逻辑
- 不控制 `isExpanded`，播放状态不得影响 island 展开 / 收起

TemporaryTrayViewModel 职责：

- 保存当前 App 会话中的文件 / 文件夹 URL 引用、拖入高亮和简短状态反馈
- 对同一路径去重并限制首版最多 `20` 个项目
- 管理单选、`Command` 增减选择、`Shift` 连续范围选择和批量拖出中的项目集合
- 提供移除 / 清空引用入口，不移动、复制或删除磁盘上的源项目
- 不负责跨启动持久化、播放列表导入或快捷启动配置

QuickLaunchViewModel 职责：

- 管理固定 `10` 槽状态、替换 / 交换动作与投放高亮
- 委托 `QuickLaunchStore` 保存槽位路径，委托 `QuickLaunchAppController` 执行系统打开与图标读取
- 不直接操作 `UserDefaults`、`NSWorkspace` 或原生 dragging session

## 4. 局域网遥控层

文件：

- `RemoteControl/RemoteControlServer.swift`

职责：

- 使用 `Network` 框架监听 `17777` 端口
- 提供无配对的局域网 HTTP 控制页
- 提供播放 / 暂停、上一首 / 下一首、音量调整、默认输出设备读取 / 选择 / 恢复、播放列表读取、点击播放、歌词状态读取和当前 Mac 睡眠接口
- 将所有播放动作转发给 `MusicPlayerViewModel`
- 读取 `LyricsViewModel` 的当前歌词行及前后窗口，遥控端通过“歌词 / 歌曲列表”分栏展示歌词和播放列表，不处理在线候选确认或本地歌词选择
- 读取 `AudioOutputDeviceService` 的当前可见输出设备，遥控端可保存默认输出设备并手动触发恢复
- 使用 `IOKit.pwr_mgt` 触发系统睡眠，只作用于当前运行 Onion 的 Mac
- 不直接访问 `AVPlayer`、不处理 island 尺寸、窗口定位或 SwiftUI 渲染

当前约束：

- 遥控器默认无配对码或 token，适合用户可信任的家庭局域网
- 遥控器访问状态时会触发 `MusicPlayerViewModel.showLyrics()`，确保手机端无需先打开 Mac 上的歌词标签页即可读取歌词；联网仍受“联网匹配歌词”开关控制，在线候选选择仍留在 Mac UI
- 睡眠后 Onion 进程和 HTTP 服务不再响应；唤醒依赖 macOS 网络唤醒、路由器、Home Assistant 或其它外部 Wake-on-LAN 能力
- App Sandbox 需要同时启用 `network.client` 和 `network.server` 权限
- 外网暴露、访问控制和配对流程不属于当前首版范围

## 5. 视图渲染层

文件：

- `ContentView.swift`
- `CompactIslandView.swift`
- `ExpandedIslandView.swift`
- `NotchIslandShape.swift`
- `Controls/` 目录（右侧工具按钮组与跨功能共用视图桥接）
- `Music/` 目录（音乐 mini player）
- `QuickLaunch/` 目录（快捷启动槽位）
- `TemporaryTray/` 目录（临时文件引用拖盘）
- `Mascot/` 目录（角色动画系统）
- `Settings/` 目录（设置窗口）

职责：

- 渲染 compact island（含左侧 Mascot 角色）
- 渲染右侧收起态音乐活动指示与展开态工具按钮组（静音 / 设置 / 退出）
- compact 不渲染音乐控制
- 渲染 expanded mini player
- 应用自定义 notch shape
- 响应点击展开/收起，并协调两阶段展开动画

Music 子系统职责：

- `MusicTrack.swift` — 单曲模型，保存本地 URL、时长及用于歌词匹配的标题 / 歌手；metadata 缺失时按文件名回退
- `MusicPlayerState.swift` — 播放状态枚举，不保存曲目信息
- `MusicFilePicker.swift` — 使用 `NSOpenPanel` 混合选择本地音频文件和音乐目录
- `MusicPlayerController.swift` — 唯一直接使用 `AVPlayer` 的底层播放控制器，负责 security-scoped 文件访问生命周期，并把播放开始、结束、失败与 stall 状态回传给 ViewModel
- `MusicPlayerViewModel.swift` — 音乐状态、本地 / 线上播放模式、播放列表状态和动作入口；退出时保存当前播放进度
- `OnlineMusicService.swift` — 网易云登录状态、用户歌单、在线歌曲播放 URL 和边听边存触发的服务边界
- `NeteaseAPIClient.swift` — 网易云榜单、搜索、歌单、相似歌曲、播放 URL 和账号状态请求
- `NeteaseModels.swift` — 网易云接口响应与歌曲 / 歌单数据结构
- `NeteaseDiscoveryView.swift` — 线上发现页，承载榜单、搜索、个人歌单、相似推荐、在线歌曲列表和失败状态提示；列表结果与失败状态只保留当前 App 会话缓存
- `OnlineDownloadManager.swift` — 在线歌曲下载到本地目录，并服务“边听边存”
- `MusicFolderMonitor.swift` — 可选监听指定音乐目录，发现新增音频后转交播放列表导入
- `AudioOutputDeviceService.swift` — 使用 CoreAudio 枚举系统输出设备，并按保存的设备 UID 尝试切换默认输出设备
- `LyricsService.swift` — 读取本地 / 已确认缓存歌词；仅在用户允许后搜索在线候选、下载确认结果并写入缓存
- `LyricsViewModel.swift` — 歌词标签页状态、本地导入、在线候选选择、失败重试和时间高亮同步
- `MusicLyricsView.swift` — 歌词滚动展示、联网关闭提示、候选选择与重新匹配操作
- `MusicPlaybackMode.swift` — 播放模式枚举，支持顺序、单曲循环、列表循环、随机
- `MusicDirectoryScanner.swift` — 判断拖入文件 / 目录是否可导入，并扫描目录第一层筛选支持的本地音频文件
- `MusicPlaylistStore.swift` — 使用 JSON 保存本地音频文件 URL、只读 security-scoped bookmark、当前索引、播放模式和当前曲目播放进度，存储在 Application Support；恢复时把原始索引映射到过滤后的有效列表；不保存线上发现歌曲列表或在线播放失败状态
- `MusicExpandedView.swift` — expanded mini player 的顶部控制、进度区和下方功能入口组合，不承载播放列表卡片、快捷启动或临时暂存内部实现
- `MusicPlaylistPanelView.swift` — 播放列表 / 歌词共用卡片、切换头部与音乐投放热区
- `MusicPlaylistPreviewItem.swift` — 播放列表单行展示、当前播放指示与删除入口
- `MusicTimelineSlider.swift` — 拖动进度条的局部交互与回调转发
- `MusicHeaderControls.swift` — 播放列表卡片的添加 / 清空微型按钮及播放器按钮 hover 修饰器
- `MusicStyle.swift` — 音乐区域共享强调色
- 当前阶段只为歌词匹配和线上展示读取标题 / 歌手 metadata，不显示封面，不做复杂资料库

QuickLaunch 子系统职责：

- `QuickLaunchViewModel.swift` — 管理 10 个可空快速启动槽位、外部拖入放置 / 替换、已有 App 移动 / 交换和槽位布局持久化
- `QuickLaunchStore.swift` — 使用 JSON 保存和恢复固定槽位中的 App 路径
- `QuickLaunchAppController.swift` — 调用系统打开 App，并提供系统 App 图标
- `QuickLaunchDragSource.swift` — 桥接 AppKit 原生内部拖动图像与换位投放数据
- `QuickLaunchView.swift` — 组合快捷启动标题、空态引导、槽位、占位与投放反馈
- `QuickLaunchItemView.swift` — 呈现单个已有 App 槽位及删除入口

TemporaryTray 子系统职责：

- `TemporaryTrayViewModel.swift` — 管理临时暂存的当前会话文件引用、去重 / 容量、移 / 拷模式、选择集合、框选和拖放反馈状态
- `TemporaryTrayItem.swift` — 描述文件引用与当前可用显示状态，不直接访问文件系统
- `TemporaryTrayFileService.swift` — 检查文件可用性并加载 Quick Look 预览 / 系统图标回退
- `TemporaryTrayDragSource.swift` — 桥接携带真实 `fileURL` 的单项或批量原生文件拖出
- `TemporaryTrayView.swift` — 组合临时暂存标题、空态、图标架与清空入口
- `TemporaryTrayItemView.swift` — 呈现单个引用的预览、名称、选中态及移除入口

Controls 子系统职责：

- `IslandToolButton.swift` — 单个圆形图标按钮，统一 hover 背景、描边和辅助提示
- `IslandToolButtonsView.swift` — 横向组合静音、设置、退出三个工具按钮
- `DropFrameReporter.swift` — 将 SwiftUI 热区 frame 上报到 AppKit 拖拽路由使用的 window 内容坐标系，供播放列表、快捷启动和临时暂存复用
- 静音只更新 Onion 内部状态，不修改系统音量
- 设置和退出通过 `IslandViewModel` 回调交给 `OnionFlowApp.swift`

Mascot 子系统职责：

- `MascotState.swift` — idle / working / music 动画状态枚举
- `MascotKind.swift` — `String` rawValue + `CaseIterable`，含小机器人 / 鬼魂 / 像素螃蟹 / 像素小狗 / 像素猫 / 像素恐龙 / 终端蛙
- `MascotView.swift` — 统一入口，按 `MascotKind` 分发到具体角色 View
- `Characters/RobotMascotView.swift` — 小机器人，舱体舱门、金属高光、高透面罩、LED眼睛带均衡器跳动、胸口 Arc Reactor 呼吸核心与两侧悬浮双手
- `Characters/GhostMascotView.swift` — 害羞幽灵，半透明发光白蓝渐变、粉红腮红、双手浮空、底部底边裙摆呈数学正弦波实时水波流动
- `Characters/PixelCrabMascotView.swift` — 像素螃蟹，复古 8-bit 点阵格栅、双螯挥舞和横行动效
- `Characters/PixelCatMascotView.swift` — 像素猫，尾巴摇摆与眨眼
- `Characters/PixelDinoMascotView.swift` — 像素恐龙，奔跑与大跳
- `Characters/PixelFrogMascotView.swift` — 终端蛙，腮帮呼吸与大弹跳
- idle 状态：极缓浮沉呼吸、天线/项圈铃铛/反应堆核心发光呼吸 + 错位 Z 上浮
- working 状态：运动加速，头顶额外浮现 3 点式 Loading（小草点、浆果点、碎石点等），显示专注和后台深度处理
- music 状态：强节奏跳跃，并由 `MascotMusicNotesEffect` 提供环绕音符特效

Settings 子系统职责：

- `MascotPickerView.swift` — 角色卡片、频谱风格、氛围背景 / 粒子、歌词联网偏好与性能效果设置
- `SettingsWindowController.swift` — 固定宽度、内容自适应高度的可交互独立 NSPanel，负责面板生命周期、鼠标事件接收、相对 island 的定位、高度变化时保持顶部锚点，以及失焦关闭。为了在 macOS 15.0 部署目标下绕过 Swift 编译器优化阶段的 `EarlyPerfInliner` 崩溃 Bug，内部 `SettingsHostingView` 统一采用非泛型的 `NSHostingView<AnyView>` 避让方案。
- 通过 `@AppStorage` 与渲染 / 歌词状态共享 `mascotKind`、`spectrumStyle`、`backgroundNebulaEnabled`、`backgroundParticlesEnabled`、`backgroundNebulaTheme` 和 `onlineLyricsEnabled`；expanded 内容按背景开关挂载 / 卸载 `AntigravityBackgroundView`，歌词联网权限由 `LyricsViewModel` 在歌词检查时读取

当前结构：

- 外层为单个 island 容器
- 收起态 compact 保留左侧 Mascot 与右侧音乐活动指示
- 展开后 compact 顶栏恢复右侧工具按钮组
- expanded 状态显示 mini player

当前设计原则：

- 不做多层黑色背景叠加
- compact 状态保持单行高度
- expanded mini player 仍由同一个 island shape 承载
- 音乐业务不写进 `ContentView.swift` 或 `IslandViewModel.swift`

## 数据流

当前数据流：

1. `OnionFlowApp.swift` → `AppDelegate` → `IslandViewModel` + `MusicPlayerViewModel` + `QuickLaunchViewModel` + `TemporaryTrayViewModel` → `FloatingPanelController` → `ContentView`
2. 用户点击 island 展开时，`ContentView` 先调用 `reserveWindowForExpansion()`
3. `reservesExpandedWindow` 变化后触发 `onLayoutChange`
4. `FloatingPanelController` 先把窗口扩到 expanded 尺寸
5. 下一帧 / 延迟时间后 `ContentView` 调用 `expandIsland()`，SwiftUI 壳体从中心展开。在 Apple Silicon 下使用 `DispatchQueue.main.async`（下一帧秒开），在 Intel 架构下使用 `#if arch(x86_64)` 分支延迟 `0.08` 秒展开以避开核显重绘卡顿。
6. 内部点击收起时，`collapseIsland()` 先收起 SwiftUI 壳体；`AppDelegate` 同步关闭已打开的设置窗口，再延迟缩小 AppKit 窗口
7. 用户点击 Onion 外部其它 App 或桌面时不触发收起；透明区域由 `IslandHostingView.hitTest(_:)` 放行，不阻挡桌面或其它 App 鼠标事件

### 本地音乐播放流

1. 用户在 mini player 点击添加歌曲 → `MusicPlayerViewModel.addFilesOrDirectoriesToPlaylist()`
2. `MusicPlayerViewModel` 通知 `FloatingPanelController` 进入文件选择器流程，关闭后恢复 island 层级
3. `MusicFilePicker` 使用 `NSOpenPanel` 返回用户选择的音频文件和 / 或目录 URL；通过 Swift Concurrency `async/await` 异步拉起面板并将其提升到 island 上方，确保在此期间完全释放主 Actor 阻断，保持 Island 与 Mascot 动效顺畅运行。
4. 用户也可以把本地音频文件或文件夹拖入播放列表区域；由于 island 使用非激活 `NSPanel`，拖拽接收在 `IslandHostingView` 的 AppKit 层完成，再把 URL 转交给 `MusicPlayerViewModel`
5. `MusicPlayerViewModel` 委托 `MusicDirectoryScanner.audioFilesToImport(from:)` 统一判断文件 / 目录并展开可导入音频，随后过滤播放列表中已存在的文件
6. 播放列表、当前索引、播放模式和当前曲目进度变化后，`MusicPlayerViewModel` 调用 `MusicPlaylistStore` 写入 `playlist.json`，同时为本地文件保存只读 security-scoped bookmark
7. App 启动时，`MusicPlayerViewModel` 从 `MusicPlaylistStore` 恢复音频文件 URL、只读 security-scoped bookmark、当前索引、播放模式和当前曲目进度；恢复时过滤已不存在或不再是音频的文件，并将保存的原始 `currentIndex` 映射到过滤后的有效列表
8. 启动恢复会加载当前曲目，seek 到上次位置并继续播放；旧 `playlist.json` 缺少 `currentTrackProgress` 时按 0 处理
9. 如果当前没有有效播放列表，ViewModel 设置 `currentIndex` 并调用 `MusicPlayerController.load(url:)` 播放新添加的第一首
10. `MusicPlayerController` 对本地 URL 开启 security-scoped access，使用 `AVPlayerItem` 加载文件，并安装进度 / 播放开始 / 播放结束 / 失败 / stall 监听
11. 加载成功后 `MusicPlayerViewModel` 保存 `MusicTrack`，并切换到 `.playing`
12. 播放进度通过 controller 回调更新 `currentTime`
13. 自然播放结束后，ViewModel 按 `MusicPlaybackMode` 决定顺序下一首、列表循环或随机播放
14. `ContentView` 的收起态 compact 始终保持 Mascot / 右侧音乐活动指示，展开态恢复工具按钮组，音乐控制集中在 expanded mini player

### 线上音乐播放流

1. 用户在播放列表卡片切到线上发现页，`NeteaseDiscoveryView` 读取榜单、搜索、个人歌单或相似推荐数据
2. 线上列表数据由 `NeteaseAPIClient` 通过 `URLSession` 获取，并以 `NeteaseSong` / `NeteaseUserPlaylist` 等模型传回 UI；`MusicPlayerViewModel` 只做当前 App 会话内存缓存，刷新列表时重置在线播放失败标记
3. 用户点击在线歌曲后，`MusicPlayerViewModel` 切到 `.online` 模式，保存本地播放记忆，并把当前线上列表复制为 `activeOnlinePlaylist`
4. `MusicPlayerViewModel` 调用 `OnlineMusicService.streamURL(for:)` 获取真实播放 URL，再委托 `MusicPlayerController` 通过 `AVPlayer` 播放该 URL
5. 在线歌曲播放成功后仍生成 `MusicTrack`，供歌词匹配、进度更新、遥控器状态和 Mascot music 状态复用；ViewModel 会等 AVPlayer 真实开始播放或进度推进后再切到 `.playing`
6. 如果开启“边听边存”，`OnlineMusicService` 触发 `OnlineDownloadManager` 后台下载；若用户同时开启目录自动监听，`MusicFolderMonitor` 可把下载目录中新出现的音频追加到本地播放列表
7. 在线模式自然结束后同样走 `MusicPlaybackMode`，单曲循环重播当前在线曲目，列表循环 / 随机 / 顺序模式按 `activeOnlinePlaylist` 推进
8. 在线播放启动超过约 6 秒仍未推进，或 AVPlayer 回传失败 / 早期 stall 后仍无进展时，ViewModel 会标记当前线上歌曲失败并按现有失败跳过逻辑处理
9. App 退出后，`onlinePlaylist`、`activeOnlinePlaylist`、`cachedOnlinePlaylists`、`failedOnlineSongIDs` 和 `onlineSongFailureMessages` 随进程释放；下次启动重新拉取线上发现列表，并初始化失败状态

### 歌词流

1. `MusicPlayerViewModel.showLyrics()` 可由当前曲目加载、expanded 面板出现、播放列表 / 歌词布局切换、歌词标签页或遥控状态读取触发；`LyricsViewModel` 先检查本地与已确认缓存
2. `LyricsService` 先尝试读取同名本地 `.lrc`，再读取已经确认并写入 `LyricsCacheV2` 的歌词；旧版未确认的自动匹配缓存不会沿用
3. 同目录 `.lrc` 在用户只授权单个沙盒外音频文件时可能不可读取；歌词页提供手动选择 `.lrc` 并复制到缓存的入口
4. 没有已有歌词且 `onlineLyricsEnabled` 关闭时，页面提示用户在设置中开启，不联系第三方服务
5. 开关开启时，服务使用曲目标题 / 歌手搜索在线候选；标题和歌手均可靠对应时可自动下载并缓存
6. 无可靠自动匹配时展示候选列表，由用户选择后下载并缓存；用户点击重新匹配时始终进入候选选择流程，也可返回原歌词而不覆盖当前关联
7. 网络失败与未找到歌词分别显示，失败状态允许重试

### 右侧工具按钮流

1. 用户点击静音按钮 → `IslandToolButtonsView` 调用 `musicViewModel.toggleMute()`
2. `MusicPlayerViewModel.isMuted` 更新后刷新按钮图标和 hover / active 视觉状态
3. 用户点击设置按钮 → `viewModel.openSettings()` → `AppDelegate.settingsController.toggle()`，未打开时显示设置窗口，已打开时关闭；`SettingsWindowController` 将可见状态回传给 `IslandViewModel` 以更新按钮提示词；island 收起时 AppDelegate 关闭仍在显示的设置窗口
4. 用户点击退出按钮 → `viewModel.requestQuit()` → `AppDelegate.quitApp()` → `NSApp.terminate(nil)`

### 快速启动流

1. 用户在 expanded 内容中的快速启动区域拖入 `.app` 或拖动已有 App 图标；该区域由 `QuickLaunchView` 呈现，原生拖动由 `QuickLaunchDragSource` 承担
2. 完全为空时显示主副引导文案；已有 App 或拖入悬停时空槽以弱化占位显示；每次外部拖入仅接收一个 `.app`，高亮鼠标指向的固定槽位，`QuickLaunchViewModel` 将 App 放入该槽位，目标已有 App 时直接替换
3. 已有 App 拖到空槽时移动，拖到占用槽位时交换两个 App，空槽允许保留在中间
4. `QuickLaunchStore` 将 10 槽布局（包含空槽）写入 `quickLaunchAppsJson`，启动后恢复原布局；旧的紧凑列表数据会映射到前几个槽位
5. 用户在设置页关闭快捷启动时仅隐藏入口并扩展播放列表 / 歌词内容高度，已保存槽位不清除，AppKit 不再接收该区域的 `.app` 投放；底部临时暂存保持可见

### 临时暂存流

1. 用户把单个或多个文件 / 文件夹拖到 expanded 底部临时暂存，`IslandHostingView` 将事件交给 `IslandDropCoordinator`，仅在暂存热区把原始 URL 交给 `TemporaryTrayViewModel`
2. ViewModel 按标准化路径去重，当前会话内最多保存 `20` 个引用；默认拖入记录为移动，按 `Option` 拖入记录为复制，普通文件、音频文件和 `.app` 在此区域都不触发其它入口动作
3. `TemporaryTrayFileService` 异步请求 Quick Look 缩略预览并提供系统文件图标回退，`TemporaryTrayView` / `TemporaryTrayItemView` 仅展示原始名称、预览和不可用状态
4. 用户可单击选择、以 `Command` 增减选择、以 `Shift` 选择连续范围，或从空白区域拖动框选；拖动任意已选项目时，`TemporaryTrayDragSource` 按项目保存的移动 / 复制模式把选中的真实 `fileURL` 一次写出，并用叠放图像与数量角标反馈批量拖出
5. 移 / 拷混合选择时，ViewModel 即时提示“移 / 拷暂不支持混合，请分开拖出”，并拒绝启动混合批量拖出
6. 目标成功接收后自动批量移除对应拖盘引用，取消拖拽或投回拖盘自身时保留。由于 island 保持非激活 `NSPanel`，首版不劫持键盘 `Esc`
7. 单项移除或清空只移除引用，不删除源文件；首版不持久化 URL 或 security-scoped bookmark，重启后拖盘为空

### Onion 设置流

1. 用户点击菜单栏 "Settings..." → `AppDelegate.settingsController.show()`
2. `AppDelegate` 将设置定位锚点传给 `SettingsWindowController`：expanded 锚点使用固定的右侧视觉补偿，设置窗口顶部向下错开 `3pt`；简洁边缘隐藏投影后仍沿用同一横向位置，避免观感间隔改变
3. 用户在设置页选择角色 → 写入 `@AppStorage(mascotKind)`
4. `ContentView` 读取 `@AppStorage` → MascotView 实时更新
5. Mascot 状态由 `IslandViewModel.isExpanded` 和 `MusicPlayerViewModel.state` 单向映射到 `MascotState`
6. 用户选择频谱风格、氛围背景主题、动态粒子或“联网匹配歌词” → 通过 `@AppStorage` 分别驱动 compact 频谱、expanded 背景效果和歌词联网权限
7. 用户在局域网遥控页选择默认输出设备 → `RemoteControlServer` 保存 `preferredAudioOutputDeviceUID` 并调用 `AudioOutputDeviceService` 尝试切换输出
8. App 启动或收到 `NSWorkspace.didWakeNotification` 后，`AppDelegate` 读取 `preferredAudioOutputDeviceUID` 并让 `AudioOutputDeviceService` 延迟重试切换输出；若蓝牙音箱尚未重新出现在系统输出设备列表中，本轮恢复会失败但不阻塞播放

### 工程命名与数据身份

- 用户可见的正式名称为 `Onion Flow`，菜单栏、设置标题和工具提示使用简称 `Onion`。
- `OnionFlow.xcodeproj`、`OnionFlow/`、`OnionFlowApp.swift`、target / scheme、`larva.OnionFlow` Bundle ID 与 Application Support 下的 `OnionFlow` 存储目录采用同一内部标识。
- Bundle ID 与沙箱容器身份已从旧开发版本切换；macOS Sandbox 不允许新身份自动读取旧容器中的偏好、播放列表和歌词缓存。

## 当前已知问题

### 1. notch 形状仍在迭代

虽然已经实现了自定义 shape（`NotchIslandShape` 现已支持 `AnimatablePair` 实现肩部和底部半径插值动画），并修正了 compact 左右肩部轮廓，但视觉上还没有完全贴近真实 macOS notch / Dynamic Island。

### 2. 顶部贴边策略仍在观察

当前已有基础顶部居中和鼠标所在屏幕优先策略。

### 3. Music 播放列表与线上发现阶段已完成基础接入

当前代码已接入本地 mini player、线上发现、播放列表和轻量持久化。后续扩展前仍应保持音乐业务边界：文件选择在 `MusicFilePicker.swift`，目录扫描在 `MusicDirectoryScanner.swift`，播放器能力在 `MusicPlayerController.swift`，播放列表持久化在 `MusicPlaylistStore.swift`，网易云请求入口在 `NeteaseAPIClient.swift` / `OnlineMusicService.swift`，线上发现 UI 在 `NeteaseDiscoveryView.swift`，下载能力在 `OnlineDownloadManager.swift`，状态和动作编排在 `MusicPlayerViewModel.swift`。

### 4. 本地同目录歌词受沙盒授权范围限制

当用户只选择一个沙盒外音频文件时，应用不保证能够自动读取相邻 `.lrc`。当前提供“选择本地歌词”将用户确认文件复制入缓存的兜底路径。

## 后续扩展方向

### 渲染层

当前顶层 island 渲染已拆分：

- `CompactIslandView`
- `ExpandedIslandView`
- `NotchIslandShape`

Mascot 角色系统扩展：

- 新增角色只需：`MascotKind` 加 case + `Characters/` 下新增角色 View 文件 + `MascotView` switch 加一行
- 设置页自动显示新角色（`CaseIterable`），当前所有角色均可选择
- Mascot 系统与岛屿状态、播放状态单向绑定（`viewModel.isExpanded` / `musicViewModel.state → MascotState`），不反向耦合

注意：

- 这是后续方向，不是现在立刻重构

## 当前开发准则

- 每次只做一个小任务
- 不做无关重构
- 先保证项目具备可编译路径，是否运行 `xcodebuild` 按下方 Build 规则执行
- island 外壳、展开 / 收起与顶层组合 UI 集中在 `ContentView.swift`；有独立状态与交互的功能视图放入对应子系统目录
- 窗口尺寸、定位、层级和 hosting 外壳逻辑集中在 `FloatingPanelController.swift`；跨功能拖放分发由 `IslandDropCoordinator.swift` 承担
- 状态数据优先集中在 `IslandViewModel.swift`
- 当前项目只注释有价值代码，不要求每行都补注释
- 有价值注释优先用于解释不容易直接看懂的逻辑、平台约束、状态流和容易误改的位置
- 对几何路径、窗口定位、多屏策略、状态绑定、SwiftUI 结构、预览代码，可按需要补充更细的中文注释
- 修改复杂逻辑时，如果新增了控制点、尺寸公式、特殊分支或预览代码，应同步检查是否需要更新注释

## Build / xcodebuild 规则

- 默认不主动运行 `xcodebuild`，避免产生大量日志和 token 消耗
- 只改文档、注释、提示词、任务清单、README 时，不运行 build
- 只改轻量 UI 文案、颜色、间距时，通常不运行 build，由用户在 Xcode 中验证
- 修改 Swift 逻辑、SwiftUI 结构、AppKit 窗口、播放器、文件权限、异步流程或 Xcode 工程配置时，应说明建议验证方式
- 只有在用户明确要求、正在修复编译错误，或改动风险较高且需要确认可编译时，才运行 `xcodebuild`
- 如果用户说明“我自己编译”或“不要运行 xcodebuild”，则不运行 build，只列出需要用户验证的点

## 注释执行规则

- 只为有理解成本、维护风险、平台约束或容易误改的代码补充中文注释
- 简单赋值、直观布局参数、普通属性声明和自解释调用不写注释，避免注释噪音
- 已经过期、重复解释代码表面含义或没有维护价值的旧注释，可以删除或改写
- 对以下内容必须重点注释：
  - `SwiftUI` 视图结构
  - 自定义 `Shape` / `Path`
  - `NSPanel`、窗口定位、多屏判断
  - 属性包装器，例如 `@State`、`@ObservedObject`
  - `#Preview` 预览代码

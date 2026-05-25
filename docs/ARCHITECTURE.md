# ARCHITECTURE

## 目标

本文档用于说明 NookFlow 当前 macOS MVP 迭代阶段的基本架构、主要职责划分，以及后续扩展方向。

当前项目采用：

- `SwiftUI` 负责主要界面
- `AppKit` 负责顶部 floating panel 管理
- `ObservableObject` 负责基础状态驱动
- `AVPlayer` 负责本地音乐播放

## 架构概览

当前结构可以理解为 4 层：

1. 应用入口层
2. 窗口控制层
3. 状态管理层
4. 视图渲染层

## 1. 应用入口层

文件：

- `NookFlowApp.swift`

职责：

- 启动应用
- 初始化 `AppDelegate`
- 创建 `IslandViewModel`
- 创建 `MusicPlayerViewModel`
- 挂载 `MenuBarExtra`
- 提供 menu bar app 入口

当前实现思路：

- 使用 `@NSApplicationDelegateAdaptor` 接入 `AppDelegate`
- 在 `applicationDidFinishLaunching` 中创建顶部 island panel

## 2. 窗口控制层

文件：

- `FloatingPanelController.swift`

职责：

- 创建和持有 `NSPanel`
- 控制 floating panel 显示
- 负责顶部位置计算
- 根据 ViewModel 的 panel 尺寸更新窗口 frame
- 将 `MusicPlayerViewModel` 透传给 `ContentView`
- 通过自定义 `IslandPanel` 处理透明面板点击 warning
- 通过自定义 hosting view 限制透明区域的 hit-test
- expanded 期间通过自定义 hosting view 放行透明区域 hit-test，避免遮挡桌面或其它 App
- expanded 期间由 `IslandHostingView` 接收 Finder 文件 / 文件夹拖拽，并把 URL 转交给 `MusicPlayerViewModel`
- 打开 `NSOpenPanel` 等 NookFlow 发起的系统面板后恢复 island 层级
- 文件选择器进入 modal event loop 后由 `MusicFilePicker` 异步提升层级，确保添加歌曲面板显示在 island 上方

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
- 管理当前播放列表、当前播放索引和播放模式
- 调用 `MusicFilePicker` 选择本地音频文件或目录
- 调用 `MusicDirectoryScanner` 从目录中筛选支持的音频文件
- 接收文件选择器或拖拽传入的 URL，统一过滤、去重并追加到播放列表
- 调用 `MusicPlaylistStore` 保存和恢复轻量播放列表状态
- 调用 `MusicPlayerController` 播放、暂停、回到开头和 seek
- 不处理 island 尺寸、窗口定位或展开 / 收起逻辑
- 不控制 `isExpanded`，播放状态不得影响 island 展开 / 收起

## 4. 视图渲染层

文件：

- `ContentView.swift`
- `Controls/` 目录（右侧工具按钮组）
- `Music/` 目录（本地音乐 mini player）
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

- `MusicTrack.swift` — 单曲模型，只保存本地 URL、标题和时长
- `MusicPlayerState.swift` — 播放状态枚举，不保存曲目信息
- `MusicFilePicker.swift` — 使用 `NSOpenPanel` 混合选择本地音频文件和音乐目录
- `MusicPlayerController.swift` — 唯一直接使用 `AVPlayer` 的底层播放控制器，并负责 security-scoped 文件访问生命周期
- `MusicPlayerViewModel.swift` — 音乐状态、播放列表状态和动作入口
- `MusicPlaybackMode.swift` — 播放模式枚举，支持顺序、单曲循环、列表循环、随机
- `MusicDirectoryScanner.swift` — 扫描目录第一层，筛选支持的本地音频文件
- `MusicPlaylistStore.swift` — 使用 JSON 保存音频文件 URL、只读 security-scoped bookmark、当前索引、播放模式和当前曲目播放进度，存储在 Application Support
- `MusicPlayerViewModel.swift` — 退出时调用 `persistCurrentStateOnQuit()` 保存当前播放进度，确保下次启动能恢复
- `MusicExpandedView.swift` — expanded mini player，包含播放 / 暂停 / 添加歌曲 / 播放模式 / 播放列表 / 拖拽导入 / 进度和时间
- `QuickLaunchViewModel.swift` — 管理快速启动 App 列表、按拖放位置插入、拖动重排、最多 10 个和顺序持久化
- 当前阶段不读取 metadata，不显示封面，不做复杂资料库

Controls 子系统职责：

- `IslandToolButton.swift` — 单个圆形图标按钮，统一 hover 背景、描边和辅助提示
- `IslandToolButtonsView.swift` — 横向组合静音、设置、退出三个工具按钮
- 静音只更新 NookFlow 内部状态，不修改系统音量
- 设置和退出通过 `IslandViewModel` 回调交给 `NookFlowApp.swift`

Mascot 子系统职责：

- `MascotState.swift` — idle / working / music 动画状态枚举
- `MascotKind.swift` — `String` rawValue + `CaseIterable`，含小狗 / 小机器人 / 小猫 / 鬼魂 / 小羊 / 小鸟 / 木头人
- `MascotView.swift` — 统一入口，按 `MascotKind` 分发到具体角色 View
- `Characters/SleepCapsuleMascotView.swift` — 柴犬小狗，焦糖渐变、垂耳摆动、戴红色项圈与小金铃铛，听歌时活泼吐舌
- `Characters/RobotMascotView.swift` — 小机器人，舱体舱门、金属高光、高透面罩、LED眼睛带均衡器跳动、胸口 Arc Reactor 呼吸核心与两侧悬浮双手
- `Characters/CatMascotView.swift` — 蜜桃橘猫，粉嫩内耳、蝴蝶结、胡须颤动，听歌时大瞳孔随节奏自动缩放
- `Characters/GhostMascotView.swift` — 害羞幽灵，半透明发光白蓝渐变、粉红腮红、双手浮空、底部底边裙摆呈数学正弦波实时水波流动
- `Characters/NoodleMascotView.swift` — 云朵小羊，层叠云朵气泡毛发、黄金螺旋羊角，听歌时羊毛像“低音炮纸盆”一样弹性鼓点膨胀
- `Characters/BirbMascotView.swift` — 胖胖小鸟，钴蓝到荧光蓝径向渐变身体、橙黄色小喙，工作时小翅膀极速振翼，听歌时开口唱起歌
- `Characters/MoaiMascotView.swift` — 蹦迪石像，火山岩板 slate 灰色质感、硬朗直鼻梁，听歌时炫酷戴上双色荧光霓虹墨镜狂热抖动
- idle 状态：极缓浮沉呼吸、天线/项圈铃铛/反应堆核心发光呼吸 + 错位 Z 上浮
- working 状态：运动加速，头顶额外浮现 3 点式 Loading（小草点、浆果点、碎石点等），显示专注和后台深度处理
- music 状态：强节奏跳跃，小机器人摇头、石像戴眼镜、小羊膨胀、小鸟欢唱、小猫瞳孔缩放，并由 `MascotMusicNotesEffect` 提供环绕音符特效

Settings 子系统职责：

- `MascotPickerView.swift` — 纯角色卡片列表，负责选择 Mascot 类型
- `SettingsWindowController.swift` — 独立 NSPanel（380×320），点击外部关闭
- 通过 `@AppStorage` 与 ContentView 共享 mascotKind；ContentView 仍保留 mascotEnabled / mascotSize 读取兼容

当前结构：

- 外层为单个 island 容器
- 收起态 compact 保留左侧 Mascot、中间展开箭头、右侧音乐活动指示
- 展开后 compact 顶栏恢复右侧工具按钮组
- expanded 状态显示 mini player

当前设计原则：

- 不做多层黑色背景叠加
- compact 状态保持单行高度
- expanded mini player 仍由同一个 island shape 承载
- 音乐业务不写进 `ContentView.swift` 或 `IslandViewModel.swift`

## 数据流

当前数据流：

1. `NookFlowApp.swift` → `AppDelegate` → `IslandViewModel` + `MusicPlayerViewModel` → `FloatingPanelController` → `ContentView`
2. 用户点击 island 展开时，`ContentView` 先调用 `reserveWindowForExpansion()`
3. `reservesExpandedWindow` 变化后触发 `onLayoutChange`
4. `FloatingPanelController` 先把窗口扩到 expanded 尺寸
5. 下一帧 `ContentView` 调用 `expandIsland()`，SwiftUI 壳体从中心展开
6. 内部点击收起时，`collapseIsland()` 先收起 SwiftUI 壳体，再延迟缩小 AppKit 窗口
7. 用户点击 NookFlow 外部其它 App 或桌面时不触发收起；透明区域由 `IslandHostingView.hitTest(_:)` 放行，不阻挡桌面或其它 App 鼠标事件

### 本地音乐播放流

1. 用户在 mini player 点击添加歌曲 → `MusicPlayerViewModel.addFilesOrDirectoriesToPlaylist()`
2. `MusicPlayerViewModel` 通知 `FloatingPanelController` 进入文件选择器流程，关闭后恢复 island 层级
3. `MusicFilePicker` 使用 `NSOpenPanel` 返回用户选择的音频文件和 / 或目录 URL；通过 Swift Concurrency `async/await` 异步拉起面板并将其提升到 island 上方，确保在此期间完全释放主 Actor 阻断，保持 Island 与 Mascot 动效顺畅运行。
4. 用户也可以把本地音频文件或文件夹拖入播放列表区域；由于 island 使用非激活 `NSPanel`，拖拽接收在 `IslandHostingView` 的 AppKit 层完成，再把 URL 转交给 `MusicPlayerViewModel`
5. `MusicPlayerViewModel` 对目录调用 `MusicDirectoryScanner.audioFiles(in:)`，对单文件调用 `MusicDirectoryScanner.isAudioFile(_:)`，并过滤播放列表中已存在的文件
6. 播放列表、当前索引、播放模式和当前曲目进度变化后，`MusicPlayerViewModel` 调用 `MusicPlaylistStore` 写入 `playlist.json`，同时为本地文件保存只读 security-scoped bookmark
7. App 启动时，`MusicPlayerViewModel` 从 `MusicPlaylistStore` 恢复音频文件 URL、只读 security-scoped bookmark、当前索引、播放模式和当前曲目进度；恢复时过滤已不存在或不再是音频的文件
8. 启动恢复会加载当前曲目，seek 到上次位置并继续播放；旧 `playlist.json` 缺少 `currentTrackProgress` 时按 0 处理
9. 如果当前没有有效播放列表，ViewModel 设置 `currentIndex` 并调用 `MusicPlayerController.load(url:)` 播放新添加的第一首
10. `MusicPlayerController` 对本地 URL 开启 security-scoped access，使用 `AVPlayerItem` 加载文件，并安装进度 / 播放结束监听
11. 加载成功后 `MusicPlayerViewModel` 保存 `MusicTrack`，并切换到 `.playing`
12. 播放进度通过 controller 回调更新 `currentTime`
13. 自然播放结束后，ViewModel 按 `MusicPlaybackMode` 决定顺序下一首、列表循环或随机播放
14. `ContentView` 的收起态 compact 始终保持 Mascot / chevron / 右侧音乐活动指示，展开态恢复工具按钮组，音乐控制集中在 expanded mini player

### 右侧工具按钮流

1. 用户点击静音按钮 → `IslandToolButtonsView` 调用 `musicViewModel.toggleMute()`
2. `MusicPlayerViewModel.isMuted` 更新后刷新按钮图标和 hover / active 视觉状态
3. 用户点击设置按钮 → `viewModel.openSettings()` → `AppDelegate.settingsController.show()`
4. 用户点击退出按钮 → `viewModel.requestQuit()` → `AppDelegate.quitApp()` → `NSApp.terminate(nil)`

### 快速启动流

1. 用户在 expanded mini player 的快速启动区域拖入 `.app` 或拖动已有 App 图标
2. `QuickLaunchViewModel` 根据鼠标落点计算插入位置，或对已有项执行重排
3. 列表顺序写入 `@AppStorage(quickLaunchAppsJson)`，启动后恢复原顺序
4. 快速启动列表最多保留 10 个 App，满位时按插入位置裁剪末尾或最前元素

### Mascot 设置流

1. 用户点击菜单栏 "Settings..." → `AppDelegate.settingsController.show()`
2. `SettingsWindowController` 创建 NSPanel + `MascotPickerView`
3. 用户在设置页选择角色 → 写入 `@AppStorage(mascotKind)`
4. `ContentView` 读取 `@AppStorage` → MascotView 实时更新
5. Mascot 状态由 `IslandViewModel.isExpanded` 和 `MusicPlayerViewModel.state` 单向映射到 `MascotState`

## 当前已知问题

### 1. notch 形状仍在迭代

虽然已经实现了自定义 shape（`NotchIslandShape` 现已支持 `AnimatablePair` 实现肩部和底部半径插值动画），并修正了 compact 左右肩部轮廓，但视觉上还没有完全贴近真实 macOS notch / Dynamic Island。

### 2. 顶部贴边策略仍在观察

当前已有基础顶部居中和鼠标所在屏幕优先策略。

### 3. Music 播放列表阶段已完成基础接入

当前代码已接入本地 mini player、播放列表和轻量持久化。后续扩展前仍应保持音乐业务边界：文件选择在 `MusicFilePicker.swift`，目录扫描在 `MusicDirectoryScanner.swift`，播放器能力在 `MusicPlayerController.swift`，播放列表持久化在 `MusicPlaylistStore.swift`，状态和动作在 `MusicPlayerViewModel.swift`。

## 后续扩展方向

### 渲染层

建议后续拆分：

- `CompactIslandView`
- `ExpandedIslandView`
- `IslandShape`

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
- UI 优先集中在 `ContentView.swift`
- 窗口逻辑优先集中在 `FloatingPanelController.swift`
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

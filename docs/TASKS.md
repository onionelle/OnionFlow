# TASKS

## 当前阶段

Music 播放列表阶段已完成基础接入。当前重点是保持顶部 island 体验稳定，继续小步处理交互、视觉和文档同步。

## 正在做

暂无进行中的开发任务。

## 已完成

- [x] 重构收起态右侧音乐活动指示器为 5 栏高质感霓虹频谱仪 (Premium Equalizer Waveform)：
  - [x] 新建模块 `CompactMusicActivityIndicator.swift`，保持 `ContentView.swift` 架构整洁
  - [x] 横跨 5 根音量条的流线渐变调色板（深邃靛蓝 → 天蓝 → 青绿 → 荧光翡翠 → 琥珀酸绿）与匹配霓虹发光阴影
  - [x] 多重频率谐波合成算法 + 幂函数非线性整形，波形跳动有爆发力与弹性的有机音轨感
  - [x] 基于 SwiftUI Spring 的平滑动效衰减过渡，暂停/加载时波形柔和回弹至静态波形，避免瞬间冻结

- [x] 修复播放列表和快速启动的拖拽判定失效问题：通过引入命名空间 `.coordinateSpace(name: "island_panel")`，将 `GeometryReader` 的坐标转换为 `.named("island_panel")`，解决无标题栏 `NSPanel` 下 `.global` 坐标返回零导致热区判定失效的 Bug。
- [x] 支持拖拽添加歌曲 / 文件夹
  - [x] `IslandHostingView` 接收本地 `fileURL` 拖拽，规避非激活 `NSPanel` 下 SwiftUI drop 不稳定的问题
  - [x] 拖拽文件和文件夹复用 ViewModel 的过滤、扫描和去重逻辑
  - [x] 空播放列表状态明确提示可拖拽歌曲或文件夹
  - [x] 拖拽悬停时显示 drop target 视觉提示
- [x] 支持播放列表轻量持久化
  - [x] 保存音频文件 URL、只读 security-scoped bookmark、当前选中索引和播放模式
  - [x] 保存当前曲目播放进度，退出时写入最新播放位置
  - [x] 启动后恢复播放列表，seek 到上次位置并继续播放
  - [x] 恢复时过滤已不存在或不再是音频文件的路径
  - [x] `currentTrackProgress` 字段缺失时使用默认值 0
- [x] 支持快速启动 App 面板
  - [x] 外部拖入 `.app` 时按鼠标落点插入到指定位置
  - [x] 已有 App 支持直接拖动重排位置
  - [x] 顺序写入持久化存储并在启动后恢复
  - [x] 快速启动 App 上限调整为 10 个
- [x] 文档存放整理
  - [x] 注释规则收敛到 `docs/ARCHITECTURE.md`
  - [x] `README.md` 精简为项目入口和文档索引
  - [x] `docs/DESIGN.md` 移除重复文件职责说明
  - [x] `docs/TASKS.md` 精简为任务清单
  - [x] 根目录参考图片移动到 `docs/assets/`
- [x] 调整 App 外点击行为
  - [x] 自定义 hosting view 过滤 expanded 透明区域 hit-test
  - [x] 点击桌面或其它 App 不再触发收起
- [x] 修复添加歌曲面板被 island 覆盖与主线程阻塞问题
  - [x] 不隐藏、不移动顶部 island，重构为非阻塞异步模式，采用 Swift Concurrency `async/await` 异步置顶文件选择面板，防止主线程卡死
- [x] 播放中 Mascot 音符状态
  - [x] `MascotState.music` 由播放状态触发
  - [x] 共用音符特效保持环绕角色，数量按周期在 4 到 6 个之间变化
  - [x] 音符位置按周期错位变化，不引入音乐业务逻辑
- [x] 收起态右侧区域改为音乐活动指示，展开后恢复静音 / 设置 / 退出三个按钮
- [x] 代码全量重构与性能美学优化 (Premium Optimization)
  - [x] 重构 `MusicTimelineSlider` 滑块手势交互：拖拽中更新局部状态和临时时间文字，仅在松开时触发 `AVPlayer.seek(to:)`，解决高频 seek 噪音和掉帧问题
  - [x] 升级配色体系，替换纯红、绿、蓝、橙基色为荧光绿、珊瑚红、琥珀金和靛蓝，极大提升视觉质感
  - [x] 优化并全局修复 `.onHover` 指针改变逻辑：在 `islandContainer` 以及 `MusicExpandedView` 根容器上统一挂载 arrow 指针设置，彻底杜绝文本悬停处出现 I-beam 输入状态光标的问题
- [x] 全员 7 款角色形象高级感矢量重塑 (Mascot High-Fidelity Vector Redesign)
  - [x] `RobotMascotView` 重塑：金属反光舱体、镜面玻璃高光、眼睛频谱仪跳动、胸口反应堆与浮空双手
  - [x] `SleepCapsuleMascotView` 重塑：焦糖柴犬小狗、下垂垂耳摆动、项圈小金铃铛发光与听歌快乐吐舌
  - [x] `CatMascotView` 重塑：蜜桃白毛橘猫、蝴蝶结、胡须动态颤动与大瞳孔随节拍缩放
  - [x] `GhostMascotView` 重塑：发光果冻半透明渐变、粉红腮红红晕、双手浮空与底部流体数学正弦水波
  - [x] `NoodleMascotView` 重塑：蓬松云朵羊毛、盘旋黄金羊角与听歌“重低音音响式”羊毛收缩膨胀
  - [x] `BirbMascotView` 重塑：球形青鸟饱满径向渐变、唱歌小喙与极速蜂鸟翅膀骨骼旋转振翼
  - [x] `MoaiMascotView` 重塑：直鼻梁黑曜岩石石像、琥珀深度运算瞳孔与听歌爆笑戴上双色荧光霓虹墨镜狂热跳跃

## 下一步任务

- [ ] 继续观察 compact / expanded 顶部贴边和单层 island 壳体是否稳定
- [ ] Music 后续阶段再评估 metadata、专辑封面或系统媒体键
- [ ] 如继续扩展 Mascot，保持 `MascotKind` + `MascotView` + `Characters/` 的现有模式

## 约束

- 每次只做一个明确的小任务
- 不做大规模重构
- 不删除用户未确认要删除的源码文件
- SwiftUI 为主，必要时再补 AppKit
- Build / xcodebuild 规则以 `docs/ARCHITECTURE.md` 为准
- 新功能涉及系统 API、文件、播放器、权限或通知时，能力放入 Service / Controller，不写进 View
- 主 View 只负责组合 UI 和转发用户意图，ViewModel 负责状态和动作，Model 负责数据结构
- 文件职责、数据流、注释规则以 `docs/ARCHITECTURE.md` 为准
- 视觉和交互规则以 `docs/DESIGN.md` 为准

## 验收清单

- [x] App 启动后收起态 compact 仍显示 Mascot / chevron / 右侧音乐活动指示
- [x] 播放中收起态 compact 仍显示 Mascot / chevron / 右侧音乐活动指示，不显示音乐控制
- [x] expanded 显示 mini player：曲名、播放状态、播放 / 暂停、添加歌曲、播放模式、播放列表、进度条、当前时间 / 总时长
- [x] 播放列表支持添加本地文件和目录
- [x] 播放列表支持拖拽添加本地音频文件和文件夹
- [x] 播放列表支持轻量持久化，重启后恢复列表、当前索引、播放模式、文件访问权限和上次播放进度
- [x] 恢复后 seek 到上次位置并继续播放
- [x] 播放列表支持点击播放、删除单项、清空列表、自动下一首、上一首 / 下一首
- [x] 播放模式可在顺序、单曲循环、列表循环、随机之间切换
- [x] 快速启动支持外部拖入、按落点插入、已有 App 拖动重排，最多 9 个
- [x] 收起态右侧显示音乐活动指示，展开后恢复三个工具按钮
- [x] `ContentView.swift` 不直接操作 `AVPlayer`
- [x] `IslandViewModel.swift` 不包含音乐业务逻辑
- [x] `AVPlayer` 只在 `MusicPlayerController.swift` 中出现
- [x] `NSOpenPanel` 只在 `MusicFilePicker.swift` 中出现
- [x] `FloatingPanelController.swift` 的窗口定位和展开 / 收起逻辑保持独立
- [x] Mascot 动画文件不承担音乐业务逻辑
- [x] 本次涉及的复杂逻辑和关键代码已按有价值优先标准补充中文注释

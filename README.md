# NookFlow

NookFlow 是一个使用 `SwiftUI` + `AppKit` 开发的 macOS 原生桌面应用，目标是在屏幕顶部中央提供一个类似 MacBook 刘海 / Dynamic Island 的交互式状态面板。

当前项目已完成本地音乐 mini player 播放列表阶段，当前重点验证以下能力：

- 作为 macOS menu bar app 启动
- 在屏幕顶部中央显示一个 floating panel
- 默认显示 compact island
- 点击后展开为更大的信息面板
- 使用本地音乐文件、目录、拖拽导入和持久化播放列表驱动 expanded mini player

## 文档索引

- `docs/ARCHITECTURE.md`：架构分层、文件职责、数据流、开发准则和注释执行规则
- `docs/DESIGN.md`：产品定位、视觉规范、交互规范和动画方向
- `docs/TASKS.md`：当前阶段、正在做的任务、下一步任务和验收清单
- `docs/PROMPTS.md`：可复用的中文协作提示词模板

## 当前能力

- menu bar app 基础入口
- 顶部 floating panel
- 基础贴顶定位
- compact / expanded 切换
- compact Mascot / chevron / 右侧音乐活动指示，expanded 恢复工具按钮布局
- 自定义 notch-style compact 外轮廓
- expanded mini player 布局
- 快速启动 App 面板：支持外部拖入、按落点插入、拖动重排和持久化顺序，最多 9 个
- 深色风格黑色面板
- 两阶段展开动画：先扩 AppKit 窗口，再展开 SwiftUI 壳体
- 内部点击收起完成后窗口缩回 compact 尺寸
- expanded 窗口透明区域通过 hosting view hit-test 过滤，避免鼠标遮挡桌面或其它 App
- 多显示器基础策略：优先在鼠标所在屏幕显示
- shoulder 肩部半径跟随展开 / 收起动画平滑过渡（compact 5 → expanded 10）
- NotchIslandShape 通过 AnimatablePair 实现形状参数插值动画
- Mascot 角色动画系统（Canvas + TimelineView，idle / working / music 三种状态，7 个角色）
- Mascot 设置页（macOS 原生面板风格，纯角色选择器）
- `@AppStorage` 持久化：mascotKind；ContentView 仍保留 mascotEnabled / mascotSize 读取兼容
- 右侧工具按钮组：展开后显示静音、打开设置、退出 NookFlow
- 本地音乐 mini player：混合添加文件 / 目录、拖拽添加文件 / 文件夹、播放、暂停、上一首 / 下一首、顺序 / 单曲循环 / 列表循环 / 随机模式、自动下一首、播放列表预览、点击播放、删除单项、清空列表、进度和时间显示
- 播放列表轻量持久化：保存音频文件 URL、只读 security-scoped bookmark、当前选中索引、播放模式和上次播放进度；启动后恢复列表并 seek 到上次位置继续播放

## 运行方式

1. 用 Xcode 打开工程。
2. 选择 `NookFlow` scheme。
3. 直接运行。
4. 运行后应用会出现在菜单栏，并在屏幕顶部显示 island 面板。

## 当前交互

- 默认状态显示空 compact island
- 点击 compact island 可展开
- 再次点击 compact 顶栏或点击 expanded 空白区域可收起；点击桌面或其它 App 不会收起
- 收起态左侧显示 Mascot 角色（收起 idle，展开 working），中间保留展开箭头，右侧显示音乐活动指示
- 展开后右侧恢复静音 / 设置 / 退出三个工具按钮；播放中 Mascot 使用 music 状态和 4 到 6 个环绕音符特效
- expanded 状态显示 mini player：曲名、状态、播放 / 暂停、添加歌曲、播放模式、上一首 / 下一首、播放列表区域、进度条、当前时间 / 总时长
- 未添加歌曲时，expanded 仍保留播放列表区域并显示 0 首状态
- 播放列表区域支持拖拽本地音频文件或文件夹添加到当前列表
- 播放列表行支持点击播放、删除、序号显示、蓝色低透明 hover / 选中背景，并显式使用箭头光标
- 右侧工具按钮组仅在展开后显示，包含：静音状态切换、打开设置、退出 NookFlow
- 菜单栏 "Settings..." 打开 Mascot 角色选择窗口
- 设置窗口支持切换角色

## 下一步建议

- 继续保持顶部贴边、单层 island 壳体和展开 / 收起动画稳定
- Music 后续阶段再评估 metadata、专辑封面、系统媒体键或更完整资料库能力

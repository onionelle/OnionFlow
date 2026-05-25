# DESIGN

## 产品定位

NookFlow 是一个面向 macOS 的 notch-style / Dynamic Island 风格本地音乐 mini player。

目标不是做普通通知条，而是做一个贴合屏幕顶部边缘、接近 MacBook 刘海交互感的原生悬浮音乐控制组件。

## 设计目标

- 顶部中央常驻
- 视觉上贴合屏幕顶部
- 默认状态简洁克制
- 当前阶段支持本地播放列表控制
- 整体接近 macOS 原生质感

## 形态定义

### Compact

用于常驻展示核心状态。

特点：

- 单行信息
- 顶部贴边
- 黑色 notch-style 外形
- 不像 notification banner

布局（从左到右）：

- 左侧 Mascot 角色区域（32pt × 32pt，compact 距左边缘 10pt，expanded 顶栏距左边缘 15pt）
- 中间展开箭头（居中）
- 右侧收起态音乐活动指示 / 展开态工具按钮组（compact 距右边缘 14pt，expanded 顶栏距右边缘 20pt）
- Mascot 不侵占中间箭头区域
- 收起态右侧音乐活动指示不侵占中间箭头区域；展开态工具按钮组同样不侵占中间箭头区域

建议内容：

- 收起态：左侧 Mascot 角色动画（收起 → idle，展开 → working）、中间展开箭头、右侧音乐活动指示
- 展开态：左侧 Mascot music 状态动画（4 到 6 个环绕音符按周期错位变化）、中间展开箭头、右侧工具按钮组

### Expanded

当前用于显示本地音乐 mini player。点击 expanded 空白区域会收起 island。

当前显示：

- 当前曲名
- 播放状态
- 播放 / 暂停
- 添加本地文件 / 音乐目录
- 上一首 / 下一首
- 顺序 / 单曲循环 / 列表循环 / 随机播放模式
- 当前播放列表
- 空列表状态
- 进度条
- 当前时间 / 总时长

## 视觉规范

### 背景

- 主背景接近纯黑
- 建议：`Color.black.opacity(0.94)`
- 可加入非常轻的顶部高光

### 阴影

- expanded 状态使用较明确的黑色阴影：`Color.black.opacity(0.8)`，`radius: 5`，`x: 0`，`y: 0`
- compact 状态不显示阴影
- 阴影跟随 island 展开 / 收起状态同步变化

### 圆角

- 顶部：应与顶部屏幕边缘融合
- 底部：使用较大圆角
- 当前底部圆角：compact `15`，expanded `40`

### 形状要求

- 不能是普通 `RoundedRectangle`
- 优先采用 notch-style 自定义 `Shape`
- 目标是：
  - top attached
  - flat top edge
  - concave shoulder corners
  - rounded bottom corners
- 肩部半径跟随展开状态动画过渡（compact 5 → expanded 10）
- 底部圆角同样跟随状态变化（compact 15 → expanded 40）

## 交互规范

### 基础交互

- 点击 compact 状态栏展开
- 再次点击 compact 顶栏或点击 expanded 空白区域收起；点击桌面或其它 App 不收起
- 展开采用两阶段动画：先扩大 AppKit 窗口，再展开 SwiftUI 壳体
- 内部点击收起时先收回 SwiftUI 壳体，再把 AppKit 窗口缩回 compact
- expanded 透明区域必须透传鼠标事件，避免阻挡桌面或其它 App

### 音乐播放交互

- 收起态 compact 保持 Mascot / chevron / 右侧音乐活动指示
- 选择本地音乐并播放后，收起态 compact 仍保持 Mascot / chevron / 右侧音乐活动指示
- 所有音乐控制只放在 expanded mini player 中，compact 不放播放 / 暂停、进度等音乐控制
- expanded mini player 支持混合添加本地文件和目录、拖拽添加本地文件和文件夹、播放 / 暂停、上一首 / 下一首、切换顺序 / 单曲循环 / 列表循环 / 随机模式、点击播放列表项、删除列表项、清空列表和拖动进度
- expanded mini player 的播放器按钮、播放列表播放按钮、删除按钮和清空按钮都提供悬停提示词
- expanded mini player 在没有加载列表时仍保留播放列表区域，空态需明确提示可以拖拽歌曲或文件夹
- 快速启动 App 面板支持外部拖入、按落点插入、已有 App 拖动重排和顺序持久化，最多保留 9 个
- 当前阶段不做最近曲目、专辑封面、metadata 读取、系统媒体键或复杂资料库

### 右侧工具按钮交互

- 右侧工具按钮只在展开后显示
- 静音按钮只切换 NookFlow 内部播放器静音状态，不修改系统音量
- 设置按钮打开现有 Mascot 设置页
- 退出按钮直接退出 NookFlow
- 按钮 hover 时只增强背景和描边，不做缩放

### Mascot 设置页交互

- 菜单栏 "Settings..." 打开设置窗口
- 角色卡片点击切换，选中态：蓝色 1.5pt 描边 + checkmark.circle.fill
- 当前角色均可点击选择，不再显示 Coming Soon 禁用状态
- 当前设置页是纯 Mascot 角色选择器，不再显示 Enable Toggle 和 Size Picker
- 角色列表使用 ScrollView，隐藏滚动条，卡片保持紧凑高度
- 窗口居中，层级高于顶部 island，点击外部自动关闭

### 播放列表交互

- 播放列表项点击播放对应曲目
- 播放列表项左侧显示序号，当前播放项使用蓝色序号和曲名
- 播放列表项不使用行间虚线分隔，依靠文字层级、hover / 选中背景和外层边界区分行
- 播放列表项 hover / 选中背景使用蓝色低透明整行矩形背景，不带圆角
- 播放列表项显式使用箭头光标，避免停在文字上显示输入光标
- 删除按钮 hover 时显示红色背景提醒，点击删除对应曲目
- 播放列表文字使用细体（regular 字重）
- 播放列表区域保持低透明背景和虚线边框；空播放列表状态额外显示拖拽提示和辅助说明
- 拖拽文件或文件夹进入播放列表区域时显示低透明蓝色填充和虚线描边，只作为 drop target 提示

### 后续交互方向

- Mascot 点击交互（当前阶段预留，不绑定动作）

## 动画建议

- 使用短时长 spring 动画
- 展开时优先做高度和透明度过渡
- 避免夸张缩放

## 技术约束

文件职责、数据流和模块边界以 `docs/ARCHITECTURE.md` 为准；本文档只保留会影响产品体验的设计约束。

### Mascot

- 纯 SwiftUI Canvas + TimelineView，不引入 Lottie / SpriteKit / PNG sprite sheet
- 不创建 MascotViewModel，状态由 `viewModel.isExpanded` 和 `musicViewModel.state` 直接映射
- MascotView 使用 `.allowsHitTesting(false)`，不阻断 compactBar 点按
- 默认尺寸 32pt，设置页当前不提供尺寸切换
- 角色视觉采用高阶矢量曲线、线性与径向渐变、高透镜面反光质感以及外发光阴影特效，在 32pt 极致物理限制下保留精细的微观反光、动态骨骼颤动与极佳的可识别度。

## 当前关注点

- 本地音乐 mini player 播放列表阶段已完成基础接入
- 当前阶段支持单曲、多曲、目录和拖拽文件 / 文件夹添加到当前播放列表，并在下次启动恢复列表、播放模式和上次播放进度
- expanded 状态保持在同一个 island 壳体内
- 后续扩展前继续保持播放控制集中在 expanded mini player

## 设计优先级

1. 保持现有 compact 形状和顶部贴边关系
2. 未播放时保留 Mascot 识别度
3. 音乐控制全部集中在 expanded mini player
4. expanded mini player 信息清晰
5. 保持一个 island 壳体，不做卡片嵌套

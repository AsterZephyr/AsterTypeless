# macOS SwiftUI 架构

## 目标

把 Typeless 开源版重构成一个纯 macOS 原生应用：

- UI 层使用 `SwiftUI`
- 系统能力层使用 `AppKit + Accessibility + CoreGraphics`
- 工程与发布层使用 `Xcode macOS App target`
- 输入体验以“小浮窗 + 全局触发 + 当前输入框写回”为核心

这份文档替代旧的 Electron / React / Node 设计。旧技术栈已经从主工程中移除。

## 分层

### 1. App 层

入口文件：

- [TypelessMacApp.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/TypelessMacApp.swift)
- [TypelessAppModel.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/App/TypelessAppModel.swift)

职责：

- 管理首页、设置页、浮窗共享状态
- 组织权限刷新、录音状态、写回动作
- 聚合统计数据和首页展示数据

### 2. Feature 层

首页：

- [HomeView.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Features/Home/HomeView.swift)
- [DashboardCards.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Features/Home/DashboardCards.swift)

浮窗：

- [FloatingBarView.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Features/FloatingBar/FloatingBarView.swift)
- [FloatingBarWindowManager.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Features/FloatingBar/FloatingBarWindowManager.swift)
- [AudioPulseView.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Features/FloatingBar/AudioPulseView.swift)

设置：

- [SettingsView.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Features/Settings/SettingsView.swift)

职责：

- 只做界面表达和轻交互
- 不直接接系统 API
- 保持首页是概览视图，浮窗才是主工作流

### 3. Services 层

本地数据：

- [TranscriptStore.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Services/TranscriptStore.swift)

音频：

- [AudioInputMonitor.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Services/AudioInputMonitor.swift)

系统桥：

- [AccessibilityBridge.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Services/AccessibilityBridge.swift)
- [HotkeyBridge.swift](/Users/hxz/code/typeless-open-cleanroom/Sources/TypelessMacApp/Services/HotkeyBridge.swift)

职责：

- 处理麦克风权限、音量采样、辅助功能、输入监听
- 读取当前前台 App、当前选中内容和上下文
- 尝试把最终文本写回当前焦点输入框

### 4. 工程壳

工程壳相关文件：

- [project.yml](/Users/hxz/code/typeless-open-cleanroom/project.yml)
- [Info.plist](/Users/hxz/code/typeless-open-cleanroom/App/Config/Info.plist)
- [TypelessMac.entitlements](/Users/hxz/code/typeless-open-cleanroom/App/Config/TypelessMac.entitlements)
- [generate_xcode_project.sh](/Users/hxz/code/typeless-open-cleanroom/Scripts/generate_xcode_project.sh)

职责：

- 承接从原型到正式 App target 的迁移
- 管理 bundle id、权限文案、资源和签名入口
- 为后续 Xcode Archive、notarization 和发布留接口

## 当前状态机

### 首页

首页承载四类信息：

1. 核心设置摘要
2. 口述报告统计
3. 个人画像
4. 最近转录与反馈

首页不承担实时输入动作，避免再次长成 dashboard 式操作台。

### 浮窗

浮窗是高频入口，目标状态机如下：

1. `idle`
2. `armed`
3. `recording`
4. `processing`
5. `ready-to-insert`
6. `dismissed`

目前已经覆盖：

- `armed`
- `recording`
- `ready-to-insert`
- `dismissed`

后续要补：

- `Fn` 按下即进入 `recording`
- `Fn` 松开后自动停止并进入 `processing`

## 为什么不用旧架构

旧的 Electron 方案虽然便于快速验证，但会持续带来这几个问题：

- 界面气质像网页
- 信息层级过重
- 浮窗不够原生
- 系统能力和界面层割裂

对于 Typeless 这种输入法级工具，真正合适的技术路线是：

- 原生窗口
- 原生权限模型
- 原生系统事件
- 原生 Accessibility 写回
- 原生打包、签名与发布链路

## 后续迭代顺序

1. 先把当前原型迁到 Xcode macOS App target。
2. 把浮窗的实时音频反馈继续打磨细。
3. 把 `Fn` 的按下、长按、松开语义做完整。
4. 接 `Deepgram + OpenAI` 真正的语音链路。
5. 把首页进一步收窄成更克制的 macOS 概览页。
6. 视需要把本地 JSON store 升到 SQLite 或 SwiftData。

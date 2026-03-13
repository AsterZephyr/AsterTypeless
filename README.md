# TypelessMac

一个只面向 macOS 的 Typeless 开源版骨架。

这次重构已经把之前的 Electron / React / Node 运行时全部移除，仓库现在只保留：

- `SwiftUI`：首页、设置页、浮动输入条
- `AppKit / Accessibility / CoreGraphics`：全局触发、权限、焦点输入框读取与写回
- `Xcode macOS App target`：后续用于打包、签名、权限、资源和发布
- `本地持久化`：先用 JSON store 承接首页统计与最近转录
- `研究文档`：保留 clean-room 研究和 UX 审计，方便后续继续演进

## 当前方向

项目现在不再做“网页壳桌面端”，而是直接按原生 macOS 工具来组织：

- 首页是概览 Hub，不承担高频输入动作
- 高频输入交给小浮窗
- 浮窗要能显示说话时的实时状态
- 目标体验是 `Fn` 唤起、说完即写回当前输入框

当前已经确认的正式路线：

1. `SwiftUI` 做界面
2. `AppKit + AXUIElement + CGEventTap` 做系统桥
3. `Xcode macOS App target` 做打包、签名、权限、资源和发布

## 目录结构

```text
App/
  Config/             Info.plist / entitlements
  Resources/          Asset Catalog 等资源

Sources/TypelessMacApp/
  App/                应用状态与主入口状态机
  Features/Home/      首页概览
  Features/FloatingBar/ 浮动输入条
  Features/Settings/  设置页
  Models/             领域模型
  Services/           音频、权限、Accessibility、热键、本地存储
  Support/            视觉主题与通用样式

Config/
  Runtime.sample.plist  预留给后续 provider / key 配置

Scripts/
  generate_xcode_project.sh

project.yml           Xcode project spec

docs/
  research.md
  ux-audit-2026-03-13.md
  architecture-macos-swiftui.md
  todo-macos-native.md
```

## 当前已实现

- 原生 `SwiftUI` 主窗口
- 原生 `SwiftUI` 设置页
- 原生 `NSPanel` 浮动输入条
- 麦克风权限检测与实时音量采样
- 音频电平平滑值与更紧凑的实时抖动反馈
- `Fn` 按下开始、松开结束的原型状态机
- Accessibility 权限检测
- 当前前台 App 与焦点元素上下文读取
- 选中文本读取
- 文本写回焦点输入框
- 失败时回落到剪贴板粘贴
- 本地口述记录、首页统计、个人画像占位数据

## 当前还没做完

- 真正的 `OpenAI + Deepgram` 网络调用链
- `Fn` 的 `tap / hold / double tap` 完整语义
- 跨更多 macOS App 的稳定写回兼容性
- 浮窗实时音频反馈继续打磨成更接近 Typeless 的形态
- 首页更进一步收紧成 Typeless 那种更克制的原生信息架构

## 运行方式

### 1. 用 Xcode 打开

现在最推荐直接打开 [TypelessMac.xcodeproj](/Users/hxz/code/typeless-open-cleanroom/TypelessMac.xcodeproj)。

[Package.swift](/Users/hxz/code/typeless-open-cleanroom/Package.swift) 仍然保留，主要用于快速本地验证和轻量编译。

仓库里已经补了 App target 所需的外围件：

- [project.yml](/Users/hxz/code/typeless-open-cleanroom/project.yml)
- [TypelessMac.xcodeproj](/Users/hxz/code/typeless-open-cleanroom/TypelessMac.xcodeproj)
- [Info.plist](/Users/hxz/code/typeless-open-cleanroom/App/Config/Info.plist)
- [TypelessMac.entitlements](/Users/hxz/code/typeless-open-cleanroom/App/Config/TypelessMac.entitlements)
- [generate_xcode_project.sh](/Users/hxz/code/typeless-open-cleanroom/Scripts/generate_xcode_project.sh)

本机在 2026-03-14 已经验证通过：

- `swift build`
- `xcodebuild -project TypelessMac.xcodeproj -scheme TypelessMac -configuration Debug -sdk macosx build`

### 2. 命令行构建

```bash
cd /Users/hxz/code/typeless-open-cleanroom
swift build
```

或者直接走 Xcode 工程：

```bash
xcodebuild -project /Users/hxz/code/typeless-open-cleanroom/TypelessMac.xcodeproj -scheme TypelessMac -configuration Debug -sdk macosx build
```

当前这台机器的 Xcode 环境已经在 2026-03-14 修复并验证通过。上面的两条构建命令都可以正常跑完。

## 设计原则

- 只做 macOS，不再考虑跨平台桌面壳
- 首页做概览，不做重操作台
- 高频动作收进浮窗
- 功能层优先原生化，再谈 provider 接入
- 尽量避免“大而全”的 dashboard 观感

## 后续技术路线

1. 继续打磨正式的 Xcode App target，并补 Archive / 发布链路。
2. 把实时音频反馈做成 Typeless 风格的小体积生命体征。
3. 把 `Fn` 触发从当前原型推进到完整的 `tap / hold / double tap` 语义。
4. 接入 `Deepgram + OpenAI` 主链路。
5. 把首页继续压缩成更像 macOS 菜单栏工具的概览页。

## 保留文档

- clean-room 研究记录：[research.md](/Users/hxz/code/typeless-open-cleanroom/docs/research.md)
- UX 审计记录：[ux-audit-2026-03-13.md](/Users/hxz/code/typeless-open-cleanroom/docs/ux-audit-2026-03-13.md)
- 新架构说明：[architecture-macos-swiftui.md](/Users/hxz/code/typeless-open-cleanroom/docs/architecture-macos-swiftui.md)
- 原生路线 TODO：[todo-macos-native.md](/Users/hxz/code/typeless-open-cleanroom/docs/todo-macos-native.md)

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
- 音频电平平滑值，可直接驱动“说话时抖动”的反馈条
- `Fn` 触发监听骨架和 Input Monitoring 权限检测
- Accessibility 权限检测
- 当前前台 App 与焦点元素上下文读取
- 选中文本读取
- 文本写回焦点输入框
- 失败时回落到剪贴板粘贴
- 本地口述记录、首页统计、个人画像占位数据

## 当前还没做完

- 真正的 `OpenAI + Deepgram` 网络调用链
- `Fn` 长按 / 按下即说 的完整状态机
- 跨更多 macOS App 的稳定写回兼容性
- 浮窗实时音频反馈的视觉打磨
- 首页更进一步收紧成 Typeless 那种更克制的原生信息架构

## 运行方式

### 1. 用 Xcode 打开

最推荐直接在 Xcode 中打开根目录下的 [Package.swift](/Users/hxz/code/typeless-open-cleanroom/Package.swift)。

当前的 `Package.swift` 更像原型入口。下一步会迁成正式的 Xcode macOS App target。

### 2. 命令行构建

```bash
cd /Users/hxz/code/typeless-open-cleanroom
swift build
```

如果本机的 Xcode / Command Line Tools 没有配好，`swift build` 可能会失败。这是系统工具链问题，不是旧 Node 依赖问题。

根据 2026-03-13 本机实际排查，当前环境已确认：

- `/Applications/Xcode.app` 不存在或不可用
- `xcode-select -p` 仍指向 `CommandLineTools`
- `swift --version` 是 `Apple Swift 6.2.4`
- 当前 SDK / CLT 仍有 `6.2.3` 痕迹
- `xcodebuild -version` 无法执行
- 直接类型检查会报 `SwiftBridging` 重复定义和 SDK / 编译器不匹配

## 设计原则

- 只做 macOS，不再考虑跨平台桌面壳
- 首页做概览，不做重操作台
- 高频动作收进浮窗
- 功能层优先原生化，再谈 provider 接入
- 尽量避免“大而全”的 dashboard 观感

## 后续技术路线

1. 把工程从 `Swift Package` 原型迁到 `Xcode macOS App target`。
2. 把实时音频反馈做成 Typeless 风格的小体积生命体征。
3. 把 `Fn` 触发补成按下即说、松开即停。
4. 接入 `Deepgram + OpenAI` 主链路。
5. 把首页继续压缩成更像 macOS 菜单栏工具的概览页。

## 保留文档

- clean-room 研究记录：[research.md](/Users/hxz/code/typeless-open-cleanroom/docs/research.md)
- UX 审计记录：[ux-audit-2026-03-13.md](/Users/hxz/code/typeless-open-cleanroom/docs/ux-audit-2026-03-13.md)
- 新架构说明：[architecture-macos-swiftui.md](/Users/hxz/code/typeless-open-cleanroom/docs/architecture-macos-swiftui.md)
- 原生路线 TODO：[todo-macos-native.md](/Users/hxz/code/typeless-open-cleanroom/docs/todo-macos-native.md)

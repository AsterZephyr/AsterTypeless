# macOS Native TODO

## 已确认的正式技术路线

1. `SwiftUI` 做界面
2. `AppKit + AXUIElement + CGEventTap` 做系统桥
3. `Xcode macOS App target` 做打包、签名、权限、资源和发布

## 近期优先级

### P0 工程形态

- `Xcode macOS App target` 已生成并验证 Debug 构建
- 已补 `Info.plist` 骨架
- 已补 `.entitlements` 骨架
- 已补 `project.yml` 和生成脚本
- 配置正式 App Icon、bundle identifier、权限文案
- Debug 构建已通过
- 跑通 Archive 和后续发布链路

### P0 输入主链路

- `Fn` 按下即说、松开即停的原型已接通
- 明确 `tap / hold / double tap` 的交互语义
- 完善 Input Monitoring 权限引导
- 完善 Accessibility 权限引导

### P0 浮窗体验

- 浮窗已切成“录音时更紧凑、停下后展开”的布局
- 音频电平反馈已升级到实时抖动原型
- `idle / armed / recording / processing / ready` 状态机已接通原型
- 继续往 Typeless 的浮窗质感打磨

### P1 跨 App 能力

- 建立插入兼容矩阵
- 优先验证 Cursor、VS Code、Slack、Notion、Chrome、Arc、JetBrains
- 区分 AX 直接写回和剪贴板回退两条路径

### P1 模型接入

- 接 `Deepgram` 做语音识别
- 接 `OpenAI` 做 rewrite / orchestration
- 接流式状态到浮窗

### P1 首页信息架构

- 首页只保留概览，不承载高频操作
- 设置摘要收紧成状态卡片
- 口述报告维持四项指标
- 个人画像做成更稳定的报告区
- 转录记录与反馈入口继续拆分

## 当前本机构建状态

2026-03-14 已验证：

- `swift build` 通过
- `xcodebuild -project TypelessMac.xcodeproj -scheme TypelessMac -configuration Debug -sdk macosx build` 通过

## 备注

当前仓库已经不再依赖旧 Electron / React / Node 栈。
后续所有桌面端能力都以 macOS 原生工程为主线推进。

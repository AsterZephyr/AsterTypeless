# macOS Native TODO

## 已确认的正式技术路线

1. `SwiftUI` 做界面
2. `AppKit + AXUIElement + CGEventTap` 做系统桥
3. `Xcode macOS App target` 做打包、签名、权限、资源和发布

## 近期优先级

### P0 工程形态

- 从 `Package.swift` 原型迁移到正式的 Xcode macOS App target
- 增加 `Info.plist`
- 增加 `.entitlements`
- 配置 App Icon、bundle identifier、权限文案
- 跑通本地 Debug 构建和 Archive

### P0 输入主链路

- 完整实现 `Fn` 按下即说、松开即停
- 明确 `tap / hold / double tap` 的交互语义
- 完善 Input Monitoring 权限引导
- 完善 Accessibility 权限引导

### P0 浮窗体验

- 把音频电平反馈做成更像 Typeless 的实时抖动小窗口
- 缩小浮窗信息密度，保留最关键的状态提示
- 明确 `idle / armed / recording / processing / ready` 状态机

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

## 当前本机构建问题

根据 2026-03-13 本机实际命令输出，当前环境问题如下：

- `/Applications/Xcode.app` 不存在或不可用
- `xcode-select -p` 指向 `CommandLineTools`
- `xcodebuild -version` 无法运行，因为没有完整 Xcode
- `swift --version` 显示为 `Apple Swift 6.2.4`
- SDK 报错显示当前 CLT / SDK 仍有 `Swift 6.2.3` 痕迹
- `/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap`
  和
  `/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap`
  同时存在，触发 `SwiftBridging` 重复定义

## 本机构建修复建议

1. 安装完整 Xcode
2. 切换 active developer directory 到 Xcode
3. 跑 `xcodebuild -runFirstLaunch`
4. 再确认 `swift --version` 与 SDK 版本一致
5. 如仍异常，再清理并重装 Command Line Tools

## 备注

当前仓库已经不再依赖旧 Electron / React / Node 栈。
后续所有桌面端能力都以 macOS 原生工程为主线推进。

# AsterTypeless UI / UX Research

日期: 2026-03-14

目标: 基于 Typeless 公开资料和 Apple 官方 macOS 设计资料，继续收紧 `AsterTypeless` 的 demo 方向，让它更像一个原生的 macOS 输入工具，而不是网页式桌面壳。

## 核心结论

### 1. Typeless 的第一性原理不是“大主页”，而是“跨 App 的原生输入动作”

从 Typeless 官方快速开始页可以确认，它的核心体验是:

- 光标在任意文本框中
- 按住默认热键 `fn`
- 听到交互音或看到白色条形开始移动后开始说话
- 松开后把格式化后的文本直接插回当前输入框
- `esc` 用于取消
- `fn + space` 进入 hands-free

这说明 Typeless 的主产品不是 dashboard，而是一个常驻系统层、跨 App、生效路径极短的输入工具。

### 2. 音频反馈不是装饰，而是状态确认机制

Typeless 官方文档明确提到“听到交互音或看到白色条形开始移动后再开始说话”。这意味着小浮窗里的动态条形不是视觉点缀，而是录音状态、听写激活和用户信心反馈的一部分。

### 3. Typeless 正在把“个人能力”做成个性化能力，而不是配置表单

Typeless 2025-12-24 的 v0.9.0 更新里明确写了个性化能力会自然适应用户语气，支持 formal / casual / concise / detailed，并且可以在 `Settings > Personalization` 里关闭。

这意味着个人能力区不应该长成复杂配置页，而应该更像:

- 画像摘要
- 当前倾向
- 是否开启 personalization
- 最近学习到的风格趋势

### 4. macOS 原生路线里，Menu Bar 是高频入口，不是附属品

Apple 官方对 `MenuBarExtra` 的定义非常直接:

- 适合在 app 不处于前台时，仍然提供常用功能
- 适合 utility app
- 可与主窗口、设置窗口共同组成完整体验

对于 `AsterTypeless` 这种“跨 App 输入工具”，Menu Bar 应该是正式入口之一，而不是以后再加的辅助功能。

### 5. macOS 原生窗口应该收拢成“单主窗 + 设置 + 浮窗 + 菜单栏”

Apple 在 SwiftUI scene 体系里建议:

- `Window` 适合表达全局唯一状态
- `Settings` 负责应用内设置
- `MenuBarExtra` 负责常驻可访问能力

这和 Typeless 的产品形态高度一致。对我们来说，比起继续做大而全的首页，更合适的是:

- 一个唯一的主窗口，用来承载概览、历史、画像
- 一个系统标准 Settings 窗口
- 一个常驻 Menu Bar 入口
- 一个极短路径的浮动输入条

## 对当前 demo 的直接指导

### 立即要做

1. 把 app 增加 `MenuBarExtra`
2. 把主窗口从“网页式工作台”继续收成更原生的概览窗
3. 把个人能力区改成“个性化摘要”，不要继续长成配置堆
4. 把浮窗保持成最短路径，不把复杂操作塞进去

### 明确不要做

- 不把首页继续做成 web dashboard
- 不把高频输入动作放回主窗口
- 不把个人能力区做成一堆开关和字段
- 不把跨 App 输入的核心状态藏起来

## 对“个人能力区”的建议结构

### 首页只保留这几块

1. `Dictation Report`
   - 总口述时间
   - 总字数
   - 节省时间
   - 平均语速

2. `Personalization`
   - 当前写作倾向
   - 最近高频场景
   - 建议项

3. `Readiness`
   - 权限
   - Provider 状态
   - 跨 App 样本

4. `History / Feedback`
   - 最近结果
   - 最近写回
   - 最近一次最终文本

## 今晚之后的优化顺序

1. `MenuBarExtra`
2. 单主窗继续原生化
3. 个性化区域更像“能力摘要”
4. 浮窗状态和 hands-free 语义继续细化
5. 明天拿到 API 后再接真实链路

## Sources

- Typeless quickstart: <https://www.typeless.com/zh-cn/help/quickstart/first-dictation>
- Typeless install/setup: <https://www.typeless.com/help/installation-and-setup>
- Typeless personalization release notes: <https://www.typeless.com/help/release-notes/macos/personalized-smarter>
- Typeless pricing/security claims: <https://www.typeless.com/zh-cn/pricing>
- Apple `MenuBarExtra`: <https://developer.apple.com/documentation/swiftui/menubarextra>
- Apple `Scene`: <https://developer.apple.com/documentation/SwiftUI/Scene>
- Apple “Designing for macOS”: <https://developer.apple.com/design/human-interface-guidelines/designing-for-macos>
- Apple WWDC22 “Bring multiple windows to your SwiftUI app”: <https://developer.apple.com/videos/play/wwdc2022/10061/>
- Apple WWDC21 “SwiftUI on the Mac: The finishing touches”: <https://developer.apple.com/videos/play/wwdc2021/10289/>

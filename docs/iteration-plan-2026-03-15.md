# AsterTypeless 功能现状与迭代规划

日期: 2026-03-15

## 当前状态总结

### 已完成 (UI/骨架层)

| 模块 | 状态 | 说明 |
|------|------|------|
| 主窗口布局 | 已完成 | Sidebar + CaptureHero 全屏填充，渐变背景 |
| 浮窗骨架 | 已完成 | FloatingBarView + FnVoiceBarView，NSPanel non-activating |
| 浮窗状态机 | 已完成 | idle / armed / recording / processing / ready |
| 捕获语义 | 已完成 | manual / tapToggle / holdToTalk / handsFree |
| 设置页 | 已完成 | 输入方式、权限、行为、诊断四区 |
| MenuBarExtra | 已完成 | 常驻菜单栏入口 |
| 音频电平采集 | 已完成 | AVAudioEngine 实时 RMS，level / smoothedLevel / isSpeaking |
| Fn 热键监听 | 已完成 | tap / doubleTap / holdStart / holdEnd |
| 回退快捷键 | 已完成 | Carbon 全局热键注册 |
| AX 写回 | 已完成 | AccessibilityBridge 直写 + 剪贴板回退 |
| 本地持久化 | 已完成 | TranscriptStore + InsertionCompatibilityStore (JSON) |
| Runtime 配置 | 已完成 | 从 plist 读取 provider key，区分 mock/partial/providerReady |
| 兼容性记录 | 已完成 | 记录每次写回的 app、方法、成败 |

### 未完成 (核心功能缺口)

以下按优先级排列，是当前 App "看起来像产品但还不能用" 的根本原因。

---

## P0: 必须补齐才能形成最小可用链路

### 1. 真实语音转写 (StreamingTranscriptEngine 目前是 mock)

**现状**: `StreamingTranscriptEngine` 是纯本地占位，不做真实 ASR。它根据一个固定模板字符串，配合 `isSpeaking` 信号逐 token 吐出预设文本。用户说什么完全不影响输出。

**目标**: 接入真实 STT provider，让用户说话后看到自己说的内容。

**方案优先级**:
1. OpenAI gpt-4o-transcribe (最快跑通，单 provider)
2. Deepgram nova-2 streaming (更低延迟，更像 Typeless 体验)

**依赖**: 需要在 `Config/Runtime.local.plist` 中配置真实 API key。

**涉及文件**:
- `Services/StreamingTranscriptEngine.swift` -- 需要重写，接真实 WebSocket/HTTP streaming
- `Services/AudioInputMonitor.swift` -- 需要把 PCM buffer 送给 provider

### 2. 真实文本生成 (QuickActionEngine 目前是 mock)

**现状**: `QuickActionEngine.execute()` 对所有模式都返回固定拼接字符串，不调用任何 LLM。dictate 模式直接原样返回 draft，rewrite/translate/ask 只是加了一句前缀。

**目标**: 接入 OpenAI (或 OpenRouter) 做真实的 dictate/rewrite/translate/ask。

**涉及文件**:
- `Services/QuickActionEngine.swift` -- 需要接 OpenAI chat completion API

### 3. 日夜模式切换 (moon.stars 按钮无功能)

**现状**: `CaptureHeroView` 顶栏的月亮图标 (`moon.stars`) 只是一个静态 `Image`，没有绑定任何 action，也没有 appearance 切换逻辑。

**目标**: 点击后切换 light/dark/auto appearance。

**涉及文件**:
- `Features/Home/CaptureHeroView.swift:58` -- 把静态 Image 改成 Button
- `App/TypelessAppModel.swift` -- 新增 `@Published var appearance` 状态
- `Support/AppTheme.swift` -- 颜色需要适配 dark mode (当前硬编码了大量 RGB 白色/浅色值)

**注意**: 当前整个 UI 的颜色体系全部是硬编码的浅色 RGB 值 (白底、浅灰边框、浅蓝渐变)，没有使用系统语义色。切换到 dark mode 需要系统性地替换颜色定义。这不是一个简单的开关，而是一次主题系统重构。

---

## P1: 补齐后才像一个完整产品

### 4. Sidebar 数据是假数据

**现状**: `TranscriptSidebarView` 显示的 5 条记录 (`ConceptTranscript.samples`) 是硬编码的 mock 数据，不来自真实 `TranscriptStore`。

**目标**: Sidebar 展示真实的 `model.sessions`，按日期分组，支持搜索过滤。

**涉及文件**:
- `Features/Home/TranscriptSidebarView.swift` -- 数据源从 `ConceptTranscript.samples` 切到 `model.sessions`

### 5. Settings 页面功能缺口

**现状**:
- 输入方式的 TextField 改了值不会触发任何实际行为 (只改了 `RuntimeSettings` 的字符串)
- `launchAtLogin` Toggle 不起作用 (没有接 `SMAppService` 或 `ServiceManagement`)
- 麦克风选择没有枚举系统设备列表
- 没有 provider API key 配置入口 (目前只能手动编辑 plist)

**目标**: Settings 的每个控件都应该有真实效果。

### 6. 浮窗 partial transcript 展示

**现状**: 浮窗 `FloatingBarView` 有文本展示区，但因为 `StreamingTranscriptEngine` 是 mock，所以展示的是预设文本而不是用户说的话。

**目标**: 接入真实 STT 后，浮窗应逐字展示用户正在说的内容。

### 7. 录音结束后的确认/编辑流程

**现状**: 录音停止后直接 `runQuickAction()`，没有让用户确认或编辑 transcript 的中间步骤。浮窗的 `ready` 状态虽然有，但没有编辑 UI。

**目标**: 停止录音后进入确认态，用户可以编辑 transcript 再提交。

---

## P2: 产品打磨

### 8. App Icon 和 Bundle ID

**现状**: 没有正式 App Icon (`AppIcon.appiconset` 是空的)，bundle identifier 还是默认值。

### 9. Onboarding / 首次权限引导

**现状**: 没有首次启动引导。用户打开 App 后需要自己去设置里一个个点权限请求按钮。

### 10. 本地数据升级

**现状**: JSON 文件存储，适合原型但不适合长期。

**目标**: 迁移到 SwiftData 或 SQLite。

### 11. Archive / Notarization / 发布

**现状**: 只验证了 Debug build，没有 Archive 和 notarization 流程。

---

## 各文件功能实现度评估

| 文件 | 实现度 | 缺失 |
|------|--------|------|
| AsterTypelessApp.swift | 95% | 基本完整 |
| TypelessAppModel.swift | 70% | 逻辑框架完整，但 quickAction/transcript 都走 mock |
| HomeView.swift | 90% | 布局已修复，缺 dark mode 适配 |
| CaptureHeroView.swift | 80% | moon.stars 按钮无功能 |
| TranscriptSidebarView.swift | 40% | 全部假数据 |
| DashboardCards.swift | 10% | 已写但未接入 HomeView |
| ReadinessCard.swift | 10% | 已写但未接入 HomeView |
| FloatingBarView.swift | 70% | UI 完整，数据是 mock |
| FnVoiceBarView.swift | 70% | 同上 |
| SettingsView.swift | 60% | UI 完整，多数控件无真实效果 |
| MenuBarStatusView.swift | 60% | 基本可用，部分按钮无效 |
| StreamingTranscriptEngine.swift | 5% | 纯 mock，不做真实 ASR |
| QuickActionEngine.swift | 5% | 纯 mock，不调 LLM |
| AudioInputMonitor.swift | 90% | 音频采集完整，缺送 buffer 给 provider |
| AccessibilityBridge.swift | 80% | 核心逻辑完整，需要更多 App 兼容测试 |
| HotkeyBridge.swift | 85% | 基本可用，边界 case 需打磨 |
| FallbackShortcutBridge.swift | 80% | Carbon 热键已接，格式校验可加强 |
| RuntimeConfigService.swift | 90% | 已完成 |
| TranscriptStore.swift | 90% | 已完成 (JSON) |
| InsertionCompatibilityStore.swift | 90% | 已完成 (JSON) |
| AppTheme.swift | 50% | 缺 dark mode，大量颜色硬编码在各 View 里而非统一管理 |

---

## 建议迭代顺序

### Sprint 1: 打通真实语音链路 (最高优先级)

1. 配置真实 API key 到 `Config/Runtime.local.plist`
2. 重写 `StreamingTranscriptEngine` 接入真实 STT
3. 重写 `QuickActionEngine` 接入真实 LLM
4. 验证: 说话 -> 浮窗出文字 -> 写回目标 App

### Sprint 2: 数据层真实化

1. Sidebar 切换到真实 sessions 数据源
2. 录音后增加确认/编辑步骤
3. Dashboard 卡片 (DashboardCards / ReadinessCard) 接入主页或做成可切换 tab

### Sprint 3: 主题与设置

1. 建立统一的颜色 token 系统 (替代散落的 RGB 硬编码)
2. 适配 dark mode
3. 补齐 Settings 页面的真实绑定 (launchAtLogin, 麦克风选择, key 配置)
4. 日夜模式切换按钮

### Sprint 4: 产品完善

1. Onboarding 权限引导
2. App Icon 和品牌资源
3. 跨 App 兼容性系统测试 (Cursor, VS Code, Slack, Notion, Chrome, Arc)
4. Archive / notarization / 发布流程

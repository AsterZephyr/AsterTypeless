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

| 文件 | 实现度 | 状态 |
|------|--------|------|
| AsterTypelessApp.swift | 98% | Onboarding sheet 已接入 |
| TypelessAppModel.swift | 90% | 真实 STT/LLM 已串联，多 provider 支持 |
| HomeView.swift | 95% | 语义色适配，dark mode 基本可用 |
| CaptureHeroView.swift | 95% | 外观切换按钮、快捷键提示、实时统计 |
| TranscriptSidebarView.swift | 90% | 真实数据，日期分组，搜索，空状态 |
| DashboardCards.swift | 10% | 已写但未接入 HomeView (低优先级) |
| ReadinessCard.swift | 10% | 已写但未接入 HomeView (低优先级) |
| FloatingBarView.swift | 85% | UI 完整，有 key 时走真实数据 |
| FnVoiceBarView.swift | 85% | 同上 |
| SettingsView.swift | 90% | 外观切换、provider 配置 UI、权限区 |
| ProviderSettingsView.swift | 95% | 多 provider 选择、API key 配置、状态显示 |
| OnboardingView.swift | 95% | 5 步引导：欢迎、麦克风、辅助功能、输入监听、完成 |
| MenuBarStatusView.swift | 70% | 基本可用 |
| OpenAIClient.swift | 95% | Chat Completion + Audio Transcription |
| ProviderRegistry.swift | 95% | 多 provider 定义、配置、持久化 |
| StreamingTranscriptEngine.swift | 85% | 有 key 走真实 API，无 key 走 mock |
| QuickActionEngine.swift | 85% | 有 key 走真实 API，无 key 走 mock |
| AudioInputMonitor.swift | 95% | PCM 采集、WAV 导出、实时电平 |
| AccessibilityBridge.swift | 80% | 核心逻辑完整，需要更多 App 兼容测试 |
| HotkeyBridge.swift | 85% | 基本可用，边界 case 需打磨 |
| FallbackShortcutBridge.swift | 80% | Carbon 热键已接 |
| RuntimeConfigService.swift | 90% | 已完成 |
| ProviderConfigStore.swift | 95% | JSON 持久化到 Application Support |
| TranscriptStore.swift | 90% | 已完成 (JSON) |
| InsertionCompatibilityStore.swift | 90% | 已完成 (JSON) |
| AppTheme.swift | 85% | 语义色 token + dark mode + 外观切换 |
| App Icon | 100% | 声波指纹设计，10 种尺寸 |

---

## 已完成的迭代

### Sprint 1: 打通真实语音链路 -- DONE

### Sprint 2: 数据层真实化 -- DONE

### Sprint 3: 主题与设置 -- DONE

### Sprint 4: 产品完善 -- DONE (大部分)

1. Onboarding 权限引导 -- DONE
2. App Icon -- DONE
3. 多 Provider 体系 (OpenAI/千问/Groq/Deepgram) -- DONE
4. Provider 配置 UI -- DONE

## 剩余待做

### 需要 API key 才能验证

1. 端到端真实链路验证 (说话 -> 转写 -> 生成 -> 写回)
2. Deepgram WebSocket 实时流式转写 (目前只接了 OpenAI-compatible batch 转写)

### 独立可做

1. DashboardCards / ReadinessCard 接入主页 (低优先级)
2. CaptureHeroView / TranscriptSidebarView 中的剩余硬编码 RGB 替换
3. launchAtLogin 接 SMAppService (需要代码签名)
4. 麦克风设备枚举与选择
5. 跨 App 兼容性系统测试 (Cursor, VS Code, Slack, Notion, Chrome, Arc)
6. Archive / notarization / 发布流程
7. 本地数据从 JSON 升级到 SwiftData

### 支持的 Provider 矩阵

| Provider | LLM Chat | STT | 实时流式 | OpenAI 兼容 |
|----------|----------|-----|----------|------------|
| OpenAI | Yes | Yes (batch) | No | Yes |
| 千问 (Qwen/DashScope) | Yes | - | - | Yes (chat) |
| Groq | Yes | Yes (batch) | No | Yes |
| Deepgram | - | Yes | Yes (WebSocket) | No (需单独适配) |
| Azure OpenAI | Yes | Yes (batch) | No | 部分 (URL/auth 不同) |

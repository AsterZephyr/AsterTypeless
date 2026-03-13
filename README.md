# Typeless Open Clean Room

一个开源版 Typeless MVP 骨架，目标是先把“桌面端语音输入 + 本地内嵌 provider / 自接 API”这条主链路搭起来，再逐步补全选中文本改写、上下文感知和原生输入能力。

## 当前能力

- Electron + React + Vite 桌面端壳子
- 更紧凑的 macOS 工具窗口式 UI
- 麦克风录音和本地音频缓存
- 本地历史记录持久化（SQLite）
- Electron IPC 直连 voice flow
- 全局快捷键唤起的浮层输入条
- macOS native helper 状态探测骨架
- 原生选中内容读取，失败时回落到剪贴板
- 原生文本写回，失败时回落到粘贴板粘贴
- 可切换 `mock` / `proxy` provider
- 标准化的 `voice_flow` 请求与响应契约

## Monorepo 结构

```text
apps/
  desktop/   Electron + React 桌面端
  server/    可选 Fastify HTTP wrapper
packages/
  shared/    桌面端和服务端共享的 schema / contracts
  voice-flow provider 与 voice flow 核心逻辑
docs/
  research.md  clean-room 逆向分析记录
```

## 快速启动

```bash
cd /Users/hxz/code/typeless-open-cleanroom
cp .env.example .env
pnpm install
pnpm dev
```

默认会启动：

- 桌面端开发环境
- Electron 主进程内嵌的 voice flow runtime

如果你只想单独启动某一部分：

```bash
pnpm dev:server
pnpm dev:desktop
pnpm dev:all
```

- `pnpm dev`：只起桌面端，用户侧不需要单独启动 server
- `pnpm dev:all`：同时起桌面端和可选 HTTP wrapper，便于调试远程网关模式

## 环境变量

项目根目录下的 [`.env.example`](/Users/hxz/code/typeless-open-cleanroom/.env.example) 已经给了最小配置：

```bash
VOICE_PROVIDER=mock
UPSTREAM_VOICE_FLOW_URL=
UPSTREAM_API_KEY=
GLOBAL_SHORTCUT=CommandOrControl+Shift+;
PORT=8787
HOST=127.0.0.1
```

### `mock` 模式

- 不依赖外部模型
- 用 `transcriptHint` / `selectedText` 模拟一条可用的语音处理链路
- 适合先联调 UI、历史记录、录音和请求结构

### `proxy` 模式

把 `VOICE_PROVIDER` 设为 `proxy`，并填上：

```bash
VOICE_PROVIDER=proxy
UPSTREAM_VOICE_FLOW_URL=https://your-gateway.example.com/v1/voice/flow
UPSTREAM_API_KEY=your-token
```

这样 Electron 主进程里的 `proxy` provider 会直接把桌面端请求转发成 JSON 给你的上游服务，不需要额外起本地 server。

### 全局快捷键

- 当前默认快捷键：`CommandOrControl+Shift+;`
- 按下后会弹出一个全局浮层输入条，适合快速打字或录音
- `Fn` 单键唤起还没接入；这一步需要补 macOS 原生事件监听层，而不是只靠 Electron 的 `globalShortcut`

### macOS native helper

- 当前已经接通原生 helper，用来读取辅助功能权限状态、当前前台 App、选中文本，并尝试把结果写回目标 App
- 界面里会显示 native bridge 状态，并能触发一次辅助功能权限申请
- “Use selection” 会优先尝试原生选中内容读取，失败时回落到剪贴板
- “Insert into app” 会优先尝试直接修改焦点输入框的值，失败时回落到粘贴板粘贴
- 构建时会优先尝试 Swift helper；如果本机的 Swift toolchain 和 Command Line Tools / Xcode SDK 不匹配，会自动回落到 Objective-C helper
- 这一步还没有做完跨所有 App 的稳定兼容性验证

## 上游接口契约

桌面端默认通过 IPC 调主进程里的 voice flow runtime。

如果你需要 HTTP 调试层，项目里仍然保留了可选的 Fastify wrapper：

- `GET /health`
- `GET /v1/runtime`
- `POST /v1/voice/flow`

`proxy` 模式下，上游会收到一个 JSON 请求体：

```json
{
  "mode": "dictate",
  "context": {
    "focusedAppName": "Slack",
    "selectedText": "",
    "surroundingText": "Current nearby context",
    "transcriptHint": "hello team this is a test",
    "targetLanguage": "English"
  },
  "metadata": {
    "client": "desktop",
    "durationMs": 1200,
    "mimeType": "audio/webm",
    "source": "microphone"
  },
  "audioFile": {
    "filename": "voice-input.webm",
    "mimeType": "audio/webm",
    "base64": "..."
  }
}
```

上游返回需要满足共享契约 [contracts.ts](/Users/hxz/code/typeless-open-cleanroom/packages/shared/src/contracts.ts) 里的 `VoiceFlowResponseSchema`，最小可用示例：

```json
{
  "requestId": "req_123",
  "mode": "dictate",
  "refinedText": "Hello team, this is a test.",
  "delivery": {
    "kind": "insert-after-cursor"
  },
  "debug": {
    "provider": "openai",
    "transcriptSource": "audio",
    "audioProvided": true,
    "contextDigest": "Slack • hello team this is a test"
  },
  "latencyMs": 820
}
```

## 现在这版的边界

已经完成：

- 桌面端 MVP 骨架
- 共享 schema
- 本地 mock provider
- 自接 API 的 proxy provider
- 本地历史记录与旧 JSON 迁移到 SQLite
- 全局快捷键触发的浮层输入条
- macOS native helper 权限状态与前台 App 探测骨架
- 原生选中内容读取与剪贴板回落
- 原生文本写回与粘贴板粘贴回落

还没接入：

- `Fn` 单键唤起
- 跨任意 App 的稳定选中文本兼容层
- 跨任意 App 的稳定文本写回兼容层
- 真正的 STT / LLM provider 适配器

## 下一步建议

1. 先补一个真实 provider 适配器，比如 OpenAI 兼容网关或你自己的内部服务。
2. 继续把 macOS 原生层往前推，增强跨 App 的选中文本与文本写回兼容性。
3. 最后接 `Fn` 或长按修饰键这类更接近 Typeless 的唤起方式。

## 参考

- clean-room 逆向分析记录：[research.md](/Users/hxz/code/typeless-open-cleanroom/docs/research.md)

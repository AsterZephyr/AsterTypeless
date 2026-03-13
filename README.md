# Typeless Open Clean Room

一个开源版 Typeless MVP 骨架，目标是先把“桌面端语音输入 + 本地内嵌 provider / 自接 API”这条主链路搭起来，再逐步补全选中文本改写、上下文感知和原生输入能力。

## 当前能力

- Electron + React + Vite 桌面端壳子
- Typeless 风格的三栏工作区 UI
- 麦克风录音和本地音频缓存
- 本地历史记录持久化（SQLite）
- Electron IPC 直连 voice flow
- 全局快捷键唤起的浮层输入条
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

还没接入：

- macOS 原生 Accessibility 桥
- `Fn` 单键唤起
- 当前焦点输入框插入文本
- 选中文本捕获
- 真正的 STT / LLM provider 适配器

## 下一步建议

1. 先补一个真实 provider 适配器，比如 OpenAI 兼容网关或你自己的内部服务。
2. 再做 macOS 原生层，把“获取选中文本”和“插回当前输入框”补上。
3. 然后把历史存储从 JSON 升级到 SQLite。

## 参考

- clean-room 逆向分析记录：[research.md](/Users/hxz/code/typeless-open-cleanroom/docs/research.md)

# Tonight Execution Plan

日期: 2026-03-14

目标: 在不依赖真实 `Deepgram` / `OpenAI` API key 的前提下，继续推进 `AsterTypeless` 的 P0 主链路，把“可接真实 provider 的原生底座”补齐。

## 今晚不做

- 不直接接真实第三方 API
- 不把 key 写进仓库
- 不做远程服务依赖

## 今晚要做

### 1. Runtime Config 基础设施

- 新增本地运行时配置读取
- 支持从 `Config/Runtime.local.plist` 或 sample 配置读取 provider 信息
- 在 UI 中明确显示:
  - 当前 provider 方案
  - 是否缺少 `Deepgram` 配置
  - 是否缺少 `OpenAI` 配置
  - 当前链路处于 `mock-ready` 还是 `provider-ready`

交付结果:
- 配置服务
- 运行时状态模型
- 设置页 / 首页状态展示

### 2. Provider 占位链路

- 把“未配置真实 API”变成显式状态，而不是隐式失败
- 为后续接入实时语音转写和 rewrite 预留 provider 抽象
- 让浮窗、首页、设置页都能读到一致的 runtime status

交付结果:
- 本地 mock / provider-ready 双态
- 明确错误提示文案

### 3. 跨 App 写回兼容矩阵底座

- 新增插入尝试记录
- 记录目标 App、写回方式、是否成功、时间
- 为后续验证 Cursor / VS Code / Slack / Notion / Chrome / Arc / JetBrains 做数据底座

交付结果:
- insertion compatibility store
- 本地 JSON 记录
- 首页或设置页的兼容性摘要入口

### 4. 构建与提交流程

- 每完成一个小点就单独 commit
- 每个 commit 后 push 到 `origin/main`
- 每个小点都重新跑:
  - `swift build`
  - `xcodebuild -project AsterTypeless.xcodeproj -scheme AsterTypeless -configuration Debug -sdk macosx build`

## 今晚预期提交顺序

1. `docs: add nightly execution plan`
2. `feat: add runtime provider config status`
3. `feat: track insertion compatibility results`

## 明早你应该能看到的结果

- 仓库里有清晰的 tonight plan 文档
- App 已能识别“是否具备真实 provider 配置”
- App 已开始记录跨 App 写回成功率
- 后续只差你补真实 key，我就能直接接入真实语音链路

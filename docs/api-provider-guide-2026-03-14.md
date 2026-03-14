# API Provider Guide

## 推荐组合

如果目标是最像 `Typeless` 的输入体验，当前最适合的组合仍然是：

1. `Deepgram` 负责实时语音转写
2. `OpenAI` 负责润色、改写、上下文编排和结果生成

如果你暂时只想先打通链路，也可以先走：

1. `OpenAI` 直接做转写
2. `OpenAI` 同时做文本整理

但这条路更像一个“语音输入 demo”，不像 Typeless 那种低延迟、持续录音、实时状态反馈的产品体验。

## 为什么不是 OpenRouter + Deepgram

`OpenRouter` 适合做统一的 LLM 出口，不适合替代 `Deepgram` 的实时语音 API。

原因：

1. `Deepgram` 的核心价值是流式语音转写、低延迟 partial transcript、endpointing、utterance 分段，这些不是普通 OpenAI-compatible chat 接口能替代的
2. 我没有查到 `OpenRouter` 提供 `Deepgram` 作为 speech-to-text provider 的官方路线
3. `OpenRouter` 更适合承接“文本改写模型的路由层”，不适合作为实时语音主链路

## 明天你给我的最小配置

### 方案 A：推荐

```bash
DEEPGRAM_API_KEY=...
DEEPGRAM_BASE_URL=https://api.deepgram.com
DEEPGRAM_MODEL=nova-2
DEEPGRAM_LANGUAGE=zh-CN

OPENAI_API_KEY=...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-5-mini
OPENAI_TRANSCRIBE_MODEL=gpt-4o-transcribe
```

适用场景：

1. 中文为主
2. 中英混说
3. 希望保留 Typeless 那种实时语音体验

### 方案 B：先快速跑通

```bash
OPENAI_API_KEY=...
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-5-mini
OPENAI_TRANSCRIBE_MODEL=gpt-4o-transcribe
```

适用场景：

1. 先做 MVP
2. 暂时不追求最好的实时流式体验

### 方案 C：你如果更想用 OpenRouter

```bash
DEEPGRAM_API_KEY=...
DEEPGRAM_BASE_URL=https://api.deepgram.com
DEEPGRAM_MODEL=nova-2
DEEPGRAM_LANGUAGE=zh-CN

OPENAI_API_KEY=<你的 OpenRouter Key>
OPENAI_BASE_URL=https://openrouter.ai/api/v1
OPENAI_MODEL=<你选的文本模型>
```

这一套只建议把 `OpenRouter` 用在“文本生成 / 文本改写”层，不要用它替代 Deepgram 的实时语音入口。

## 我们接入时会怎么用

### Deepgram

用途：

1. 持续接收麦克风 PCM/Opus 音频
2. 实时返回 partial transcript
3. 在讲话结束后返回 final transcript
4. 把实时状态同步到浮窗

我们需要的能力：

1. streaming transcription
2. interim results
3. endpointing / utterance split
4. smart formatting

### OpenAI

用途：

1. 把 `final transcript` 整理成更像人写的文本
2. 根据模式做 `dictate / rewrite / translate / ask`
3. 根据当前 app、选中文本、附近上下文做结果编排

输入大致会是：

1. transcript
2. current app
3. selected text
4. surrounding text
5. current mode

输出大致会是：

1. cleaned transcript
2. rewritten final text
3. optional rationale / metadata

## 接入顺序

1. 先接本地配置读取
2. 先打通 `OpenAI-only fallback`
3. 再接 `Deepgram realtime`
4. 再把流式 partial transcript 接到浮窗
5. 最后把生成结果接到跨 App 写回

## 当前不建议现在做的事

1. 不要先做多 provider 复杂路由
2. 不要先接国内一堆 ASR 厂商
3. 不要先把 OpenRouter 当成 Deepgram 替代
4. 不要先做云端后端网关

现阶段最重要的是把 `本地 macOS app -> 语音 -> 文本 -> 插回当前输入框` 这条链做顺。

<div align="center">

<br />

# AsterTypeless

### Voice that flows into any app.

Press **Fn**, speak naturally, release. Your words land at the cursor -- polished, in any language, in any app on your Mac.

<br />

**Native macOS** · **SwiftUI + Accessibility APIs** · **Bring your own AI**

<br />

[Quick Start](#quick-start) · [Providers](#supported-providers) · [Architecture](#architecture) · [Contributing](#contributing)

<br />

---

</div>

## What it does

AsterTypeless turns your voice into text and drops it right where your cursor is. No switching apps, no copy-paste, no friction.

```
You speak          -->  ASR transcribes  -->  LLM polishes  -->  Text appears at cursor
"帮我回复说周三可以"  -->  "帮我回复说周三可以"  -->  "周三可以的，到时见。"  -->  [typed into Slack]
```

The entire pipeline runs in under 2 seconds with a self-hosted model.

## Why

macOS has built-in dictation. It works. But it doesn't clean up your speech, doesn't translate on the fly, doesn't let you swap in your own models, and doesn't work with self-hosted AI. AsterTypeless does all of that.

## Core ideas

- **Fn-triggered** -- hold Fn to talk, release to finish. Also supports tap-to-toggle, double-tap for hands-free, and keyboard shortcuts.
- **Writes back to any app** -- uses Accessibility APIs to insert text at the cursor. Falls back to clipboard paste when AX isn't available.
- **Bring your own provider** -- OpenAI, Qwen, Groq, Deepgram, Azure, or any self-hosted server with an OpenAI-compatible API (vLLM, Ollama, etc.).
- **Four modes** -- Dictate (clean up speech), Rewrite (polish selected text), Translate (into any language), Ask (answer questions from context).
- **Minimal floating bar** -- a tiny waveform capsule appears while recording. No clutter, no chrome.
- **Dark mode native** -- respects system appearance out of the box.

## Quick Start

**Requirements:** macOS 14+, Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen)

```bash
git clone https://github.com/AsterZephyr/AsterTypeless.git
cd AsterTypeless
xcodegen generate
./Scripts/deploy.sh     # builds, signs, deploys to /Applications, launches
```

First launch opens a permission wizard for **Microphone**, **Accessibility**, and **Input Monitoring**.

### Connect a provider

Open **Settings** (gear icon in main window or menu bar) and fill in your endpoint:

| Field | Example |
|---|---|
| Base URL | `http://your-server:8000/v1` |
| API Key | `sk-...` or `not-needed` for self-hosted |
| Model | `gpt-4o-mini` / `qwen-plus` / `/data0/models/Qwen3-1.7B` |

Click **Save** -- takes effect immediately, no restart needed. Hit **Test Connection** to verify.

You can also configure via plist if you prefer:

```bash
cp Config/Runtime.sample.plist Config/Runtime.local.plist
# edit with your values
```

## Supported Providers

| Provider | Chat (LLM) | Transcription (STT) | Streaming | Notes |
|---|---|---|---|---|
| **OpenAI** | gpt-4o-mini | gpt-4o-transcribe | -- | Standard API |
| **Qwen** | qwen-plus, qwen-turbo | -- | -- | Via DashScope, OpenAI-compatible |
| **Groq** | llama-3.3-70b | whisper-large-v3-turbo | -- | Fast inference |
| **Deepgram** | -- | nova-2 | WebSocket | Real-time streaming |
| **Azure OpenAI** | Any deployment | Any deployment | -- | Custom endpoint format |
| **Self-hosted** | Any | Any | -- | vLLM, Ollama, LocalAI, etc. |

Providers with an OpenAI-compatible `/v1/chat/completions` or `/v1/audio/transcriptions` endpoint work out of the box.

## How it works

```
                        ┌──────────────────────────────────────────────────┐
  Fn press ─────────►   │  AudioInputMonitor                               │
                        │  Records PCM via AVAudioEngine                   │
  Fn release ───────►   │  Exports WAV                                     │
                        └──────────────┬───────────────────────────────────┘
                                       │
                                       ▼
                        ┌──────────────────────────────────────────────────┐
                        │  StreamingTranscriptEngine                        │
                        │  POST /v1/audio/transcriptions ──► ASR server    │
                        └──────────────┬───────────────────────────────────┘
                                       │ transcript
                                       ▼
                        ┌──────────────────────────────────────────────────┐
                        │  QuickActionEngine                                │
                        │  POST /v1/chat/completions ──► LLM server        │
                        │  (strips <think> tags for reasoning models)       │
                        └──────────────┬───────────────────────────────────┘
                                       │ polished text
                                       ▼
                        ┌──────────────────────────────────────────────────┐
                        │  AccessibilityBridge                              │
                        │  AXUIElement.setValue ──► target app cursor       │
                        │  Fallback: clipboard paste via Cmd+V              │
                        └──────────────────────────────────────────────────┘
```

## Architecture

```
Sources/AsterTypeless/
├── App/                    State machine, bootstrap, pipeline orchestration
├── Features/
│   ├── Home/               Main window (sidebar + capture hero)
│   ├── FloatingBar/        Minimal waveform overlay (NSPanel)
│   ├── Settings/           Provider config, permissions, appearance
│   ├── MenuBar/            Menu bar quick actions
│   └── Onboarding/         First-launch permission wizard
├── Models/                 Domain types (sessions, quick bar state, settings)
├── Services/
│   ├── OpenAIClient        HTTP: chat completions + audio transcription
│   ├── DeepgramStreamingClient   WebSocket: real-time STT
│   ├── ProviderRegistry    Multi-provider config + persistence
│   ├── AudioInputMonitor   AVAudioEngine capture, PCM buffer, WAV export
│   ├── AccessibilityBridge AX read/write + clipboard fallback
│   ├── HotkeyBridge        Fn key tap/hold/double-tap via CGEventTap
│   └── ...                 Transcript store, config service, shortcuts
└── Support/                Theme tokens, window chrome
```

## Development

```bash
# Regenerate Xcode project after adding files
xcodegen generate

# Build
xcodebuild -scheme AsterTypeless build

# Deploy (preserves macOS permissions across rebuilds)
./Scripts/deploy.sh

# Check pipeline logs after a dictation
cat /tmp/aster_pipeline.log
```

The deploy script uses `rsync` to update `/Applications/AsterTypeless.app` without breaking the code signature, so macOS permissions (Accessibility, Input Monitoring) persist across rebuilds.

## Roadmap

- [ ] Deepgram real-time streaming during recording (live partial transcripts)
- [ ] Expanded cross-app compatibility testing (VS Code, Notion, Arc, Slack)
- [ ] SwiftData migration for local storage
- [ ] Archive, notarization, and DMG distribution
- [ ] Configurable Fn behavior (sensitivity, double-tap timeout)

## Contributing

PRs welcome. If you're adding a new provider, it only needs to implement the OpenAI-compatible chat or transcription endpoint format.

## License

[MIT](LICENSE)

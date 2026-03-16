# AsterTypeless

A native macOS voice-to-text tool. Press Fn, speak, and your words are transcribed and inserted at the cursor position in any app.

Built with SwiftUI, AppKit, and Accessibility APIs. Supports multiple AI providers for speech recognition and text processing.

## Features

- **Fn-triggered dictation** -- press Fn to start, release to finish. Text is written back to the focused input field automatically.
- **Multi-provider STT** -- OpenAI Transcribe, Groq Whisper, Deepgram (real-time WebSocket), or any self-hosted OpenAI-compatible ASR server (e.g. Qwen3-ASR via vLLM).
- **Multi-provider LLM** -- OpenAI, Qwen (DashScope), Groq, Azure OpenAI, or self-hosted (e.g. Qwen3 via vLLM). Supports dictation cleanup, rewriting, translation, and Q&A modes.
- **Cross-app text insertion** -- writes back via Accessibility API (AXValue), with clipboard paste as fallback. Works across most macOS apps.
- **Floating dictation bar** -- compact overlay shows recording status, audio levels, and transcription progress.
- **Dark mode** -- full light/dark/auto appearance support with system semantic colors.
- **Menu bar access** -- quick start dictation or open the main window from the menu bar.
- **Privacy-first** -- all audio processing is done through your configured API provider. Nothing is stored or sent without your knowledge.

## Screenshots

*(Coming soon)*

## Requirements

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for regenerating the project file)

## Quick Start

### 1. Clone and build

```bash
git clone https://github.com/AsterZephyr/AsterTypeless.git
cd AsterTypeless
xcodegen generate
xcodebuild -scheme AsterTypeless build
```

### 2. Deploy

```bash
./Scripts/deploy.sh
```

This builds the app, copies it to `/Applications/AsterTypeless.app`, and launches it. On first run, you'll need to grant permissions (see below).

### 3. Grant permissions

The app needs three macOS permissions:

| Permission | Purpose | How to grant |
|---|---|---|
| **Microphone** | Voice capture | System prompt on first use |
| **Accessibility** | Read/write text in other apps | System Settings > Privacy & Security > Accessibility |
| **Input Monitoring** | Fn key detection | System Settings > Privacy & Security > Input Monitoring |

An onboarding wizard guides you through these on first launch.

### 4. Configure an AI provider

Copy the sample config and add your provider details:

```bash
cp Config/Runtime.sample.plist Config/Runtime.local.plist
# Edit Config/Runtime.local.plist with your API keys
```

Or configure providers in-app via **Settings > AI Provider**.

#### Self-hosted example (vLLM + Qwen3)

```xml
<dict>
    <key>OpenAIBaseURL</key>
    <string>http://YOUR_SERVER:8000/v1</string>
    <key>OpenAIAPIKey</key>
    <string>not-needed</string>
    <key>OpenAIModel</key>
    <string>/data0/models/Qwen3-1.7B</string>
    <key>DeepgramBaseURL</key>
    <string>http://YOUR_SERVER:8001/v1</string>
    <key>DeepgramAPIKey</key>
    <string>not-needed</string>
    <key>DeepgramModel</key>
    <string>/data0/models/Qwen3-ASR-1.7B</string>
</dict>
```

The config file is searched in these locations:
1. `~/Library/Application Support/AsterTypeless/Config/`
2. Project source directory
3. Environment variable `ASTERTYPELESS_RUNTIME_CONFIG`

## Supported Providers

| Provider | LLM | STT | Real-time streaming | OpenAI-compatible |
|---|---|---|---|---|
| OpenAI | gpt-4o-mini | gpt-4o-transcribe | No | Yes |
| Qwen (DashScope) | qwen-plus | -- | -- | Yes (chat) |
| Groq | llama-3.3-70b | whisper-large-v3-turbo | No | Yes |
| Deepgram | -- | nova-2 | Yes (WebSocket) | No |
| Azure OpenAI | Configurable | Configurable | No | Partial |
| Self-hosted | Any | Any | No | Yes (vLLM, Ollama) |

## Architecture

```
Sources/AsterTypeless/
  App/                  Application lifecycle, state machine (TypelessAppModel)
  Features/
    Home/               Main window: sidebar + capture hero
    FloatingBar/        Floating dictation overlay (NSPanel)
    Settings/           Settings window with provider config UI
    MenuBar/            Menu bar extra
    Onboarding/         First-launch permission wizard
  Models/               Domain models (DictationSession, QuickBarState, etc.)
  Services/
    OpenAIClient        HTTP client for chat completion + audio transcription
    DeepgramStreamingClient  WebSocket client for real-time STT
    ProviderRegistry    Multi-provider configuration and persistence
    StreamingTranscriptEngine  ASR orchestration (real or mock)
    QuickActionEngine   LLM orchestration (real or mock)
    AudioInputMonitor   Microphone capture, PCM buffer, WAV export
    AccessibilityBridge AX text read/write, clipboard fallback
    HotkeyBridge        Fn key tap/hold/double-tap detection
    FallbackShortcutBridge  Carbon global hotkey registration
    RuntimeConfigService  Plist-based provider config loading
    TranscriptStore     Local session persistence (JSON)
  Support/              Theme system (AppTheme), window chrome config
```

## Pipeline

The end-to-end flow when you press Fn and speak:

```
Fn press -> startRecording -> AudioInputMonitor (PCM capture)
                                |
Fn release -> stopRecording -> collectWAVData()
                                |
                          StreamingTranscriptEngine.transcribeAudio(wav)
                                |
                          POST /v1/audio/transcriptions -> ASR server
                                |
                          QuickActionEngine.executeAsync(transcript)
                                |
                          POST /v1/chat/completions -> LLM server
                                |  (strip <think> tags if Qwen3)
                          AccessibilityBridge.insert(text)
                                |
                          AXValue write or clipboard paste -> target app
```

## Development

### Regenerate Xcode project

```bash
xcodegen generate
```

### Build from command line

```bash
xcodebuild -scheme AsterTypeless build
```

### Deploy to /Applications (preserves permissions)

```bash
./Scripts/deploy.sh
```

### Debug pipeline

After using the app, check `/tmp/aster_pipeline.log` for the full pipeline trace with timestamps.

### Project file

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) with `project.yml`. After adding new files, run `xcodegen generate` to update the `.xcodeproj`.

## License

MIT

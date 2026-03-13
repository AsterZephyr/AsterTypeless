# Typeless Clean-Room Reverse Engineering Notes

Date: 2026-03-13

## Scope

This document summarizes a clean-room implementation plan based on:

- public website behavior and page content from `https://www.typeless.com/` and `https://www.typeless.com/pricing`
- local desktop app packaging from `/Applications/Typeless.app`
- local runtime data layout under `/Users/hxz/Library/Application Support/Typeless`

This is not a source-code copy plan. The goal is to rebuild the product shape with your own API layer and provider integrations.

## High-Confidence Findings

### 1. Web app / marketing site

- The public site is a Next.js app behind CloudFront.
- It presents Typeless as an AI voice dictation product first, but pricing and page strings show the product has expanded into a broader AI productivity platform.
- Public feature strings include:
  - voice dictation
  - rewrite / write / summarize / search
  - full-page chat
  - image creation
  - multi-model comparison
  - sources from URL, text, file, folders
  - team plan / people management
- Pricing strings show support for payment methods including card, US bank account, AliPay, and WeChat Pay.

### 2. Desktop architecture

- The macOS app is Electron.
- `Info.plist` shows:
  - bundle id: `now.typeless.desktop`
  - version: `1.0.4`
  - custom scheme: `typeless://`
  - Electron ASAR integrity
- App package contains:
  - `dist/main/index.js`
  - `dist/preload/index.mjs`
  - `dist/renderer/*`
  - `Resources/drizzle/*.sql`
- Dependencies indicate the main stack is Electron + Vite + React, with:
  - `drizzle-orm`
  - `sqlite3`
  - `@libsql/client`
  - `electron-store`
  - `electron-updater`
  - `@sentry/electron`
  - `koffi`

### 3. Native capability layer

- The app uses native macOS dynamic libraries loaded through `koffi`.
- Observed helper modules:
  - input helper: insert plain text / rich text, delete backward, read selected text, read current input state
  - keyboard helper: global shortcut monitor and key watcher
  - context helper: focused app info, focused element info, visible text, related content
  - opus encoder helper: local audio compression
- This means Typeless is not just “send microphone to cloud”; it deeply integrates with macOS Accessibility and text insertion.

### 4. Local storage model

- Local app data found at `/Users/hxz/Library/Application Support/Typeless`
- Important files:
  - `typeless.db`
  - `Recordings/*.ogg`
  - `app-settings.json`
  - `app-storage.json`
  - `app-onboarding.json`
- Local DB currently has a main `history` table with fields for:
  - `audio`, `audio_local_path`, `audio_metadata`
  - `refined_text`, `edited_text`
  - `audio_context`
  - detected language
  - focused app / bundle id / window title / web URL / web domain
  - `mode`, `mode_meta`
  - `client_metadata`
- This strongly suggests the product stores raw capture metadata locally, while high-value AI processing is remote.

### 5. Cloud API split

- Main API host in desktop app: `https://api.typeless.com`
- High-confidence observed endpoints in desktop main process:
  - `/ai/voice_flow`
  - `/app/get_blacklist_domain`
  - `/app/metrics_mp`
  - `/user/traits`
- Core voice path found in main process:
  1. capture audio
  2. compress to OGG/Opus
  3. collect `audio_context`
  4. attach mode-specific params
  5. POST to `/ai/voice_flow`
  6. receive `refine_text`, `delivery`, `user_prompt`, `web_metadata`, `external_action`
  7. insert output back into active app

### 6. Product capability shape

- Based on public strings and local app code, Typeless today is closer to this:
  - cross-app voice keyboard
  - context-aware dictation and rewriting
  - read-only text Q&A
  - AI search
  - multi-model chat
  - source-grounded chat over links/files/text
  - image generation
  - personal/team subscription and quota system

## What To Rebuild Cleanly

You should treat Typeless as three products glued together:

1. A macOS-native input/control layer
2. A cloud AI orchestration backend
3. A subscription and growth web app

If you rebuild only the backend prompts, you will miss the real moat. The biggest value is:

- reliable global input capture
- app-aware context collection
- low-friction insertion back into any text field
- fast round-trip for “speak -> polished text”

## Recommended Reimplementation Strategy

### Phase 1: Build the real core, not the whole platform

Ship this first:

- global shortcut to start/stop recording
- local microphone capture
- local OGG/Opus compression
- focused app + selected text + nearby visible text capture
- one `voice_flow` backend
- insertion back into the current app
- local history and replay

Do not start with:

- team plan
- knowledge base
- image generation
- multi-model compare UI
- referral / affiliate

### Phase 2: Add “selected text intelligence”

Add:

- rewrite selected text
- summarize selected text
- translate selected text
- answer questions about selected text

This is already enough to feel like a strong Typeless-style product.

### Phase 3: Expand into AI workspace

Only after the core input loop is solid, add:

- source upload and URL ingest
- source-grounded chat
- search mode
- full-page chat
- model selection
- compare answers

## Suggested System Design

### Desktop app

Recommended stack:

- Electron + React + Vite for fastest path to parity
- native macOS bridge in Swift or Objective-C
- Node addon or FFI bridge for:
  - Accessibility APIs
  - focused element inspection
  - selected text retrieval
  - text insertion
  - global keyboard shortcuts
  - low-level audio device access if needed

Key modules:

- `desktop/main`
  - window lifecycle
  - updater
  - IPC
  - file paths
  - local DB
- `desktop/native`
  - accessibility bridge
  - keyboard monitor
  - input insertion
  - focused context
- `desktop/audio`
  - microphone capture
  - VAD optional
  - OGG/Opus compression
- `desktop/voice-flow`
  - gather context
  - send request
  - receive structured response
  - apply insertion/delivery
- `desktop/history`
  - SQLite history
  - local recordings
  - retention cleanup

### Backend

Recommended split:

- API gateway
- auth/billing/quota service
- voice orchestration service
- chat/source service
- provider adapters
- telemetry service

Suggested backend responsibilities:

- normalize desktop requests
- choose model/provider by mode
- prompt assembly
- contextual rewriting / translation / question answering
- search grounding
- billing / quotas
- user traits / personalization

### Provider abstraction

Make provider integration swappable from day one.

Suggested interface:

- `transcribe(audio, meta)`
- `refineDictation(rawText, context, mode)`
- `chat(messages, tools, sources, model)`
- `search(query)`
- `generateImage(prompt)`

Possible providers:

- STT:
  - OpenAI
  - Deepgram
  - local Whisper / faster-whisper
- text generation:
  - OpenAI
  - Anthropic
  - Gemini
  - DeepSeek
- search grounding:
  - Tavily / SerpAPI / custom browser worker
- image generation:
  - OpenAI Images or another dedicated image provider

## Minimal API Contract For Your Own Clone

### `POST /v1/voice/flow`

Request:

- `audio_file`
- `audio_id`
- `mode`
- `audio_context`
- `audio_metadata`
- `parameters`

Response:

- `refined_text`
- `delivery`
  - `insert_plain_text`
  - `insert_rich_text`
  - `replace_selection`
  - `open_sidebar`
- `external_action`
  - optional link opening or follow-up UI action
- `usage`
- `debug`

### `POST /v1/context/rewrite`

Request:

- selected text
- focused app
- desired transform

Response:

- replacement text
- optional formatted HTML

### `POST /v1/chat`

Request:

- messages
- selected content
- source ids
- model

Response:

- answer
- citations
- action suggestions

### `POST /v1/sources/ingest`

Support:

- file
- folder manifest
- URL
- pasted text

### `GET /v1/user/traits`

Return:

- subscription
- quota
- personalization settings
- enabled features

## Suggested Local Schema

Use SQLite locally with at least:

- `history`
- `recordings`
- `user_preferences`
- `app_profiles`
- `prompt_presets`
- `event_log`

For MVP, `history` can look similar to observed Typeless fields:

- `id`
- `mode`
- `refined_text`
- `edited_text`
- `audio_local_path`
- `audio_context_json`
- `audio_metadata_json`
- `focused_app_name`
- `focused_app_bundle_id`
- `focused_window_title`
- `focused_web_domain`
- `focused_web_url`
- `detected_language`
- `status`
- `created_at`

## UX Features Worth Copying First

Highest ROI:

- floating mini bar
- one hotkey to dictate
- selected-text rewrite
- app-aware tone adaptation
- local history panel
- retry last transcript

Medium ROI:

- translation mode
- smart formatting
- clipboard and rich text insert
- compare model answers

Lower ROI for first release:

- teams
- affiliate/referral
- rewards
- image generation
- browser extension funnel

## Security / Privacy Recommendations

- keep raw audio local by default
- make cloud upload opt-in or narrowly scoped to processing
- encrypt tokens at rest
- redact surrounding context before send when possible
- never persist full focused page text unless necessary
- store only rolling short context windows
- allow per-app denylist / allowlist

This matters because the app reads selected text, focused page content, and app metadata.

## Implementation Order I Recommend

### Milestone 1

- Electron shell
- local DB
- recording pipeline
- one global hotkey
- plain text insertion

### Milestone 2

- focused app detection
- selected text capture
- nearby context capture
- `voice_flow` backend
- retry / history

### Milestone 3

- rewrite / summarize / translate on selected text
- rich text insertion
- floating bar UX
- app-specific prompt profiles

### Milestone 4

- full chat sidebar
- model selector
- sources from URL/file/text
- source-grounded answers

### Milestone 5

- payments
- team plan
- growth loops
- referral / affiliate

## My Recommendation For You

If your goal is “a Typeless-like product that I can wire to my own APIs”, do this:

1. Copy the interaction model, not the exact product surface.
2. Rebuild the desktop-native loop first.
3. Put all intelligence behind your own gateway API.
4. Keep providers replaceable.
5. Treat context capture and insertion reliability as the real core.

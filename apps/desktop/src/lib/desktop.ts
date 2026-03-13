import type {
  DesktopHistoryItem,
  DesktopRuntimeInfo,
  DesktopVoiceFlowRequest,
  VoiceFlowResponse,
  VoiceGatewayRuntime,
} from '@typeless-open/shared'

type DesktopBridge = {
  getRuntimeInfo: () => Promise<DesktopRuntimeInfo>
  getVoiceRuntime: () => Promise<VoiceGatewayRuntime>
  runVoiceFlow: (input: DesktopVoiceFlowRequest) => Promise<VoiceFlowResponse>
  showMainWindow: () => Promise<boolean>
  toggleFloatingWindow: () => Promise<boolean>
  readSelectionFallback: () => Promise<string>
  copyToClipboard: (text: string) => Promise<boolean>
  listHistory: () => Promise<DesktopHistoryItem[]>
  saveHistory: (item: DesktopHistoryItem) => Promise<DesktopHistoryItem[]>
  openExternal: (url: string) => Promise<boolean>
}

const noopBridge: DesktopBridge = {
  async getRuntimeInfo() {
    return {
      appName: 'Typeless Open',
      appVersion: '0.1.0',
      platform: navigator.platform,
      userDataPath: 'browser-preview',
    }
  },
  async getVoiceRuntime() {
    return {
      provider: 'mock',
      transport: 'ipc',
      upstreamConfigured: false,
    }
  },
  async runVoiceFlow(input) {
    const seed =
      input.context.transcriptHint || input.context.selectedText || input.context.surroundingText

    return {
      requestId: crypto.randomUUID(),
      mode: input.mode,
      refinedText: seed ? seed.trim() : 'Browser preview voice flow result.',
      delivery: {
        kind: input.mode === 'ask' ? 'copy-only' : 'insert-after-cursor',
      },
      debug: {
        provider: 'mock',
        transcriptSource: input.audioFile ? 'audio' : 'text-hint',
        audioProvided: Boolean(input.audioFile),
        contextDigest: input.context.focusedAppName,
      },
      latencyMs: 1,
    }
  },
  async showMainWindow() {
    return true
  },
  async toggleFloatingWindow() {
    return true
  },
  async readSelectionFallback() {
    return navigator.clipboard.readText()
  },
  async copyToClipboard(text) {
    await navigator.clipboard.writeText(text)
    return true
  },
  async listHistory() {
    return []
  },
  async saveHistory(item) {
    return [item]
  },
  async openExternal(url) {
    window.open(url, '_blank', 'noopener,noreferrer')
    return true
  },
}

export const desktopBridge: DesktopBridge = window.typelessDesktop ?? noopBridge

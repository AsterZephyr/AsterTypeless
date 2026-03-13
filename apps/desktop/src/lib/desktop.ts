import type {
  DesktopCapturedContext,
  DesktopHistoryItem,
  DesktopInsertTextRequest,
  DesktopInsertTextResult,
  DesktopNativeStatus,
  DesktopRuntimeInfo,
  DesktopSelectionSnapshot,
  DesktopVoiceFlowRequest,
  VoiceFlowResponse,
  VoiceGatewayRuntime,
} from '@typeless-open/shared'

type DesktopBridge = {
  getRuntimeInfo: () => Promise<DesktopRuntimeInfo>
  getVoiceRuntime: () => Promise<VoiceGatewayRuntime>
  getNativeStatus: () => Promise<DesktopNativeStatus>
  promptAccessibilityPermission: () => Promise<DesktopNativeStatus>
  promptListenEventAccess: () => Promise<DesktopNativeStatus>
  runVoiceFlow: (input: DesktopVoiceFlowRequest) => Promise<VoiceFlowResponse>
  showMainWindow: () => Promise<boolean>
  toggleFloatingWindow: () => Promise<boolean>
  insertText: (input: DesktopInsertTextRequest) => Promise<DesktopInsertTextResult>
  readSelectionContext: () => Promise<DesktopSelectionSnapshot>
  getLastCapturedContext: () => Promise<DesktopCapturedContext>
  onCapturedContext: (
    listener: (context: DesktopCapturedContext) => void,
  ) => () => void
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
  async getNativeStatus() {
    return {
      helperAvailable: false,
      helperPath: '',
      accessibilityTrusted: false,
      accessibilityPermissionPrompted: false,
      listenEventAccess: false,
      listenEventAccessPrompted: false,
      fnTriggerEnabled: false,
      triggerSource: 'shortcut',
      focusedAppName: '',
      focusedBundleId: '',
      lastError: '',
    }
  },
  async promptAccessibilityPermission() {
    return {
      helperAvailable: false,
      helperPath: '',
      accessibilityTrusted: false,
      accessibilityPermissionPrompted: false,
      listenEventAccess: false,
      listenEventAccessPrompted: false,
      fnTriggerEnabled: false,
      triggerSource: 'shortcut',
      focusedAppName: '',
      focusedBundleId: '',
      lastError: '',
    }
  },
  async promptListenEventAccess() {
    return {
      helperAvailable: false,
      helperPath: '',
      accessibilityTrusted: false,
      accessibilityPermissionPrompted: false,
      listenEventAccess: false,
      listenEventAccessPrompted: false,
      fnTriggerEnabled: false,
      triggerSource: 'shortcut',
      focusedAppName: '',
      focusedBundleId: '',
      lastError: '',
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
  async insertText() {
    return {
      ok: false,
      method: 'unavailable',
      focusedAppName: '',
      focusedBundleId: '',
      lastError: 'Text insertion is only available in the desktop shell.',
    }
  },
  async readSelectionContext() {
    return {
      available: false,
      selectedText: await navigator.clipboard.readText(),
      surroundingText: '',
      focusedAppName: '',
      focusedBundleId: '',
      source: 'clipboard',
      lastError: '',
    }
  },
  async getLastCapturedContext() {
    return {
      triggerSource: 'manual',
      focusedAppName: '',
      focusedBundleId: '',
      selectedText: '',
      surroundingText: '',
      capturedAt: new Date(0).toISOString(),
    }
  },
  onCapturedContext(_listener) {
    return () => {}
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

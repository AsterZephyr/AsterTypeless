/// <reference types="vite/client" />

import type {
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

interface DesktopBridge {
  getRuntimeInfo: () => Promise<DesktopRuntimeInfo>
  getVoiceRuntime: () => Promise<VoiceGatewayRuntime>
  getNativeStatus: () => Promise<DesktopNativeStatus>
  promptAccessibilityPermission: () => Promise<DesktopNativeStatus>
  runVoiceFlow: (input: DesktopVoiceFlowRequest) => Promise<VoiceFlowResponse>
  showMainWindow: () => Promise<boolean>
  toggleFloatingWindow: () => Promise<boolean>
  insertText: (input: DesktopInsertTextRequest) => Promise<DesktopInsertTextResult>
  readSelectionContext: () => Promise<DesktopSelectionSnapshot>
  copyToClipboard: (text: string) => Promise<boolean>
  listHistory: () => Promise<DesktopHistoryItem[]>
  saveHistory: (item: DesktopHistoryItem) => Promise<DesktopHistoryItem[]>
  openExternal: (url: string) => Promise<boolean>
}

declare global {
  interface Window {
    typelessDesktop?: DesktopBridge
  }
}

export {}

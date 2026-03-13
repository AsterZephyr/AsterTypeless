/// <reference types="vite/client" />

import type {
  DesktopHistoryItem,
  DesktopRuntimeInfo,
  DesktopVoiceFlowRequest,
  VoiceFlowResponse,
  VoiceGatewayRuntime,
} from '@typeless-open/shared'

interface DesktopBridge {
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

declare global {
  interface Window {
    typelessDesktop?: DesktopBridge
  }
}

export {}

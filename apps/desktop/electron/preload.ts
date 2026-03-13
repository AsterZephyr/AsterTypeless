import { contextBridge, ipcRenderer } from 'electron'

import type {
  DesktopHistoryItem,
  DesktopRuntimeInfo,
  DesktopVoiceFlowRequest,
  VoiceFlowResponse,
  VoiceGatewayRuntime,
} from '@typeless-open/shared'

const desktopApi = {
  getRuntimeInfo() {
    return ipcRenderer.invoke('desktop:get-runtime-info') as Promise<DesktopRuntimeInfo>
  },
  getVoiceRuntime() {
    return ipcRenderer.invoke('desktop:voice-flow:get-runtime') as Promise<VoiceGatewayRuntime>
  },
  runVoiceFlow(input: DesktopVoiceFlowRequest) {
    return ipcRenderer.invoke('desktop:voice-flow:run', input) as Promise<VoiceFlowResponse>
  },
  showMainWindow() {
    return ipcRenderer.invoke('desktop:window:show-main') as Promise<boolean>
  },
  toggleFloatingWindow() {
    return ipcRenderer.invoke('desktop:window:toggle-floating') as Promise<boolean>
  },
  readSelectionFallback() {
    return ipcRenderer.invoke('desktop:selection:read-fallback') as Promise<string>
  },
  copyToClipboard(text: string) {
    return ipcRenderer.invoke('desktop:clipboard:copy', text) as Promise<boolean>
  },
  listHistory() {
    return ipcRenderer.invoke('desktop:history:list') as Promise<DesktopHistoryItem[]>
  },
  saveHistory(item: DesktopHistoryItem) {
    return ipcRenderer.invoke('desktop:history:save', item) as Promise<DesktopHistoryItem[]>
  },
  openExternal(url: string) {
    return ipcRenderer.invoke('desktop:open-external', url) as Promise<boolean>
  },
}

contextBridge.exposeInMainWorld('typelessDesktop', desktopApi)

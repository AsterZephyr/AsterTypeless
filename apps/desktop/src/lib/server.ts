import {
  DesktopVoiceFlowRequestSchema,
  VoiceGatewayRuntimeSchema,
  VoiceFlowResponseSchema,
  type DesktopVoiceFlowRequest,
  type VoiceFlowResponse,
} from '@typeless-open/shared'

import { desktopBridge } from './desktop'

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''

  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }

  return btoa(binary)
}

export async function fetchVoiceRuntime() {
  return VoiceGatewayRuntimeSchema.parse(await desktopBridge.getVoiceRuntime())
}

export async function submitVoiceFlow(input: {
  mode: DesktopVoiceFlowRequest['mode']
  context: DesktopVoiceFlowRequest['context']
  metadata: DesktopVoiceFlowRequest['metadata']
  audioBlob: Blob | null
  audioFilename: string
}): Promise<VoiceFlowResponse> {
  const request = DesktopVoiceFlowRequestSchema.parse({
    mode: input.mode,
    context: input.context,
    metadata: input.metadata,
    audioFile: input.audioBlob
      ? {
          filename: input.audioFilename,
          mimeType: input.audioBlob.type || 'audio/webm',
          base64: arrayBufferToBase64(await input.audioBlob.arrayBuffer()),
        }
      : null,
  })

  return VoiceFlowResponseSchema.parse(await desktopBridge.runVoiceFlow(request))
}

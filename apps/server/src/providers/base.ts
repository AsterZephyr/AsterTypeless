import type { VoiceContext, VoiceFlowResponse, VoiceMode, VoiceRequestMetadata } from '@typeless-open/shared'

export type VoiceProviderInput = {
  mode: VoiceMode
  context: VoiceContext
  metadata: VoiceRequestMetadata
  audioFile:
    | {
        buffer: Buffer
        mimeType: string
        filename: string
      }
    | null
}

export interface VoiceProvider {
  readonly name: string
  run(input: VoiceProviderInput): Promise<VoiceFlowResponse>
}


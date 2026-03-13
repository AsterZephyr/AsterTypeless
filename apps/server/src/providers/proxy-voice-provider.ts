import { VoiceFlowResponseSchema, buildContextDigest } from '@typeless-open/shared'

import type { VoiceProvider, VoiceProviderInput } from './base'

type ProxyVoiceProviderOptions = {
  endpoint: string
  apiKey?: string
}

export class ProxyVoiceProvider implements VoiceProvider {
  readonly name = 'proxy'

  constructor(private readonly options: ProxyVoiceProviderOptions) {}

  async run(input: VoiceProviderInput) {
    const response = await fetch(this.options.endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        ...(this.options.apiKey ? { authorization: `Bearer ${this.options.apiKey}` } : {}),
      },
      body: JSON.stringify({
        mode: input.mode,
        context: input.context,
        metadata: input.metadata,
        audioFile: input.audioFile
          ? {
              filename: input.audioFile.filename,
              mimeType: input.audioFile.mimeType,
              base64: input.audioFile.buffer.toString('base64'),
            }
          : null,
      }),
    })

    if (!response.ok) {
      const detail = await response.text()
      throw new Error(`Upstream voice flow failed (${response.status}): ${detail}`)
    }

    const payload = await response.json()
    const normalizedPayload =
      typeof payload === 'object' && payload !== null && 'data' in payload
        ? payload.data
        : payload
    const parsed = VoiceFlowResponseSchema.safeParse(normalizedPayload)

    if (!parsed.success) {
      throw new Error(
        `Upstream voice flow returned an unexpected payload: ${parsed.error.message}`,
      )
    }

    return {
      ...parsed.data,
      debug: {
        ...parsed.data.debug,
        provider: this.name,
        contextDigest: buildContextDigest(input.context),
      },
    }
  }
}

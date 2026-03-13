import type { VoiceGatewayRuntime } from '@typeless-open/shared'

import type { VoiceGatewayConfig } from './config'
import { MockVoiceProvider } from './providers/mock-voice-provider'
import { ProxyVoiceProvider } from './providers/proxy-voice-provider'
import type { VoiceProvider, VoiceProviderInput } from './providers/base'

function createVoiceProvider(config: VoiceGatewayConfig): VoiceProvider {
  if (config.voiceProvider === 'proxy') {
    if (!config.upstreamVoiceFlowUrl) {
      throw new Error('VOICE_PROVIDER=proxy requires UPSTREAM_VOICE_FLOW_URL')
    }

    return new ProxyVoiceProvider({
      endpoint: config.upstreamVoiceFlowUrl,
      apiKey: config.upstreamApiKey,
    })
  }

  return new MockVoiceProvider()
}

export class VoiceFlowService {
  private readonly config: VoiceGatewayConfig
  private readonly provider: VoiceProvider

  constructor(config: VoiceGatewayConfig) {
    this.config = config
    this.provider = createVoiceProvider(config)
  }

  getRuntime(): VoiceGatewayRuntime {
    return {
      provider: this.provider.name,
      transport: 'ipc',
      upstreamConfigured: Boolean(this.config.upstreamVoiceFlowUrl),
    }
  }

  run(input: VoiceProviderInput) {
    return this.provider.run(input)
  }
}

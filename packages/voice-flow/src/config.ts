const DEFAULT_PROVIDER = 'mock'

export type VoiceGatewayConfig = {
  voiceProvider: string
  upstreamVoiceFlowUrl: string
  upstreamApiKey: string
}

export function resolveVoiceGatewayConfig(env: NodeJS.ProcessEnv = process.env): VoiceGatewayConfig {
  return {
    voiceProvider:
      env.VOICE_PROVIDER || (env.UPSTREAM_VOICE_FLOW_URL ? 'proxy' : DEFAULT_PROVIDER),
    upstreamVoiceFlowUrl: env.UPSTREAM_VOICE_FLOW_URL || '',
    upstreamApiKey: env.UPSTREAM_API_KEY || '',
  }
}

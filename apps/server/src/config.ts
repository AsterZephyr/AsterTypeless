const DEFAULT_PORT = 8787
const DEFAULT_HOST = '127.0.0.1'

function parsePort(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isFinite(parsed) ? parsed : DEFAULT_PORT
}

export const serverConfig = {
  host: process.env.HOST || DEFAULT_HOST,
  port: parsePort(process.env.PORT),
  voiceProvider:
    process.env.VOICE_PROVIDER || (process.env.UPSTREAM_VOICE_FLOW_URL ? 'proxy' : 'mock'),
  upstreamVoiceFlowUrl: process.env.UPSTREAM_VOICE_FLOW_URL || '',
  upstreamApiKey: process.env.UPSTREAM_API_KEY || '',
}


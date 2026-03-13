import Fastify from 'fastify'
import cors from '@fastify/cors'
import multipart from '@fastify/multipart'
import {
  HealthResponseSchema,
  VoiceContextSchema,
  VoiceModeSchema,
  VoiceRequestMetadataSchema,
  VoiceFlowResponseSchema,
} from '@typeless-open/shared'
import { VoiceFlowService, resolveVoiceGatewayConfig, type VoiceProviderInput } from '@typeless-open/voice-flow'

const DEFAULT_PORT = 8787
const DEFAULT_HOST = '127.0.0.1'

function parsePort(value: string | undefined): number {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isFinite(parsed) ? parsed : DEFAULT_PORT
}

const serverConfig = {
  host: process.env.HOST || DEFAULT_HOST,
  port: parsePort(process.env.PORT),
}

const voiceFlowService = new VoiceFlowService(resolveVoiceGatewayConfig(process.env))

const app = Fastify({
  logger: true,
})

await app.register(cors, {
  origin: true,
})

await app.register(multipart, {
  limits: {
    fileSize: 20 * 1024 * 1024,
    files: 1,
  },
})

app.get('/health', async () => {
  return HealthResponseSchema.parse({
    ok: true,
    provider: voiceFlowService.getRuntime().provider,
    timestamp: new Date().toISOString(),
    upstreamConfigured: voiceFlowService.getRuntime().upstreamConfigured,
  })
})

app.get('/v1/runtime', async () => {
  return {
    provider: voiceFlowService.getRuntime().provider,
    port: serverConfig.port,
    host: serverConfig.host,
  }
})

app.post('/v1/voice/flow', async (request, reply) => {
  const startedAt = performance.now()
  const input = await parseVoiceFlowRequest(request)
  const result = await voiceFlowService.run(input)
  const payload = VoiceFlowResponseSchema.parse({
    ...result,
    latencyMs: Math.max(result.latencyMs, Math.round(performance.now() - startedAt)),
  })

  return reply.send(payload)
})

app.setErrorHandler((error, _request, reply) => {
  app.log.error(error)
  const message = error instanceof Error ? error.message : 'Unexpected error'
  void reply.status(500).send({
    error: message,
  })
})

try {
  await app.listen({
    host: serverConfig.host,
    port: serverConfig.port,
  })
  app.log.info(
    `Typeless open gateway listening on http://${serverConfig.host}:${serverConfig.port}`,
  )
} catch (error) {
  app.log.error(error)
  const message = error instanceof Error ? error.message : 'Unknown startup error'
  app.log.error(message)
  process.exit(1)
}

async function parseVoiceFlowRequest(
  request: Parameters<typeof app.post>[1] extends never ? never : any,
): Promise<VoiceProviderInput> {
  const fields = new Map<string, string>()
  let audioFile: VoiceProviderInput['audioFile'] = null

  for await (const part of request.parts()) {
    if (part.type === 'file') {
      const chunks: Buffer[] = []

      for await (const chunk of part.file) {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk))
      }

      audioFile = {
        buffer: Buffer.concat(chunks),
        filename: part.filename || 'voice-input.webm',
        mimeType: part.mimetype || 'application/octet-stream',
      }
      continue
    }

    fields.set(part.fieldname, String(part.value))
  }

  const mode = VoiceModeSchema.parse(fields.get('mode') || 'dictate')
  const context = VoiceContextSchema.parse(parseJsonField(fields.get('context')))
  const metadata = VoiceRequestMetadataSchema.parse(parseJsonField(fields.get('metadata')))

  return {
    mode,
    context,
    metadata,
    audioFile,
  }
}

function parseJsonField(value: string | undefined) {
  if (!value) return {}
  try {
    return JSON.parse(value)
  } catch {
    return {}
  }
}

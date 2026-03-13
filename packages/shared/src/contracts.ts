import { z } from 'zod'

export const voiceModes = ['dictate', 'rewrite', 'translate', 'ask'] as const

export const VoiceModeSchema = z.enum(voiceModes)

export const VoiceContextSchema = z.object({
  focusedAppName: z.string().default('Any app'),
  selectedText: z.string().default(''),
  surroundingText: z.string().default(''),
  transcriptHint: z.string().default(''),
  targetLanguage: z.string().default('English'),
})

export const VoiceRequestMetadataSchema = z.object({
  client: z.string().default('desktop'),
  durationMs: z.number().nonnegative().default(0),
  mimeType: z.string().default('audio/webm'),
  source: z.enum(['microphone', 'text-hint']).default('text-hint'),
})

export const VoiceDeliverySchema = z.object({
  kind: z.enum(['replace-selection', 'insert-after-cursor', 'copy-only']),
  richText: z.string().optional(),
})

export const VoiceDebugSchema = z.object({
  provider: z.string(),
  transcriptSource: z.enum(['audio', 'text-hint', 'selected-text', 'mock']),
  audioProvided: z.boolean(),
  contextDigest: z.string(),
})

export const VoiceFlowResponseSchema = z.object({
  requestId: z.string(),
  mode: VoiceModeSchema,
  refinedText: z.string(),
  delivery: VoiceDeliverySchema,
  debug: VoiceDebugSchema,
  latencyMs: z.number().nonnegative(),
})

export const DesktopHistoryItemSchema = z.object({
  id: z.string(),
  createdAt: z.string(),
  mode: VoiceModeSchema,
  focusedAppName: z.string(),
  inputPreview: z.string(),
  refinedText: z.string(),
  provider: z.string(),
  latencyMs: z.number().nonnegative(),
})

export const DesktopRuntimeInfoSchema = z.object({
  appName: z.string(),
  appVersion: z.string(),
  platform: z.string(),
  userDataPath: z.string(),
})

export const DesktopNativeStatusSchema = z.object({
  helperAvailable: z.boolean(),
  helperPath: z.string().default(''),
  accessibilityTrusted: z.boolean(),
  accessibilityPermissionPrompted: z.boolean().default(false),
  listenEventAccess: z.boolean().default(false),
  listenEventAccessPrompted: z.boolean().default(false),
  fnTriggerEnabled: z.boolean().default(false),
  triggerSource: z.enum(['fn', 'shortcut']).default('shortcut'),
  focusedAppName: z.string().default(''),
  focusedBundleId: z.string().default(''),
  lastError: z.string().default(''),
})

export const DesktopCapturedContextSchema = z.object({
  triggerSource: z.enum(['fn', 'shortcut', 'manual']).default('manual'),
  focusedAppName: z.string().default(''),
  focusedBundleId: z.string().default(''),
  selectedText: z.string().default(''),
  surroundingText: z.string().default(''),
  capturedAt: z.string(),
})

export const DesktopSelectionSnapshotSchema = z.object({
  available: z.boolean(),
  selectedText: z.string().default(''),
  surroundingText: z.string().default(''),
  focusedAppName: z.string().default(''),
  focusedBundleId: z.string().default(''),
  source: z.enum(['accessibility', 'derived-value', 'clipboard', 'unavailable']),
  lastError: z.string().default(''),
})

export const DesktopInsertTextRequestSchema = z.object({
  text: z.string(),
  preferredBundleId: z.string().default(''),
})

export const DesktopInsertTextResultSchema = z.object({
  ok: z.boolean(),
  method: z.enum(['replace-selection', 'append-value', 'pasteboard', 'unavailable']),
  focusedAppName: z.string().default(''),
  focusedBundleId: z.string().default(''),
  lastError: z.string().default(''),
})

export const HealthResponseSchema = z.object({
  ok: z.literal(true),
  provider: z.string(),
  timestamp: z.string(),
  upstreamConfigured: z.boolean(),
})

export const VoiceGatewayRuntimeSchema = z.object({
  provider: z.string(),
  transport: z.enum(['ipc', 'http']),
  upstreamConfigured: z.boolean(),
})

export const DesktopAudioFileSchema = z.object({
  filename: z.string(),
  mimeType: z.string(),
  base64: z.string(),
})

export const DesktopVoiceFlowRequestSchema = z.object({
  mode: VoiceModeSchema,
  context: VoiceContextSchema,
  metadata: VoiceRequestMetadataSchema,
  audioFile: DesktopAudioFileSchema.nullable(),
})

export type VoiceMode = z.infer<typeof VoiceModeSchema>
export type VoiceContext = z.infer<typeof VoiceContextSchema>
export type VoiceRequestMetadata = z.infer<typeof VoiceRequestMetadataSchema>
export type VoiceFlowResponse = z.infer<typeof VoiceFlowResponseSchema>
export type DesktopHistoryItem = z.infer<typeof DesktopHistoryItemSchema>
export type DesktopRuntimeInfo = z.infer<typeof DesktopRuntimeInfoSchema>
export type DesktopNativeStatus = z.infer<typeof DesktopNativeStatusSchema>
export type DesktopCapturedContext = z.infer<typeof DesktopCapturedContextSchema>
export type DesktopSelectionSnapshot = z.infer<typeof DesktopSelectionSnapshotSchema>
export type DesktopInsertTextRequest = z.infer<typeof DesktopInsertTextRequestSchema>
export type DesktopInsertTextResult = z.infer<typeof DesktopInsertTextResultSchema>
export type HealthResponse = z.infer<typeof HealthResponseSchema>
export type VoiceGatewayRuntime = z.infer<typeof VoiceGatewayRuntimeSchema>
export type DesktopVoiceFlowRequest = z.infer<typeof DesktopVoiceFlowRequestSchema>

export function buildContextDigest(context: VoiceContext): string {
  const selected = context.selectedText.trim().slice(0, 48)
  const transcript = context.transcriptHint.trim().slice(0, 48)
  const surrounding = context.surroundingText.trim().slice(0, 48)
  return [context.focusedAppName, selected, transcript, surrounding]
    .filter(Boolean)
    .join(' • ')
}

export function createHistoryPreview(text: string): string {
  return text.replace(/\s+/g, ' ').trim().slice(0, 140)
}

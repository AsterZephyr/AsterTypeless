import {
  buildContextDigest,
  type VoiceContext,
  type VoiceFlowResponse,
  type VoiceMode,
} from '@typeless-open/shared'

import type { VoiceProvider, VoiceProviderInput } from './base'

function cleanupDictation(text: string): string {
  return text
    .replace(/\b(um|uh|like|you know|sort of)\b/gi, '')
    .replace(/\s+/g, ' ')
    .replace(/\s+([,.!?;:])/g, '$1')
    .trim()
}

function sentenceCase(text: string): string {
  if (!text) return ''
  return text.charAt(0).toUpperCase() + text.slice(1)
}

function sourceText(context: VoiceContext): {
  text: string
  transcriptSource: VoiceFlowResponse['debug']['transcriptSource']
} {
  if (context.transcriptHint.trim()) {
    return { text: context.transcriptHint.trim(), transcriptSource: 'text-hint' }
  }
  if (context.selectedText.trim()) {
    return { text: context.selectedText.trim(), transcriptSource: 'selected-text' }
  }
  return { text: '', transcriptSource: 'mock' }
}

function refine(
  mode: VoiceMode,
  context: VoiceContext,
): {
  text: string
  delivery: VoiceFlowResponse['delivery']
  transcriptSource: VoiceFlowResponse['debug']['transcriptSource']
} {
  const { text: rawSource, transcriptSource } = sourceText(context)
  const clean = cleanupDictation(rawSource)
  const focusedApp = context.focusedAppName || 'your app'

  if (!clean) {
    return {
      text: `Open Typeless in ${focusedApp}, speak naturally, and your polished output will land here.`,
      delivery: { kind: 'copy-only' },
      transcriptSource,
    }
  }

  switch (mode) {
    case 'dictate':
      return {
        text: `${sentenceCase(clean)}${/[.!?]$/.test(clean) ? '' : '.'}`,
        delivery: { kind: 'insert-after-cursor' },
        transcriptSource,
      }
    case 'rewrite':
      return {
        text: sentenceCase(clean)
          .replace(/\bi\b/g, 'I')
          .replace(/\s+/g, ' ')
          .trim(),
        delivery: { kind: 'replace-selection' },
        transcriptSource,
      }
    case 'translate':
      return {
        text: `[${context.targetLanguage}] ${sentenceCase(clean)}`,
        delivery: { kind: 'replace-selection' },
        transcriptSource,
      }
    case 'ask':
      return {
        text: `Based on the current context in ${focusedApp}, the key idea is: ${sentenceCase(clean)}.`,
        delivery: { kind: 'copy-only' },
        transcriptSource,
      }
    default:
      return {
        text: sentenceCase(clean),
        delivery: { kind: 'copy-only' },
        transcriptSource,
      }
  }
}

export class MockVoiceProvider implements VoiceProvider {
  readonly name = 'mock'

  async run(input: VoiceProviderInput): Promise<VoiceFlowResponse> {
    const startedAt = performance.now()
    const refined = refine(input.mode, input.context)

    return {
      requestId: crypto.randomUUID(),
      mode: input.mode,
      refinedText: refined.text,
      delivery: refined.delivery,
      latencyMs: Math.round(performance.now() - startedAt),
      debug: {
        provider: this.name,
        transcriptSource: refined.transcriptSource,
        audioProvided: Boolean(input.audioFile),
        contextDigest: buildContextDigest(input.context),
      },
    }
  }
}

import { useRef, useState } from 'react'

type RecorderState = {
  audioBlob: Blob | null
  audioFilename: string
  durationMs: number
  isRecording: boolean
  error: string | null
}

const initialState: RecorderState = {
  audioBlob: null,
  audioFilename: 'voice-input.webm',
  durationMs: 0,
  isRecording: false,
  error: null,
}

function preferredMimeType() {
  const candidates = [
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/ogg;codecs=opus',
    'audio/ogg',
  ]

  return candidates.find((candidate) => MediaRecorder.isTypeSupported(candidate)) || ''
}

export function useVoiceRecorder() {
  const [state, setState] = useState<RecorderState>(initialState)
  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const chunksRef = useRef<Blob[]>([])
  const timerRef = useRef<number | null>(null)
  const startedAtRef = useRef(0)

  function clearTimer() {
    if (timerRef.current !== null) {
      window.clearInterval(timerRef.current)
      timerRef.current = null
    }
  }

  function releaseStream() {
    streamRef.current?.getTracks().forEach((track) => track.stop())
    streamRef.current = null
  }

  async function startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mimeType = preferredMimeType()
      const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined)

      streamRef.current = stream
      mediaRecorderRef.current = recorder
      chunksRef.current = []
      startedAtRef.current = Date.now()

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunksRef.current.push(event.data)
        }
      }

      recorder.start()

      setState((current) => ({
        ...current,
        isRecording: true,
        error: null,
        audioBlob: null,
        durationMs: 0,
        audioFilename: mimeType.includes('ogg') ? 'voice-input.ogg' : 'voice-input.webm',
      }))

      timerRef.current = window.setInterval(() => {
        setState((current) => ({
          ...current,
          durationMs: Date.now() - startedAtRef.current,
        }))
      }, 120)
    } catch (error) {
      setState((current) => ({
        ...current,
        error: error instanceof Error ? error.message : 'Microphone access failed',
      }))
    }
  }

  async function stopRecording() {
    const recorder = mediaRecorderRef.current

    if (!recorder || recorder.state === 'inactive') {
      return
    }

    await new Promise<void>((resolve) => {
      recorder.onstop = () => {
        const mimeType = recorder.mimeType || 'audio/webm'
        const audioBlob = new Blob(chunksRef.current, { type: mimeType })

        clearTimer()
        releaseStream()
        mediaRecorderRef.current = null

        setState((current) => ({
          ...current,
          isRecording: false,
          durationMs: Date.now() - startedAtRef.current,
          audioBlob,
          audioFilename: mimeType.includes('ogg') ? 'voice-input.ogg' : 'voice-input.webm',
        }))

        resolve()
      }

      recorder.stop()
    })
  }

  function clearRecording() {
    clearTimer()
    releaseStream()
    mediaRecorderRef.current = null
    chunksRef.current = []
    setState(initialState)
  }

  return {
    ...state,
    startRecording,
    stopRecording,
    clearRecording,
  }
}


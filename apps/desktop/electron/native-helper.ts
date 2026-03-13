import { execFile, spawn, type ChildProcess } from 'node:child_process'
import fsSync from 'node:fs'
import path from 'node:path'
import { promisify } from 'node:util'

import {
  DesktopInsertTextRequestSchema,
  DesktopInsertTextResultSchema,
  DesktopNativeStatusSchema,
  DesktopSelectionSnapshotSchema,
} from '@typeless-open/shared'

const execFileAsync = promisify(execFile)

type NativeHelperCommand =
  | 'status'
  | 'prompt-accessibility'
  | 'prompt-listen-events'
  | 'read-selection'
  | 'insert-text'
type NativeHelperStrategy = 'swift' | 'objc'

export type NativeFnMonitorEvent =
  | {
      type: 'ready'
      listenEventAccess: boolean
      lastError: string
    }
  | {
      type: 'fn-press'
    }
  | {
      type: 'error'
      listenEventAccess: boolean
      lastError: string
    }

interface NativeHelperBuildState {
  strategy: NativeHelperStrategy
  sourceMtimes: Partial<Record<NativeHelperStrategy, number>>
}

interface NativeHelperBuildTarget {
  strategy: NativeHelperStrategy
  sourcePath: string
  compileCommand: string
  compileArgs: string[]
}

export class NativeHelperBridge {
  private readonly appRoot: string
  private readonly userDataPath: string

  constructor(appRoot: string, userDataPath: string) {
    this.appRoot = appRoot
    this.userDataPath = userDataPath
  }

  async getStatus() {
    return this.run(
      'status',
      (value) => DesktopNativeStatusSchema.parse(value),
      this.fallbackStatus(false),
      (helperAvailable, helperPath, lastError) =>
        this.fallbackStatus(helperAvailable, helperPath, lastError),
    )
  }

  async promptAccessibilityPermission() {
    return this.run(
      'prompt-accessibility',
      (value) => DesktopNativeStatusSchema.parse(value),
      this.fallbackStatus(false),
      (helperAvailable, helperPath, lastError) =>
        this.fallbackStatus(helperAvailable, helperPath, lastError),
    )
  }

  async promptListenEventAccess() {
    return this.run(
      'prompt-listen-events',
      (value) => DesktopNativeStatusSchema.parse(value),
      this.fallbackStatus(false),
      (helperAvailable, helperPath, lastError) =>
        this.fallbackStatus(helperAvailable, helperPath, lastError),
    )
  }

  async readSelection() {
    return this.run(
      'read-selection',
      (value) => DesktopSelectionSnapshotSchema.parse(value),
      this.fallbackSelection(false),
      (helperAvailable, _helperPath, lastError) => this.fallbackSelection(helperAvailable, lastError),
    )
  }

  async insertText(input: unknown) {
    const payload = DesktopInsertTextRequestSchema.parse(input)
    const textBase64 = Buffer.from(payload.text, 'utf8').toString('base64')

    return this.run(
      'insert-text',
      (value) => DesktopInsertTextResultSchema.parse(value),
      this.fallbackInsertText(),
      (_helperAvailable, _helperPath, lastError) => this.fallbackInsertText(lastError),
      [textBase64, payload.preferredBundleId],
    )
  }

  async startFnWatcher(onEvent: (event: NativeFnMonitorEvent) => void): Promise<ChildProcess | null> {
    const binaryPath = await this.ensureBuilt()

    if (!binaryPath) {
      onEvent({
        type: 'error',
        listenEventAccess: false,
        lastError: this.lastBuildError || 'Native helper is unavailable.',
      })
      return null
    }

    const child = spawn(binaryPath, ['watch-fn'], {
      stdio: ['ignore', 'pipe', 'pipe'],
    })

    let stdoutBuffer = ''
    let stderrBuffer = ''

    child.stdout.setEncoding('utf8')
    child.stdout.on('data', (chunk) => {
      stdoutBuffer += chunk

      let newlineIndex = stdoutBuffer.indexOf('\n')
      while (newlineIndex !== -1) {
        const line = stdoutBuffer.slice(0, newlineIndex).trim()
        stdoutBuffer = stdoutBuffer.slice(newlineIndex + 1)

        if (line) {
          this.handleFnMonitorLine(line, onEvent)
        }

        newlineIndex = stdoutBuffer.indexOf('\n')
      }
    })

    child.stderr.setEncoding('utf8')
    child.stderr.on('data', (chunk) => {
      stderrBuffer += chunk
    })

    child.on('error', (error) => {
      onEvent({
        type: 'error',
        listenEventAccess: false,
        lastError: this.normalizeError(error),
      })
    })

    child.on('exit', () => {
      const message = stderrBuffer
        .split('\n')
        .map((line) => line.trim())
        .find(Boolean)

      if (message) {
        onEvent({
          type: 'error',
          listenEventAccess: false,
          lastError: message,
        })
      }
    })

    return child
  }

  private getSourcePath() {
    return path.join(this.appRoot, 'native', 'TypelessNativeHelper.swift')
  }

  private getObjcSourcePath() {
    return path.join(this.appRoot, 'native', 'TypelessNativeHelper.m')
  }

  private getBinaryPath() {
    return path.join(this.userDataPath, 'native', 'typeless-native-helper')
  }

  private getBuildStatePath() {
    return path.join(this.userDataPath, 'native', 'typeless-native-helper.build.json')
  }

  private getBuildTargets(binaryPath: string): NativeHelperBuildTarget[] {
    const targets: NativeHelperBuildTarget[] = [
      {
        strategy: 'objc',
        sourcePath: this.getObjcSourcePath(),
        compileCommand: '/usr/bin/clang',
        compileArgs: [
          '-fobjc-arc',
          '-framework',
          'AppKit',
          '-framework',
          'ApplicationServices',
          this.getObjcSourcePath(),
          '-o',
          binaryPath,
        ],
      },
      {
        strategy: 'swift',
        sourcePath: this.getSourcePath(),
        compileCommand: '/usr/bin/xcrun',
        compileArgs: [
          'swiftc',
          '-O',
          '-framework',
          'AppKit',
          '-framework',
          'ApplicationServices',
          this.getSourcePath(),
          '-o',
          binaryPath,
        ],
      },
    ]

    return targets.filter((target) => fsSync.existsSync(target.sourcePath))
  }

  private async run<T>(
    command: NativeHelperCommand,
    parse: (value: unknown) => T,
    missingHelperFallback: T,
    fallbackFactory: (helperAvailable: boolean, helperPath: string, lastError: string) => T,
    args: string[] = [],
  ): Promise<T> {
    const binaryPath = await this.ensureBuilt()

    if (!binaryPath) {
      return missingHelperFallback
    }

    try {
      const { stdout } = await execFileAsync(binaryPath, [command, ...args], {
        timeout: 8_000,
      })
      const parsed = JSON.parse(stdout || '{}')
      return parse(parsed)
    } catch (error) {
      return fallbackFactory(true, binaryPath, this.normalizeError(error))
    }
  }

  private async ensureBuilt() {
    const binaryPath = this.getBinaryPath()
    const buildStatePath = this.getBuildStatePath()
    const buildTargets = this.getBuildTargets(binaryPath)

    if (buildTargets.length === 0) {
      return null
    }

    const binaryExists = fsSync.existsSync(binaryPath)
    const currentSourceMtimes = Object.fromEntries(
      buildTargets.map((target) => [target.strategy, fsSync.statSync(target.sourcePath).mtimeMs]),
    ) as Partial<Record<NativeHelperStrategy, number>>
    const previousBuildState = this.readBuildState(buildStatePath)
    const shouldCompile =
      !binaryExists || !this.matchesBuildState(previousBuildState, currentSourceMtimes)

    if (!shouldCompile) {
      this.lastBuildError = ''
      return binaryPath
    }

    fsSync.mkdirSync(path.dirname(binaryPath), { recursive: true })

    const buildErrors: string[] = []

    for (const target of buildTargets) {
      try {
        await execFileAsync(target.compileCommand, target.compileArgs, {
          timeout: 10_000,
        })
        this.writeBuildState(buildStatePath, {
          strategy: target.strategy,
          sourceMtimes: currentSourceMtimes,
        })
        this.lastBuildError = ''
        return binaryPath
      } catch (error) {
        buildErrors.push(`${target.strategy}: ${this.normalizeError(error)}`)
      }
    }

    this.lastBuildError = buildErrors.join(' | ')
    return null
  }

  private lastBuildError = ''

  private readBuildState(buildStatePath: string) {
    if (!fsSync.existsSync(buildStatePath)) {
      return null
    }

    try {
      const raw = fsSync.readFileSync(buildStatePath, 'utf8')
      const parsed = JSON.parse(raw) as NativeHelperBuildState

      if (!parsed || typeof parsed !== 'object' || !parsed.sourceMtimes) {
        return null
      }

      return parsed
    } catch {
      return null
    }
  }

  private writeBuildState(buildStatePath: string, buildState: NativeHelperBuildState) {
    fsSync.writeFileSync(buildStatePath, `${JSON.stringify(buildState, null, 2)}\n`, 'utf8')
  }

  private matchesBuildState(
    buildState: NativeHelperBuildState | null,
    currentSourceMtimes: Partial<Record<NativeHelperStrategy, number>>,
  ) {
    if (!buildState) {
      return false
    }

    return (Object.entries(currentSourceMtimes) as Array<[NativeHelperStrategy, number]>).every(
      ([strategy, mtimeMs]) => buildState.sourceMtimes[strategy] === mtimeMs,
    )
  }

  private fallbackStatus(helperAvailable: boolean, helperPath = '', lastError = '') {
    return DesktopNativeStatusSchema.parse({
      helperAvailable,
      helperPath,
      accessibilityTrusted: false,
      accessibilityPermissionPrompted: false,
      listenEventAccess: false,
      listenEventAccessPrompted: false,
      fnTriggerEnabled: false,
      triggerSource: 'shortcut',
      focusedAppName: '',
      focusedBundleId: '',
      lastError: lastError || this.lastBuildError,
    })
  }

  private fallbackSelection(_helperAvailable: boolean, lastError = '') {
    return DesktopSelectionSnapshotSchema.parse({
      available: false,
      selectedText: '',
      surroundingText: '',
      focusedAppName: '',
      focusedBundleId: '',
      source: 'unavailable',
      lastError: lastError || this.lastBuildError,
    })
  }

  private fallbackInsertText(lastError = '') {
    return DesktopInsertTextResultSchema.parse({
      ok: false,
      method: 'unavailable',
      focusedAppName: '',
      focusedBundleId: '',
      lastError: lastError || this.lastBuildError,
    })
  }

  private normalizeError(error: unknown) {
    if (!(error instanceof Error)) {
      return 'Unable to build or run the macOS native helper.'
    }

    const stderr = 'stderr' in error && typeof error.stderr === 'string' ? error.stderr : ''
    const stdout = 'stdout' in error && typeof error.stdout === 'string' ? error.stdout : ''
    const combined = [stderr, stdout, error.message].join('\n')

    if (combined.includes('this SDK is not supported by the compiler')) {
      return 'Swift toolchain does not match the installed macOS SDK. Open Xcode once or reinstall Command Line Tools.'
    }

    if (combined.includes("redefinition of module 'SwiftBridging'")) {
      return 'Command Line Tools install is inconsistent and duplicates SwiftBridging module maps.'
    }

    const message = combined
      .split('\n')
      .map((line) => line.trim())
      .find((line) => Boolean(line) && !line.startsWith('/'))

    return message || 'Unable to build or run the macOS native helper.'
  }

  private handleFnMonitorLine(line: string, onEvent: (event: NativeFnMonitorEvent) => void) {
    try {
      const parsed = JSON.parse(line)

      if (parsed?.type === 'fn-press') {
        onEvent({ type: 'fn-press' })
        return
      }

      if (parsed?.type === 'ready') {
        const status = DesktopNativeStatusSchema.parse({
          helperAvailable: true,
          helperPath: '',
          accessibilityTrusted: false,
          accessibilityPermissionPrompted: false,
          ...parsed,
        })

        onEvent({
          type: 'ready',
          listenEventAccess: status.listenEventAccess,
          lastError: status.lastError,
        })
        return
      }

      if (parsed?.type === 'error') {
        const status = DesktopNativeStatusSchema.parse({
          helperAvailable: true,
          helperPath: '',
          accessibilityTrusted: false,
          accessibilityPermissionPrompted: false,
          ...parsed,
        })

        onEvent({
          type: 'error',
          listenEventAccess: status.listenEventAccess,
          lastError: status.lastError,
        })
      }
    } catch {
      onEvent({
        type: 'error',
        listenEventAccess: false,
        lastError: line,
      })
    }
  }
}

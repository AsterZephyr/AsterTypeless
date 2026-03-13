import { execFile } from 'node:child_process'
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

type NativeHelperCommand = 'status' | 'prompt-accessibility' | 'read-selection' | 'insert-text'
type NativeHelperStrategy = 'swift' | 'objc'

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
}

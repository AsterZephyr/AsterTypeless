import { execFile } from 'node:child_process'
import fsSync from 'node:fs'
import path from 'node:path'
import { promisify } from 'node:util'

import { DesktopNativeStatusSchema, type DesktopNativeStatus } from '@typeless-open/shared'

const execFileAsync = promisify(execFile)

type NativeHelperCommand = 'status' | 'prompt-accessibility'

export class NativeHelperBridge {
  private readonly appRoot: string
  private readonly userDataPath: string

  constructor(appRoot: string, userDataPath: string) {
    this.appRoot = appRoot
    this.userDataPath = userDataPath
  }

  async getStatus() {
    return this.run('status')
  }

  async promptAccessibilityPermission() {
    return this.run('prompt-accessibility')
  }

  private getSourcePath() {
    return path.join(this.appRoot, 'native', 'TypelessNativeHelper.swift')
  }

  private getBinaryPath() {
    return path.join(this.userDataPath, 'native', 'typeless-native-helper')
  }

  private async run(command: NativeHelperCommand): Promise<DesktopNativeStatus> {
    const binaryPath = await this.ensureBuilt()

    if (!binaryPath) {
      return this.fallbackStatus(false)
    }

    try {
      const { stdout } = await execFileAsync(binaryPath, [command], {
        timeout: 8_000,
      })
      const parsed = JSON.parse(stdout || '{}')
      return DesktopNativeStatusSchema.parse(parsed)
    } catch (error) {
      return this.fallbackStatus(true, binaryPath, this.normalizeError(error))
    }
  }

  private async ensureBuilt() {
    const sourcePath = this.getSourcePath()
    const binaryPath = this.getBinaryPath()

    if (!fsSync.existsSync(sourcePath)) {
      return null
    }

    const sourceStat = fsSync.statSync(sourcePath)
    const binaryExists = fsSync.existsSync(binaryPath)
    const shouldCompile =
      !binaryExists || fsSync.statSync(binaryPath).mtimeMs < sourceStat.mtimeMs

    if (!shouldCompile) {
      this.lastBuildError = ''
      return binaryPath
    }

    fsSync.mkdirSync(path.dirname(binaryPath), { recursive: true })

    try {
      await execFileAsync('/usr/bin/xcrun', [
        'swiftc',
        '-O',
        '-framework',
        'AppKit',
        '-framework',
        'ApplicationServices',
        sourcePath,
        '-o',
        binaryPath,
      ])
      this.lastBuildError = ''
      return binaryPath
    } catch (error) {
      this.lastBuildError = this.normalizeError(error)
      return null
    }
  }

  private lastBuildError = ''

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

    const message = combined
      .split('\n')
      .map((line) => line.trim())
      .find((line) => Boolean(line) && !line.startsWith('/'))

    return message || 'Unable to build or run the macOS native helper.'
  }
}

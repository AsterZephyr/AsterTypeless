import { app, BrowserWindow, clipboard, ipcMain, nativeTheme, shell } from 'electron'
import { fileURLToPath } from 'node:url'
import fs from 'node:fs/promises'
import fsSync from 'node:fs'
import path from 'node:path'

import {
  DesktopHistoryItemSchema,
  DesktopRuntimeInfoSchema,
  DesktopVoiceFlowRequestSchema,
  type DesktopHistoryItem,
} from '@typeless-open/shared'
import { VoiceFlowService, resolveVoiceGatewayConfig } from '@typeless-open/voice-flow'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

process.env.APP_ROOT = path.join(__dirname, '..')

loadWorkspaceEnv(path.resolve(process.env.APP_ROOT, '../..', '.env'))

const VITE_DEV_SERVER_URL = process.env.VITE_DEV_SERVER_URL
const RENDERER_DIST = path.join(process.env.APP_ROOT, 'dist')

let mainWindow: BrowserWindow | null = null

nativeTheme.themeSource = 'dark'

function getHistoryFilePath() {
  return path.join(app.getPath('userData'), 'voice-history.json')
}

async function readHistory(): Promise<DesktopHistoryItem[]> {
  try {
    const content = await fs.readFile(getHistoryFilePath(), 'utf8')
    const parsed = JSON.parse(content)
    return Array.isArray(parsed)
      ? parsed
          .map((item) => DesktopHistoryItemSchema.safeParse(item))
          .filter((result) => result.success)
          .map((result) => result.data)
      : []
  } catch {
    return []
  }
}

async function writeHistory(items: DesktopHistoryItem[]) {
  await fs.mkdir(app.getPath('userData'), { recursive: true })
  await fs.writeFile(getHistoryFilePath(), JSON.stringify(items, null, 2), 'utf8')
}

async function saveHistory(item: DesktopHistoryItem) {
  const existing = await readHistory()
  const next = [item, ...existing.filter((entry) => entry.id !== item.id)].slice(0, 30)
  await writeHistory(next)
  return next
}

function loadWorkspaceEnv(envPath: string) {
  if (!fsSync.existsSync(envPath)) {
    return
  }

  const file = fsSync.readFileSync(envPath, 'utf8')

  for (const rawLine of file.split(/\r?\n/)) {
    const line = rawLine.trim()

    if (!line || line.startsWith('#')) {
      continue
    }

    const separatorIndex = line.indexOf('=')
    if (separatorIndex === -1) {
      continue
    }

    const key = line.slice(0, separatorIndex).trim()
    const value = line.slice(separatorIndex + 1).trim().replace(/^['"]|['"]$/g, '')

    if (key && !(key in process.env)) {
      process.env[key] = value
    }
  }
}

function createVoiceFlowService() {
  return new VoiceFlowService(resolveVoiceGatewayConfig(process.env))
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1480,
    height: 940,
    minWidth: 1180,
    minHeight: 760,
    backgroundColor: '#07111f',
    title: 'Typeless Open',
    titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
    webPreferences: {
      preload: path.join(__dirname, 'preload.mjs'),
    },
  })

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    void shell.openExternal(url)
    return { action: 'deny' }
  })

  if (VITE_DEV_SERVER_URL) {
    void mainWindow.loadURL(VITE_DEV_SERVER_URL)
  } else {
    void mainWindow.loadFile(path.join(RENDERER_DIST, 'index.html'))
  }
}

app.whenReady().then(() => {
  createMainWindow()

  ipcMain.handle('desktop:get-runtime-info', async () => {
    return DesktopRuntimeInfoSchema.parse({
      appName: app.getName(),
      appVersion: app.getVersion(),
      platform: process.platform,
      userDataPath: app.getPath('userData'),
    })
  })
  ipcMain.handle('desktop:voice-flow:get-runtime', async () => {
    return createVoiceFlowService().getRuntime()
  })
  ipcMain.handle('desktop:voice-flow:run', async (_event, rawInput: unknown) => {
    const input = DesktopVoiceFlowRequestSchema.parse(rawInput)
    return createVoiceFlowService().run({
      mode: input.mode,
      context: input.context,
      metadata: input.metadata,
      audioFile: input.audioFile
        ? {
            filename: input.audioFile.filename,
            mimeType: input.audioFile.mimeType,
            buffer: Buffer.from(input.audioFile.base64, 'base64'),
          }
        : null,
    })
  })

  ipcMain.handle('desktop:selection:read-fallback', async () => clipboard.readText())
  ipcMain.handle('desktop:clipboard:copy', async (_event, text: string) => {
    clipboard.writeText(text)
    return true
  })
  ipcMain.handle('desktop:history:list', async () => readHistory())
  ipcMain.handle('desktop:history:save', async (_event, rawItem: unknown) => {
    const item = DesktopHistoryItemSchema.parse(rawItem)
    return saveHistory(item)
  })
  ipcMain.handle('desktop:open-external', async (_event, url: string) => {
    await shell.openExternal(url)
    return true
  })

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
    mainWindow = null
  }
})

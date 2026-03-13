import { app, BrowserWindow, clipboard, ipcMain, nativeTheme, shell } from 'electron'
import { DatabaseSync } from 'node:sqlite'
import { fileURLToPath } from 'node:url'
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
let historyDb: DatabaseSync | null = null

nativeTheme.themeSource = 'light'

function getHistoryDatabasePath() {
  return path.join(app.getPath('userData'), 'voice-history.db')
}

function getLegacyHistoryFilePath() {
  return path.join(app.getPath('userData'), 'voice-history.json')
}

async function readHistory(): Promise<DesktopHistoryItem[]> {
  const db = getHistoryDb()
  const rows = db
    .prepare(
      `
        SELECT
          id,
          created_at AS createdAt,
          mode,
          focused_app_name AS focusedAppName,
          input_preview AS inputPreview,
          refined_text AS refinedText,
          provider,
          latency_ms AS latencyMs
        FROM history
        ORDER BY created_at DESC, rowid DESC
        LIMIT 30
      `,
    )
    .all()

  return rows
    .map((row) => DesktopHistoryItemSchema.safeParse(row))
    .filter((result) => result.success)
    .map((result) => result.data)
}

async function saveHistory(item: DesktopHistoryItem) {
  const db = getHistoryDb()

  db.prepare(
    `
      INSERT INTO history (
        id,
        created_at,
        mode,
        focused_app_name,
        input_preview,
        refined_text,
        provider,
        latency_ms
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        created_at = excluded.created_at,
        mode = excluded.mode,
        focused_app_name = excluded.focused_app_name,
        input_preview = excluded.input_preview,
        refined_text = excluded.refined_text,
        provider = excluded.provider,
        latency_ms = excluded.latency_ms
    `,
  ).run(
    item.id,
    item.createdAt,
    item.mode,
    item.focusedAppName,
    item.inputPreview,
    item.refinedText,
    item.provider,
    item.latencyMs,
  )

  db.prepare(
    `
      DELETE FROM history
      WHERE id NOT IN (
        SELECT id
        FROM history
        ORDER BY created_at DESC, rowid DESC
        LIMIT 30
      )
    `,
  ).run()

  return readHistory()
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

function getHistoryDb() {
  if (historyDb) {
    return historyDb
  }

  fsSync.mkdirSync(app.getPath('userData'), { recursive: true })

  historyDb = new DatabaseSync(getHistoryDatabasePath())
  historyDb.exec(`
    CREATE TABLE IF NOT EXISTS history (
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      mode TEXT NOT NULL,
      focused_app_name TEXT NOT NULL,
      input_preview TEXT NOT NULL,
      refined_text TEXT NOT NULL,
      provider TEXT NOT NULL,
      latency_ms INTEGER NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_history_created_at
    ON history(created_at DESC);
  `)

  migrateLegacyHistory(historyDb)

  return historyDb
}

function migrateLegacyHistory(db: DatabaseSync) {
  const row = db.prepare('SELECT COUNT(*) AS count FROM history').get() as { count: number }
  if (row.count > 0) {
    return
  }

  const legacyPath = getLegacyHistoryFilePath()
  if (!fsSync.existsSync(legacyPath)) {
    return
  }

  try {
    const raw = fsSync.readFileSync(legacyPath, 'utf8')
    const parsed = JSON.parse(raw)

    if (!Array.isArray(parsed) || parsed.length === 0) {
      return
    }

    const items = parsed
      .map((item) => DesktopHistoryItemSchema.safeParse(item))
      .filter((result) => result.success)
      .map((result) => result.data)

    if (items.length === 0) {
      return
    }

    db.exec('BEGIN')

    const insert = db.prepare(
      `
        INSERT OR REPLACE INTO history (
          id,
          created_at,
          mode,
          focused_app_name,
          input_preview,
          refined_text,
          provider,
          latency_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `,
    )

    for (const item of items) {
      insert.run(
        item.id,
        item.createdAt,
        item.mode,
        item.focusedAppName,
        item.inputPreview,
        item.refinedText,
        item.provider,
        item.latencyMs,
      )
    }

    db.exec('COMMIT')
    fsSync.renameSync(legacyPath, path.join(app.getPath('userData'), 'voice-history.legacy.json'))
  } catch (error) {
    try {
      db.exec('ROLLBACK')
    } catch {
      // Ignore rollback failure when migration never opened a transaction.
    }
    console.warn('Failed to migrate legacy history store:', error)
  }
}

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 1480,
    height: 940,
    minWidth: 1180,
    minHeight: 760,
    backgroundColor: '#f6f1e8',
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
  historyDb?.close()
  historyDb = null

  if (process.platform !== 'darwin') {
    app.quit()
    mainWindow = null
  }
})

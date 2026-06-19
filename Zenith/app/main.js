const { app, BrowserWindow, globalShortcut, ipcMain, screen, desktopCapturer } = require('electron');
const path = require('path');
const { exec, execSync, spawn } = require('child_process');
const fs = require('fs');

let mainWindow = null;
let overlayWindow = null;
let cardWindow = null;
let backendProcess = null;
let latestScreenshotBase64 = "";

// Determine if in development mode
const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged;

// Temporary path to save screen captures inside the app workspace
const tempScreenshotDir = path.join(app.getPath('userData'), 'temp_captures');
if (!fs.existsSync(tempScreenshotDir)) {
  fs.mkdirSync(tempScreenshotDir, { recursive: true });
}
const screenshotPath = path.join(tempScreenshotDir, 'screenshot.png');

// 1. Launch the Python FastAPI Backend Daemon
function startBackend() {
  const rootDir = path.dirname(__dirname);
  const backendDir = path.join(rootDir, 'core');
  
  // Try using the virtual environment python first, fallback to system python3
  let pythonPath = path.join(backendDir, 'venv', 'bin', 'python');
  if (process.platform === 'win32') {
    pythonPath = path.join(backendDir, 'venv', 'Scripts', 'python.exe');
  }

  // If virtualenv python doesn't exist, use system python3 / python
  if (!fs.existsSync(pythonPath)) {
    pythonPath = process.platform === 'win32' ? 'python' : 'python3';
  }

  console.log(`Starting backend with: ${pythonPath} inside ${backendDir}`);

  // Start uvicorn
  backendProcess = spawn(pythonPath, ['-m', 'uvicorn', 'main:app', '--app-dir', backendDir, '--port', '5001'], {
    cwd: rootDir,
    env: { ...process.env, PYTHONUNBUFFERED: '1' }
  });

  backendProcess.stdout.on('data', (data) => {
    console.log(`[Backend stdout]: ${data}`);
  });

  backendProcess.stderr.on('data', (data) => {
    console.error(`[Backend stderr]: ${data}`);
  });

  backendProcess.on('close', (code) => {
    console.log(`Backend process exited with code ${code}`);
  });
}

// 2. Capture the Screen using Electron's desktopCapturer API
async function captureScreenNative() {
  const primaryDisplay = screen.getPrimaryDisplay();
  const scaleFactor = primaryDisplay.scaleFactor || 1;
  const { width, height } = primaryDisplay.bounds;
  
  const sources = await desktopCapturer.getSources({
    types: ['screen'],
    thumbnailSize: {
      width: width * scaleFactor,
      height: height * scaleFactor
    }
  });

  if (sources.length > 0) {
    // Select the first screen source
    const primarySource = sources[0];
    const imgBuffer = primarySource.thumbnail.toPNG();
    fs.writeFileSync(screenshotPath, imgBuffer);
    return screenshotPath;
  } else {
    throw new Error("No screen sources detected");
  }
}

// 3. Native Active Window Detection
function getActiveWindow() {
  if (process.platform === 'darwin') {
    try {
      const appName = execSync(`osascript -e 'name of application (path to frontmost application as text)'`).toString().trim();
      let windowTitle = "";
      try {
        // Fetch active window title for the frontmost application
        windowTitle = execSync(`osascript -e 'tell application "System Events" to tell process "${appName}" to get name of window 1'`).toString().trim();
      } catch (e) {
        windowTitle = "Active Window";
      }
      return { appName, windowTitle };
    } catch (err) {
      console.error("Mac Active Window Error:", err);
      return { appName: "Desktop", windowTitle: "Desktop View" };
    }
  } else if (process.platform === 'win32') {
    try {
      const psCommand = `powershell -Command "
        Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        public class Win32 {
          [DllImport(\\"user32.dll\\")]
          public static extern IntPtr GetForegroundWindow();
          [DllImport(\\"user32.dll\\")]
          public static extern int GetWindowThreadProcessId(IntPtr hwnd, out int lpdwProcessId);
        }
'@
        [IntPtr]$fg = [Win32]::GetForegroundWindow()
        $pid = 0
        [Win32]::GetWindowThreadProcessId($fg, [ref]$pid)
        $proc = Get-Process -Id $pid
        [PSCustomObject]@{
          ProcessName = $proc.ProcessName
          WindowTitle = $proc.MainWindowTitle
        } | ConvertTo-Json
      "`;
      const output = execSync(psCommand).toString().trim();
      const data = JSON.parse(output);
      return { appName: data.ProcessName, windowTitle: data.WindowTitle };
    } catch (err) {
      console.error("Windows Active Window Error:", err);
      return { appName: "Desktop", windowTitle: "Desktop View" };
    }
  }
  return { appName: "Unknown", windowTitle: "Unknown" };
}

// 4. Create Windows
function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 900,
    height: 700,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  if (isDev) {
    mainWindow.loadURL('http://localhost:5173/?mode=settings');
  } else {
    mainWindow.loadFile(path.join(__dirname, 'dist', 'index.html'), { query: { mode: 'settings' } });
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
    app.quit();
  });
}

function createOverlayWindow() {
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width, height } = primaryDisplay.bounds;

  overlayWindow = new BrowserWindow({
    width,
    height,
    x: 0,
    y: 0,
    hasShadow: false,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    enableLargerThanScreen: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  overlayWindow.setAlwaysOnTop(true, 'screen-saver');

  if (isDev) {
    overlayWindow.loadURL('http://localhost:5173/?mode=overlay');
  } else {
    overlayWindow.loadFile(path.join(__dirname, 'dist', 'index.html'), { query: { mode: 'overlay' } });
  }

  overlayWindow.on('closed', () => {
    overlayWindow = null;
  });
}

function createCardWindow(x, y, data) {
  if (cardWindow) {
    cardWindow.close();
  }

  // Adjust card window placement to be near the cropped box and not overflow screen borders
  const primaryDisplay = screen.getPrimaryDisplay();
  const { width: screenWidth, height: screenHeight } = primaryDisplay.bounds;
  const cardWidth = 380;
  const cardHeight = 520;

  let posX = x + 10;
  let posY = y + 10;

  if (posX + cardWidth > screenWidth) {
    posX = x - cardWidth - 10;
  }
  if (posY + cardHeight > screenHeight) {
    posY = screenHeight - cardHeight - 20;
  }

  cardWindow = new BrowserWindow({
    width: cardWidth,
    height: cardHeight,
    x: Math.max(0, posX),
    y: Math.max(0, posY),
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  cardWindow.setAlwaysOnTop(true, 'screen-saver');

  const queryParams = `?mode=card&data=${encodeURIComponent(JSON.stringify(data))}`;

  if (isDev) {
    cardWindow.loadURL(`http://localhost:5173/${queryParams}`);
  } else {
    cardWindow.loadFile(path.join(__dirname, 'dist', 'index.html'), {
      query: { mode: 'card', data: JSON.stringify(data) }
    });
  }

  cardWindow.on('closed', () => {
    cardWindow = null;
  });
}

// 5. IPC Request Handlers
ipcMain.handle('capture-screen', async () => {
  return latestScreenshotBase64;
});

ipcMain.handle('get-active-app', async () => {
  return getActiveWindow();
});

ipcMain.on('close-overlay', () => {
  if (overlayWindow) {
    overlayWindow.close();
  }
});

ipcMain.on('open-card', (event, payload) => {
  createCardWindow(payload.x, payload.y, payload.data);
});

ipcMain.on('close-card', () => {
  if (cardWindow) {
    cardWindow.close();
  }
});

// 6. Global Shortcut Registration
function registerShortcut() {
  // Use Command+Alt+Space for macOS, Ctrl+Space for Windows/Linux
  const shortcutKey = process.platform === 'darwin' ? 'Cmd+Alt+Space' : 'Ctrl+Space';
  
  const registered = globalShortcut.register(shortcutKey, async () => {
    console.log(`Global shortcut ${shortcutKey} triggered!`);
    
    // Close existing companion windows before running selection
    if (cardWindow) cardWindow.close();
    
    // Trigger screen capture first
    try {
      const file = await captureScreenNative();
      const imgBuffer = fs.readFileSync(file);
      latestScreenshotBase64 = `data:image/png;base64,${imgBuffer.toString('base64')}`;
      
      if (!overlayWindow) {
        createOverlayWindow();
      } else {
        overlayWindow.webContents.send('shortcut-triggered', latestScreenshotBase64);
      }
    } catch (e) {
      console.error("Error on shortcut activation capture:", e);
    }
  });

  if (registered) {
    console.log(`Registered shortcut: ${shortcutKey}`);
  } else {
    console.error(`Failed to register shortcut: ${shortcutKey}`);
  }
}

// 7. Life Cycle Management
app.whenReady().then(() => {
  startBackend();
  createMainWindow();
  registerShortcut();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  // Quit app on close, but make sure backend processes are cleaned up
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
  if (backendProcess) {
    console.log("Terminating Python backend daemon...");
    backendProcess.kill();
  }
});

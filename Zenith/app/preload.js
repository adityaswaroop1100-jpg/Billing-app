const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('zenithAPI', {
  // Capture the screens and get the screenshot URL/path
  captureScreen: () => ipcRenderer.invoke('capture-screen'),
  
  // Close the marquee selection overlay
  closeOverlay: () => ipcRenderer.send('close-overlay'),
  
  // Open and position the floating result card near the crop box
  openCard: (data) => ipcRenderer.send('open-card', data),
  
  // Hide the floating card
  closeCard: () => ipcRenderer.send('close-card'),
  
  // Detect active app process and window title
  getActiveApp: () => ipcRenderer.invoke('get-active-app'),
  
  // Listen for the global hotkey triggering the selection overlay
  onShortcutTriggered: (callback) => {
    const subscription = (event, data) => callback(data);
    ipcRenderer.on('shortcut-triggered', subscription);
    return () => ipcRenderer.removeListener('shortcut-triggered', subscription);
  }
});

const { contextBridge } = require('electron');

// Expose any needed APIs to the renderer
contextBridge.exposeInMainWorld('cocaine', {
  platform: process.platform,
  version: '1.0.0'
});

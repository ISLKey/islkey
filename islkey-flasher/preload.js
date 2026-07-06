const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('isl', {
    minimize:       () => ipcRenderer.invoke('window-minimize'),
    maximize:       () => ipcRenderer.invoke('window-maximize'),
    close:          () => ipcRenderer.invoke('window-close'),
    listPorts:      () => ipcRenderer.invoke('list-ports'),
    listFirmware:   () => ipcRenderer.invoke('list-firmware'),
    generateSerial: () => ipcRenderer.invoke('generate-serial'),
    loadConfigFile: () => ipcRenderer.invoke('load-config-file'),
    getPcWifi:      () => ipcRenderer.invoke('get-pc-wifi'),
    flashFirmware:  (o) => ipcRenderer.invoke('flash-firmware', o),
    eraseFlash:     (o) => ipcRenderer.invoke('erase-flash', o),
    openRegister:   () => ipcRenderer.invoke('open-register'),
    getRegisterStats:() => ipcRenderer.invoke('get-register-stats'),
    openExternal:   (u) => ipcRenderer.invoke('open-external', u),
    onFlashLog: (cb) => ipcRenderer.on('flash-log', (e, line) => cb(line)),
});

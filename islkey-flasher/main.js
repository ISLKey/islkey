/**
 * ISLKey Flasher v1.1.0 — Electron Main Process
 * Adds: serial number generation, random AP password,
 *       CSV asset register, TTGO T-Display support,
 *       WT32-ETH01 Ethernet board support
 */

const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const path   = require('path');
const fs     = require('fs');
const { spawn, execFileSync } = require('child_process');
const { SerialPort } = require('serialport');

let mainWindow;

// ── Resource paths ─────────────────────────────────────────────────────────────
function resourcePath(...parts) {
    if (app.isPackaged) return path.join(process.resourcesPath, ...parts);
    return path.join(__dirname, ...parts);
}

const ESPTOOL_PATH  = resourcePath('bin', 'esptool.exe');
const FIRMWARE_DIR  = resourcePath('firmware');
// Serial register + counter must SURVIVE app updates/uninstalls — keep them in the
// persistent user-data dir, not in the install folder (which is replaced on update).
const SERIALS_DIR   = app.isPackaged
    ? path.join(app.getPath('userData'), 'serials')
    : resourcePath('serials');
const SERIAL_CSV    = path.join(SERIALS_DIR, 'isl-serial-register.csv');
const SERIAL_COUNTER= path.join(SERIALS_DIR, 'next-serial.txt');

// ── Ensure serials directory exists ───────────────────────────────────────────
function ensureSerialsDir() {
    if (!fs.existsSync(SERIALS_DIR)) fs.mkdirSync(SERIALS_DIR, { recursive: true });
    if (!fs.existsSync(SERIAL_CSV)) {
        fs.writeFileSync(SERIAL_CSV,
            'serial_number,board_type,firmware,flash_date,ap_password,door_name,site_code,api_url,notes\r\n'
        );
    }
    if (!fs.existsSync(SERIAL_COUNTER)) {
        fs.writeFileSync(SERIAL_COUNTER, '1');
    }
}

// ── Serial number generation ───────────────────────────────────────────────────
function generateSerial() {
    ensureSerialsDir();
    const next = parseInt(fs.readFileSync(SERIAL_COUNTER, 'utf8').trim()) || 1;
    const date = new Date();
    const dateStr = `${date.getFullYear()}${
        String(date.getMonth()+1).padStart(2,'0')}${
        String(date.getDate()).padStart(2,'0')}`;
    const serial = `ISL-${String(next).padStart(4,'0')}-${dateStr}`;
    fs.writeFileSync(SERIAL_COUNTER, String(next + 1));
    return serial;
}

// ── Random AP password ─────────────────────────────────────────────────────────
function generateAPPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No O,0,I,1 — confusing
    let pwd = '';
    for (let i = 0; i < 8; i++) {
        pwd += chars[Math.floor(Math.random() * chars.length)];
    }
    return pwd;
}

// ── Log to CSV register ────────────────────────────────────────────────────────
function logToCSV({ serial, boardType, firmware, apPassword, doorName = '', siteCode = '', apiUrl = '', notes = '' }) {
    ensureSerialsDir();
    const date = new Date().toISOString();
    const row  = `${serial},"${boardType}","${firmware}","${date}","${apPassword}","${doorName}","${siteCode}","${apiUrl}","${notes}"\r\n`;
    fs.appendFileSync(SERIAL_CSV, row);
}

// ── Window ─────────────────────────────────────────────────────────────────────
function createWindow() {
    mainWindow = new BrowserWindow({
        width: 900, height: 720,
        minWidth: 760, minHeight: 600,
        frame: false,
        backgroundColor: '#0a0e17',
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
            nodeIntegration: false,
            contextIsolation: true,
        },
        icon: path.join(__dirname, 'assets', 'icon.ico'),
        title: 'ISLKey Flasher',
    });
    mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
    mainWindow.on('closed', () => { mainWindow = null; });
}

app.whenReady().then(() => { ensureSerialsDir(); createWindow(); });
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });

// ── IPC: Window controls ───────────────────────────────────────────────────────
ipcMain.handle('window-minimize', () => mainWindow?.minimize());
ipcMain.handle('window-maximize', () => {
    mainWindow?.isMaximized() ? mainWindow.unmaximize() : mainWindow?.maximize();
});
ipcMain.handle('window-close', () => app.quit());

// ── IPC: Serial ports ──────────────────────────────────────────────────────────
ipcMain.handle('list-ports', async () => {
    try {
        const ports = await SerialPort.list();
        return ports.map(p => ({
            path:         p.path,
            friendlyName: p.friendlyName || p.path,
            manufacturer: p.manufacturer || '',
        }));
    } catch(e) { return []; }
});

// ── IPC: Firmware files ────────────────────────────────────────────────────────
ipcMain.handle('list-firmware', async () => {
    try {
        if (!fs.existsSync(FIRMWARE_DIR)) return [];
        return fs.readdirSync(FIRMWARE_DIR)
            .filter(f => f.endsWith('.bin'))
            .map(f => {
                const full = path.join(FIRMWARE_DIR, f);
                const stat = fs.statSync(full);
                // Parse board type hint from filename e.g. islkey-relay-v1.0.0.bin
                let boardHint = 'all';
                if (f.includes('relay'))  boardHint = 'relay-board';
                if (f.includes('devkit')) boardHint = 'devkit';
                if (f.includes('ttgo') || f.includes('display')) boardHint = 'ttgo';
                if (f.includes('eth') || f.includes('wt32'))     boardHint = 'wt32-eth01';
                return {
                    name:      f,
                    path:      full,
                    sizekb:    Math.round(stat.size / 1024),
                    boardHint,
                };
            });
    } catch(e) { return []; }
});

// ── IPC: Generate serial + password ───────────────────────────────────────────
ipcMain.handle('generate-serial', async () => {
    return {
        serial:     generateSerial(),
        apPassword: generateAPPassword(),
    };
});

// ── IPC: Read the PC's current WiFi (SSID + saved password) ───────────────────
ipcMain.handle('get-pc-wifi', async () => {
    try {
        const ifOut = execFileSync('netsh', ['wlan', 'show', 'interfaces'], { encoding: 'utf8' });
        const m = ifOut.match(/^\s*SSID\s*:\s*(.+?)\s*$/m);   // not BSSID — ^\s* anchors to line start
        const ssid = m ? m[1].trim() : '';
        if (!ssid) return { ok: false, error: 'No active WiFi connection on this PC.' };

        let password = '';
        try {
            const pOut = execFileSync('netsh', ['wlan', 'show', 'profile', `name=${ssid}`, 'key=clear'], { encoding: 'utf8' });
            const pm = pOut.match(/Key Content\s*:\s*(.+?)\s*$/m);
            password = pm ? pm[1].trim() : '';
        } catch (e) { /* password not retrievable (e.g. enterprise/open) */ }

        return { ok: true, ssid, password };
    } catch (e) {
        return { ok: false, error: 'Could not read WiFi: ' + e.message };
    }
});

// ── IPC: Load provisioning config file (.islkey) ──────────────────────────────
ipcMain.handle('load-config-file', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
        title:       'Load ISLKey Config File',
        buttonLabel: 'Load Config',
        filters: [
            { name: 'ISLKey Config', extensions: ['islkey'] },
            { name: 'JSON Files',    extensions: ['json']   },
        ],
        properties: ['openFile'],
    });

    if (result.canceled || !result.filePaths.length) {
        return { ok: false, cancelled: true };
    }

    const filePath = result.filePaths[0];
    try {
        const config = JSON.parse(fs.readFileSync(filePath, 'utf8'));

        if (!config.islkey_config_version) return { ok: false, error: 'Not a valid ISLKey config file.' };
        if (!config.api?.token)            return { ok: false, error: 'Config file is missing api.token.' };
        if (!config.api?.url)              return { ok: false, error: 'Config file is missing api.url.' };

        if (config.expires_at) {
            const expires = new Date(config.expires_at);
            if (expires < new Date()) {
                return { ok: false, expired: true,
                    error: `Config token expired at ${expires.toLocaleString()}. Generate a new token in the ISL admin.` };
            }
        }
        return { ok: true, config, path: filePath };
    } catch (e) {
        return { ok: false, error: 'Could not read config file: ' + e.message };
    }
});

// ── Commission device over serial ───────────────────────────────────────────────
// After flashing, send the unit its serial + AP password. The firmware stores them
// in NVS, replies ISLKEY-ACK, and restarts with a secured setup AP.
function commissionDevice(port, payload, send) {
    return new Promise((resolve) => {
        // payload: { serial, ap_pwd, api_url, api_token, door_name, site_code }
        const line = `ISLKEY-PROV:${JSON.stringify(payload)}\n`;
        let buf = '', done = false, sendTimer = null, sp = null;

        const finish = (ok) => {
            if (done) return;
            done = true;
            if (sendTimer) clearInterval(sendTimer);
            if (sp && sp.isOpen) { try { sp.close(() => {}); } catch (e) {} }
            resolve(ok);
        };

        const open = (attempt) => {
            sp = new SerialPort({ path: port, baudRate: 115200, autoOpen: false });
            sp.on('data', (d) => {
                buf += d.toString('utf8');
                if (buf.includes('ISLKEY-ACK')) {
                    send('✓ Device acknowledged identity (ISLKEY-ACK)');
                    finish(true);
                }
                if (buf.length > 4096) buf = buf.slice(-1024);
            });
            sp.on('error', () => {});   // handled via open callback / timeout
            sp.open((err) => {
                if (err) {
                    if (attempt < 3) { setTimeout(() => open(attempt + 1), 600); }
                    else { send(`Commission: cannot open ${port} (${err.message})`); finish(false); }
                    return;
                }
                // Release the auto-reset lines so the board runs (RTS->EN, DTR->GPIO0)
                try { sp.set({ rts: false, dtr: false }, () => {}); } catch (e) {}
                send('Waiting for device to boot, then sending identity...');
                // Board needs ~2s to boot (TTGO splash), then it polls serial
                setTimeout(() => {
                    const trySend = () => { if (!done && sp.isOpen) sp.write(line, () => {}); };
                    trySend();
                    sendTimer = setInterval(trySend, 600);
                }, 2500);
            });
        };

        setTimeout(() => open(1), 500);    // let the OS release the port after esptool
        setTimeout(() => { if (!done) { send('Commission: no ACK within timeout'); finish(false); } }, 13000);
    });
}

// ── IPC: Flash firmware ────────────────────────────────────────────────────────
ipcMain.handle('flash-firmware', async (event, {
    port, firmwarePath, boardType, baudRate, serial, apPassword,
    apiUrl, apiToken, doorName, siteCode, wifiSsid, wifiPassword
}) => {
    return new Promise((resolve) => {

        if (!fs.existsSync(ESPTOOL_PATH)) {
            resolve({ ok: false, error: 'esptool.exe not found in bin/ folder' });
            return;
        }
        if (!fs.existsSync(firmwarePath)) {
            resolve({ ok: false, error: 'Firmware file not found' });
            return;
        }

        const send = (line) => mainWindow?.webContents.send('flash-log', line);

        send(`Serial:   ${serial}`);
        send(`Board:    ${boardType}`);
        send(`Port:     ${port}`);
        send(`Firmware: ${path.basename(firmwarePath)}`);
        send(`AP Pass:  ${apPassword}`);
        send('');
        send('Connecting to ESP32...');
        send('(Hold BOOT + press RESET if this hangs)');

        // Flash the complete merged image (bootloader 0x1000 + partitions 0x8000
        // + boot_app0 0xe000 + app 0x10000, all combined into one file flashable
        // at 0x0). Flashing the app alone — or to 0x1000 — leaves the board with
        // no valid bootloader and it boot-loops on RTCWDT reset.
        const args = [
            '--chip',   'esp32',
            '--port',   port,
            '--baud',   String(baudRate || 921600),
            '--before', 'default_reset',
            '--after',  'hard_reset',
            'write_flash', '-z',
            '--flash_mode', 'keep',   // header already baked into the merged image
            '--flash_freq', 'keep',
            '--flash_size', 'keep',
            '0x0', firmwarePath,
        ];

        const proc = spawn(ESPTOOL_PATH, args);

        proc.stdout.on('data', d => d.toString().split('\n').forEach(l => { if (l.trim()) send(l.trim()); }));
        proc.stderr.on('data', d => d.toString().split('\n').forEach(l => { if (l.trim()) send(l.trim()); }));

        proc.on('close', async (code) => {
            if (code !== 0) {
                send('');
                send(`✗ Flash failed (exit ${code})`);
                resolve({ ok: false, error: `esptool exited with code ${code}` });
                return;
            }

            send('');
            send('✓ Firmware written — writing serial number + AP password to device...');

            // Commission the device over serial: it stores the identity in NVS,
            // secures its setup AP with the password, and restarts.
            let commissioned = false;
            try {
                commissioned = await commissionDevice(port, {
                    serial,
                    ap_pwd:    apPassword,
                    api_url:   apiUrl   || '',
                    api_token: apiToken || '',
                    door_name: doorName || '',
                    site_code: siteCode || '',
                    wifi_ssid: wifiSsid || '',
                    wifi_pass: wifiPassword || '',
                }, send);
            } catch (e) {
                send(`Commissioning error: ${e.message}`);
            }

            // Record the unit in the asset register
            logToCSV({
                serial,
                boardType,
                firmware:   path.basename(firmwarePath),
                apPassword,
                doorName:   doorName || '',
                siteCode:   siteCode || '',
                apiUrl:     apiUrl   || '',
                notes:      commissioned ? '' : 'identity-not-set',
            });

            send('');
            if (commissioned) {
                send('✓ Flash complete — identity + config written to device');
                send(`✓ Serial number:     ${serial}`);
                send(`✓ Setup AP password: ${apPassword}`);
                if (doorName)  send(`✓ Door:              ${doorName}`);
                if (apiUrl)    send(`✓ API URL:           ${apiUrl}  (pre-loaded)`);
                if (apiToken)  send(`✓ API token:         pre-loaded`);
                send('');
                if (wifiSsid) {
                    send(`✓ WiFi:              ${wifiSsid}  (pre-loaded)`);
                    send('Board restarts, joins WiFi, registers and comes online —');
                    send('no on-device setup needed.');
                } else {
                    send('Board restarts into a SECURED setup Wi-Fi: ISLKey-XXXX');
                    send(`Join it with password ${apPassword}, then open http://192.168.4.1`);
                    if (apiUrl) send('The provisioning page is pre-filled — only WiFi is needed.');
                }
            } else {
                send('⚠ Flash OK, but could not confirm identity write over serial.');
                send('  The device will run with an OPEN setup AP until re-commissioned.');
                send(`✓ Serial number:     ${serial}  (logged to register)`);
                send(`✓ Setup AP password: ${apPassword}  (logged to register)`);
            }

            resolve({ ok: true, serial, apPassword, commissioned });
        });

        proc.on('error', err => resolve({ ok: false, error: err.message }));
    });
});

// ── IPC: Erase flash ───────────────────────────────────────────────────────────
ipcMain.handle('erase-flash', async (event, { port }) => {
    return new Promise((resolve) => {
        const send = (l) => mainWindow?.webContents.send('flash-log', l);
        send('Erasing flash — takes about 10 seconds...');

        const proc = spawn(ESPTOOL_PATH, [
            '--chip', 'esp32', '--port', port, '--baud', '921600', 'erase_flash'
        ]);
        proc.stdout.on('data', d => d.toString().split('\n').forEach(l => { if(l.trim()) send(l.trim()); }));
        proc.stderr.on('data', d => d.toString().split('\n').forEach(l => { if(l.trim()) send(l.trim()); }));
        proc.on('close', code => {
            if (code === 0) { send('✓ Flash erased'); resolve({ ok: true }); }
            else            { resolve({ ok: false, error: `Erase failed (code ${code})` }); }
        });
        proc.on('error', err => resolve({ ok: false, error: err.message }));
    });
});

// ── IPC: Open serial register CSV ─────────────────────────────────────────────
ipcMain.handle('open-register', () => {
    ensureSerialsDir();
    shell.openPath(SERIAL_CSV);
});

// ── IPC: Get register stats ────────────────────────────────────────────────────
ipcMain.handle('get-register-stats', () => {
    ensureSerialsDir();
    try {
        const lines = fs.readFileSync(SERIAL_CSV, 'utf8').split('\n').filter(l => l.trim() && !l.startsWith('serial'));
        const next  = parseInt(fs.readFileSync(SERIAL_COUNTER, 'utf8').trim()) || 1;
        return { total: lines.length, nextSerial: next };
    } catch(e) { return { total: 0, nextSerial: 1 }; }
});

// ── IPC: External links ────────────────────────────────────────────────────────
ipcMain.handle('open-external', (e, url) => shell.openExternal(url));

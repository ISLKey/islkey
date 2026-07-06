// Standalone test of the commissioning handshake against a flashed board.
// Usage: node commission-test.js COM5 ISL-TEST-0001 ABCD2345 [config.islkey]
// Mirrors the flasher: if a .islkey path is given, sends the full JSON payload.
const { SerialPort } = require('serialport');
const fs = require('fs');
const [port, serial, apPwd, cfgPath] = process.argv.slice(2);
const payload = { serial, ap_pwd: apPwd, api_url: '', api_token: '', door_name: '', site_code: '' };
if (cfgPath) {
    const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
    payload.api_url   = cfg.api?.url          || '';
    payload.api_token = cfg.api?.token        || '';
    payload.door_name = cfg.device?.door_name || '';
    payload.site_code = cfg.device?.site_code || '';
}
const line = `ISLKEY-PROV:${JSON.stringify(payload)}\n`;
let buf = '', done = false, sendTimer = null, sp = null;
const log = (m) => console.log(`[test] ${m}`);

const finish = (ok) => {
    if (done) return; done = true;
    if (sendTimer) clearInterval(sendTimer);
    if (sp && sp.isOpen) { try { sp.close(() => {}); } catch (e) {} }
    log(ok ? 'RESULT: ACK received ✓' : 'RESULT: no ACK ✗');
    process.exit(ok ? 0 : 1);
};

const open = (attempt) => {
    sp = new SerialPort({ path: port, baudRate: 115200, autoOpen: false });
    sp.on('data', (d) => {
        const s = d.toString('utf8');
        process.stdout.write(s.replace(/\r/g, ''));
        buf += s;
        if (buf.includes('ISLKEY-ACK')) finish(true);
        if (buf.length > 4096) buf = buf.slice(-1024);
    });
    sp.on('error', () => {});
    sp.open((err) => {
        if (err) {
            if (attempt < 3) { setTimeout(() => open(attempt + 1), 600); }
            else { log('cannot open ' + port + ': ' + err.message); finish(false); }
            return;
        }
        try { sp.set({ rts: false, dtr: false }, () => {}); } catch (e) {}
        log('port open; waiting for boot then sending identity...');
        setTimeout(() => {
            const trySend = () => { if (!done && sp.isOpen) sp.write(line, () => {}); };
            trySend();
            sendTimer = setInterval(trySend, 600);
        }, 2500);
    });
};
setTimeout(() => open(1), 500);
setTimeout(() => { if (!done) finish(false); }, 13000);

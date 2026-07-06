# ISLKey

Access-control platform by **ISL Technologies** — ESP32-based door controllers with a
Windows flasher/commissioning tool and a companion mobile app.

## Repository layout

| Path | What it is | Stack |
|------|-----------|-------|
| `islkey-firmware/` | Door-controller firmware — 4 board targets (relay-board, devkit, ttgo, wt32-eth01). Inputs (exit/door/fire/tamper), relay-driven lock, cloud HMAC device-auth, NimBLE. | ESP32 / PlatformIO / Arduino |
| `islkey-flasher/`  | Desktop flasher + serial commissioning tool. Flashes merged full-flash images at `0x0`, assigns serials, writes WiFi/API config over serial. | Electron / Node.js |
| `islkey-app/`      | Companion door-access mobile app (NFC tap → resolve → unlock). | Flutter |
| `kicad/`           | KiCad 8 schematic for the TTGO controller (inputs, relay lock output, monitored fire link, backup power). | KiCad |
| `wordpress/`       | Drop-in integration notes for the isl-key WordPress plugin (device API / provisioning). | — |
| `make_wiring_diagram.py` | Generates the 4-sheet wiring/pinout PDF (`ISLKey-Wiring-Diagram.pdf`). | Python / matplotlib |
| `make_kicad_schematic.py` | Generates `kicad/ISLKey.kicad_sch` from source. | Python |

## Building

- **Firmware:** `cd islkey-firmware && python -m platformio run` (per-env in `platformio.ini`).
  After a rebuild, regenerate the merged images with `esptool merge_bin` (see below) — the
  flasher writes a **merged full-flash image at `0x0`**; a raw app image boot-loops the board.
- **Flasher:** `cd islkey-flasher && npm install && npm start` (or `npm run build` for the installer).
- **App:** `cd islkey-app && flutter pub get && flutter run`.

## Hardware notes

- On the **TTGO T-Display** target the TFT occupies GPIO 4/5/16/18/19/23, so door I/O is
  remapped: inputs GPIO 13/25/26/27, relays GPIO 32/33.
- The lock is switched via an **external opto-isolated relay module** (COM/NC), with a
  single **volt-free fire N/C contact in series** (hardware release, controller-independent)
  that is **opto-monitored to GPIO26** for fire detection + cable supervision. See `kicad/`
  and the wiring PDF.

## Not in this repo

Build artifacts (`.pio/`, `node_modules/`, Flutter `build/`, installer `dist/`) and
**operational secrets** — the per-device serial register / AP passwords (`islkey-flasher/serials/`)
and any real `.islkey` provisioning configs — are git-ignored.

# ISLKey Flutter — Developer Handoff

The **ISLKey** door-access app for ISLKey users (door holders). Built in the same
ecosystem and on the same architecture as **ISLShift** (the staff clock-in app).

Last updated: 2026-06-21.

---

## Current status

✅ **Builds on Android.** `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter analyze` → **0 errors / 0 warnings** (only cosmetic `withOpacity` / `prefer_const`
  deprecation *infos* remain — identical class of non-blocking notices to ISLShift).
- **Not yet run on a physical device.** NFC requires real hardware (emulators have no NFC);
  no Android device was connected at build time. Install with:
  ```
  flutter build apk --debug --target-platform android-arm64
  adb -s <deviceId> install -r -d build/app/outputs/flutter-apk/app-debug.apk
  ```
- iOS scaffolding exists but has not been built (no macOS/Xcode here). The NFC Tag Reading
  capability + `NFCReaderUsageDescription` Info.plist key must be added before an iOS build.

## Build environment

Same as ISLShift: Flutter 3.44.2 (`C:\src\flutter`), Android Studio JBR as `JAVA_HOME`,
`ANDROID_HOME` = `…\AppData\Local\Android\Sdk`. Package / applicationId:
**`com.isltechnologies.islkey`**.

Build workarounds baked into the repo (do not undo):
- `android/build.gradle.kts` forces every plugin subproject to `compileSdk = 36` via an
  `afterEvaluate` block registered **before** `evaluationDependsOn(":app")` — `nfc_manager`
  hardcodes an older compileSdk than its AndroidX deps require. Moving the block after
  `evaluationDependsOn` throws "project already evaluated".
- `AndroidManifest.xml` requests `INTERNET` + `NFC`, declares `android.hardware.nfc` as
  **not required** (installs on non-NFC phones), and **deliberately has no NFC tag-dispatch
  intent filters** — those make Android launch a second app instance on a stray tap. Tags are
  read via `nfc_manager` reader mode while the scan screen is open.

---

## Architecture (mirrors ISLShift)

```
lib/
  main.dart                     ProviderScope + MaterialApp, branding-driven theme
  theme.dart                    ISL palette + per-customer brand colour
  models/                       branding_data, user_profile, door, credential,
                                access_event, linked_site, unlock_result
  services/
    api_service.dart            HTTP; unwraps the ISL Core { ok, data } envelope
    nfc_service.dart            reader-mode scan → uppercase hex UID (no colons)
    secure_storage_service.dart token + profile + linked sites + offline caches
  providers/
    auth_provider.dart          setup / PIN login / sign out (Riverpod Notifier)
    doors_provider.dart         doors+credentials list, caching, unlock state machine
    sites_provider.dart         linked sites
  screens/                      splash, login, setup, home, nfc_scan,
                                unlock_result, history, profile, link_site
  widgets/shared_widgets.dart   logo, PIN pad, NFC pulse ring, access tile, etc.
```

Backend: `https://i-s-l.co.uk/wp-json`, namespace `islkey/v1`. Bearer token
(`Authorization: Bearer …`, query-param `?_isl_token=` fallback), 12-hour expiry → 401 →
re-auth with PIN. **All ISLKey responses are wrapped as `{ "ok": true, "data": {…} }`** —
`ApiService._handleResponse` unwraps `data` (this differs from ISLShift, which returned the
payload at the top level).

### Endpoints wired up (Layer 1 — App API)
`POST /invite/accept` · `POST /auth` · `POST /site/link` · `GET /tags/resolve` ·
`GET /me/doors` · `GET /me/credentials` · `GET /me/log` · `POST /doors/{id}/unlock`.
Customer branding comes from the shared ISL Core endpoint `GET /isl/v1/branding/{slug}`
(best-effort; falls back to ISLKey defaults so login never blocks on it).

### The unlock flow
1. **Primary (NFC, cloud-mediated):** tap phone to the door tag → read UID →
   `GET /tags/resolve?serial=` → verify the door is in the user's `/me/doors` list →
   `POST /doors/{id}/unlock` (method `NFC_TAP_CLOUD`) → backend queues the command to the
   ESP32 → show "Unlock sent" (the door opens when the ESP32 next polls; no push exists yet).
2. **Direct:** each door card also has an Unlock button that calls `/doors/{id}/unlock`
   directly for an authenticated user already at/near the door.

Unlock is blocked client-side when a door has no controller (`device_uuid == null`) or its
`fire_alarm_state == "ACTIVE"`; the backend re-checks regardless (403 / 422 / 404 handled).

---

## Deliberately NOT built (per the handover brief)

- **BLE direct-unlock fallback** — the brief marks this as the single blocking dependency:
  the ESP32 BLE service UUID and the signed offline-unlock token format must be agreed between
  firmware and app first. `/me/doors` + `/me/credentials` are already cached locally
  (`SecureStorageService`) so the cache the BLE path needs is in place. Add a `ble_service.dart`
  + an offline-detection branch in `doors_provider.resolveAndUnlock` once the format is agreed.
- **Change PIN** — the ISLKey API reference defines no `/me/pin` endpoint, so the profile
  screen omits it (add a tile once the backend exposes one).
- **Push notifications** — backend has no FCM/APNs yet; the app uses the timeout approach
  ("Unlock sent" after the queue accepts the command).

## Outstanding TODOs

1. **Release signing** — release builds currently use the debug key. Add a real keystore
   before shipping.
2. **App identity** — default Flutter launcher icon is still in place; add the ISLKey icon.
3. **On-device verification** — run the full flow (setup → PIN → tap-to-unlock → history) on a
   physical NFC Android device with a registered test tag (`58E104DD`, site `TE2001`).
4. **iOS** — add NFC capability + Info.plist usage string, then build.

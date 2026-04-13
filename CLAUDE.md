# Flockr RFID Scanner Bridge Context

## Project Architecture
- **Layer 1: Android Bridge**: Kotlin `MainActivity` using Urovo `RFIDSDKManager` + `IRfidCallback`. EventChannel pushes EPC/RSSI scans to Dart. MethodChannel handles connect/disconnect/startScan/stopScan commands.
- **Layer 2: Scan Manager**: Drift (SQLite) database with 5-second deduplication per EPC. API sync is disabled — scans are stored locally only for now.
- **Layer 3: UI Screens**: ScanScreen (main). RegisterScreen and SettingsScreen exist but are not yet wired up — planned for after scanning is confirmed working.
- **Layer 4: API Backend**: ApiClient exists but sync is disabled. Will connect to the main Flockr app (`/api/rfid/scan`, `/api/animals`) once scanning works.

## SDK Integration
- **SDK**: `com.ubx.usdk.RFIDSDKManager` (Urovo UHF platform SDK)
- **Init Flow**: `RFIDSDKManager.getInstance().init(context, InitListener)` → on success → `getRfidManager()` → `registerCallback(IRfidCallback)` → `startInventory()`
- **JARs**: `platform_sdk_v3.1.221124.jar` + `URFIDLibrary-v2.5.0718.aar` in `android/app/libs/`
- **ProGuard**: Keeps `com.ubx.**`, `com.rfid.**`, `com.rfiddevice.**`

## Platform Channels
- **EventChannel**: `africa.flockr.scanner/rfid` — streams `{epc, rssi, timestamp, count}` maps and `{event: scanComplete}` events
- **MethodChannel**: `africa.flockr.scanner/rfid_commands` — methods: `connect`, `disconnect`, `startScan(mode)`, `stopScan`, `isConnected`, `isScanning`

## Scan Modes
- `continuous` — scans indefinitely until stopped (timeout: 0)
- `single` — scans one tag then stops (`inventorySingle()`)
- `timed` — scans for 5 seconds (`startInventoryWithTimeout(5)`)

## Trigger
- **In-app button**: START/STOP SCANNING button in the UI
- **Physical trigger**: Urovo hardware button (keyCodes 523/515) via `dispatchKeyEvent()`

## Core Rules
1. **Never drop a scan**: Offline SQLite queuing is mandatory.
2. **Keep it simple**: The UI is meant for fast-paced field work.
3. **Connect before scan**: `isConnected` guard must pass before scanning starts.

## Next Steps (after scanning confirmed)
1. Wire up SettingsScreen for API configuration
2. Enable API sync in ScanManager
3. Connect to main Flockr app for data transfer
4. Add notifications for scan status/sync events
5. Wire up RegisterScreen for new animal registration

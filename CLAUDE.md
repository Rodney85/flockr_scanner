# Flockr RFID Scanner Bridge Context

## Project Architecture
- **Layer 1: Android Bridge**: Kotlin `BroadcastReceiver` listening to `android.intent.ACTION_DECODE_DATA`. Platform Channel to push EPC scans to Dart.
- **Layer 2: Scan Manager**: Drift/sqflite database. 5-second deduplication.
- **Layer 3: UI Screens**: Scan Screen, Register Screen, Log Screen, Settings.
- **Layer 4: API Backend**: Flockr API (`/api/rfid/scan`, `/api/animals`).

## Core Rules
1. **Never drop a scan**: Offline SQLite queuing is mandatory.
2. **Action key**: `barcode_string` is the intent extra carrying the EPC.
3. **Keep it simple**: The UI is meant for fast-paced field work.

## Build Order Preference
1) Android Platform Channel -> 2) SQLite Manager -> 3) Scan UI -> 4) Settings/API -> 5) Offline Logic -> 6) Registration UI.

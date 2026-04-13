# FLOCKR RFID SCANNER BRIDGE
## Product Requirements Document
**Version:** 2.0 | **Date:** April 2026 | **Company:** Craft Silicon

---

## 1. Product Overview

The Flockr RFID Scanner Bridge is a lightweight Android application designed specifically for the **RFIDUH7-II handheld scanner device**. Its primary purpose is to intercept UHF RFID tag scans in real-time and automatically synchronize that data with the Flockr backend API. 

This bridge eliminates manual data exports and file transfers, turning the RFID scanner into a live, connected tool for both identifying existing animals and seamlessly registering new ones right in the field.

## 2. Background & Context

### 2.1 The Problem
Flockr manages livestock, each identified by a UHF RFID ear tag. The RFIDUH7-II handheld scanner can read these tags in bulk. However, the scanner's factory software relies on manual XLSX exports. This introduces delays, human error, and creates friction for farm workers who need immediate feedback.

### 2.2 The Solution Mechanic (Hardware Foundation)
The core interception mechanic is already solved at the hardware/OS level. The scanner broadcasts every successful scan as a standard Android `Intent` immediately upon reading a tag. 

**Intent Details:**
*   **Intent Action:** `android.intent.ACTION_DECODE_DATA`
*   **Data Field:** `barcode_string`
*   **Coding Format:** UTF-8
*   **Action Key:** Carriage Return
*   **Output Mode:** Intent Broadcast

Because of this, **no proprietary SDK, TCP configuration, or polling is required**. The app's foundation is simply an Android `BroadcastReceiver` listening for this specific Intent.

### 2.3 Sample EPC Data
The app must handle and seamlessly forward whatever string it receives in the `barcode_string`, such as:
*   Standard UHF RFID EPC: `E280699500005006FCD8F4C8`
*   Custom encoded tag: `123456789020250217000380`

---

## 3. Goals & Non-Goals

### 3.1 Goals
*   **Real-time Interception:** Capture every UHF RFID scan via Intent broadcast.
*   **Automated Sync:** Forward each EPC code to the Flockr backend API instantly.
*   **Instant Registration:** Allow workers to instantly create a new animal record if a scanned tag is unrecognized.
*   **Offline Resilience:** Queue all scans locally in SQLite first, ensuring zero data loss during connectivity drops, and auto-retry when online.
*   **Simplicity:** Provide a zero-friction UI that a farm worker can use all day without technical training.

### 3.2 Non-Goals
*   Replacing the comprehensive Flockr web platform.
*   Full animal profile management or health event logging.
*   iOS or Desktop support.
*   Multi-farm support within a single installation (1 App Install = 1 Farm Token).
*   User account login flows (uses pre-configured API Bearer token).

---

## 4. System Architecture: The Four Layers

The application is structured into four distinct layers:

### Layer 1 — The Android Bridge (Platform Integration)
The hardest part, but only built once. 
*   A `BroadcastReceiver` registered in the Android Manifest/MainActivity for `android.intent.ACTION_DECODE_DATA`.
*   It extracts the `barcode_string`, appends a local timestamp and `device_id`.
*   Communicates with the Flutter UI via a **Platform Channel** (Kotlin on Android side -> Dart on Flutter side).

### Layer 2 — The Scan Manager (The Brain)
The core business logic layer handling data integrity.
*   **Deduplication:** Ignores duplicate tags scanned within a **5-second window** (deduplication happens at the app level).
*   **Persistence First:** Every scan is immediately written to a local SQLite database (e.g., using `drift` or `sqflite`) *before* any network attempt.
*   **Sync Logic:** Decides whether to send immediately to the API or hold in the offline queue. Updates UI state based on API response.

### Layer 3 — The UI Screens
Built in Flutter, tailored for high-visibility outdoor use.
1.  **Scan Screen:** The main dashboard showing a live feed of scans.
2.  **Register Animal Screen:** Form to quickly add a new animal when an unrecognized tag is tapped.
3.  **Log Screen:** Full historical audit of all scans.
4.  **Settings:** Configuration for API URL, Device ID, and Bearer Token.

### Layer 4 — Backend Additions (Flockr API)
The APIs required to support the bridge.
*   `POST /api/rfid/scan` - To log a scan and look up an animal.
*   `POST /api/animals` - To register a new animal from the field.
*(Note: EPC codes are mapped directly to the existing "NFC tag ID" field in the Flockr database).*

---

## 5. App Screens & Behaviour

### 5.1 Scan Screen (Home)
The primary interface the worker relies on during scanning operations.
*   Automatic operation: Pulling the hardware trigger automatically populates this screen. No software buttons need to be pressed to scan.
*   Live scrolling list of scanned EPCs (newest at top).
*   **Row States:**
    *   ✅ **Green Tick:** Animal found. Shows Animal Name.
    *   ❌ **Red Cross:** Tag unrecognized (`found: false`). 
    *   ⏳ **Orange Clock:** Offline/Queued.
*   **Interactive Row:** Tapping a "Red Cross" row instantly opens the *Register Animal Screen*.
*   Session counter (e.g., "142 animals scanned").
*   "Clear Session" button to reset the view.

### 5.2 Register Animal Screen (New Addition)
Turns the scanner into a registration tool.
*   Triggered by tapping an unrecognized tag on the Scan Screen.
*   **Pre-filled Field:** The scanned EPC is automatically populated and locked.
*   **Inputs required:** Name, Species (Dropdown: Cattle, Goat, Sheep, etc.).
*   **Action:** Submits a `POST /api/animals` request.
*   On success, navigates back to the Scan Screen, and the previously failed tag updates to a Green Tick.

### 5.3 Log Screen
Full history of all scans across all sessions stored in SQLite.
*   Displays Timestamp, EPC, Animal Name, and Status (Sent / Failed / Pending).
*   Filterable by Status.

### 5.4 Settings Screen
Setup area, typically accessed by the Farm Manager once.
*   API Base URL input.
*   Bearer Token input (masked).
*   Device ID input (default: `RFIDUH7-II`).
*   "Test Connection" button.

---

## 6. API Contract

### 6.1 Authentication
All requests must include: `Authorization: Bearer {token}`

### 6.2 POST `/api/rfid/scan`
Sent by the app on every valid, deduplicated scan.

**Request:**
```json
{
  "epc": "E280699500005006FCD8F4C8",
  "scanned_at": "2026-04-07T16:33:00Z",
  "device_id": "RFIDUH7-II"
}
```

**Response — Animal Found (200 OK):**
```json
{
  "found": true,
  "animal": {
    "id": "uuid-123",
    "name": "Bessie",
    "species": "Cattle",
    "tag_id": "E280699500005006FCD8F4C8",
    "farm_id": "farm-456"
  }
}
```

**Response — Animal Not Found (200 OK or 404):**
```json
{
  "found": false,
  "message": "No animal registered with this tag"
}
```

### 6.3 POST `/api/animals`
Sent by the app when registering a new animal via the Register screen.

**Request:**
```json
{
  "tag_id": "E280699500005006FCD8F4C8",     // Maps to NFC Tag ID in DB
  "name": "New Calf 01",
  "species": "Cattle"
}
```

**Response — Success (201 Created):**
```json
{
  "success": true,
  "animal": {
    "id": "uuid-999",
    "name": "New Calf 01",
    "tag_id": "E280699500005006FCD8F4C8"
  }
}
```

---

## 7. Offline Handling & Resilience

Farm environments lack reliable connectivity. The SQLite-backed queue is mandatory.

| Scenario | App Behaviour |
| :--- | :--- |
| **No internet on scan** | Save to SQLite queue immediately. Show orange clock icon on row. |
| **Internet restored** | Automatically process the SQLite pending queue in FIFO order. Update icons on success. |
| **API timeout (>10s)** | Treat as a network failure. Leave in pending queue to retry later. |
| **Persistent failure** | After 3 retries, mark as permanently failed. Keep in Log Screen for manual review. |

---

## 8. Non-Functional Requirements

| Requirement | Target |
| :--- | :--- |
| **Scan-to-API Latency** | < 2 seconds on a good connection. |
| **Offline Capacity** | Minimum 10,000 scans stored locally in SQLite. |
| **App Startup** | < 3 seconds. |
| **OS Support** | Android API 28+ (Flutter). |
| **Battery Impact** | Minimal. BroadcastReceiver only wakes Dart isolate on scan. |

---

## 9. Suggested Build Order

To ensure rapid validation of the highest-risk components, follow this implementation sequence:

1.  **Wire up the Android BroadcastReceiver:** Establish the Kotlin-to-Dart platform channel. Confirm that hardware trigger pulls result in EPC strings printed in the Flutter debug console.
2.  **Build the SQLite schema & Scan Manager:** Implement the local database, the 5-second deduplication logic, and the core saving mechanism.
3.  **Build the Scan Screen:** Connect the UI to the local database using mock data to ensure scrolling and state updates (Green Tick, Red Cross, Clock) work smoothly.
4.  **Connect the API & Settings:** Implement HTTP requests, token management, and wire up `POST /api/rfid/scan`.
5.  **Implement Offline Queue:** Add network connectivity listeners and the background retry logic for pending SQLite records.
6.  **Add Register Animal Screen:** Build the form and hook it up to the `POST /api/animals` endpoint as the final feature. 

---
*Prepared for Craft Silicon / Flockr Integration*
# Flockr RFID Scanner — Fix Guide
**Device:** RFIDUH7-II PDA | **Android:** 9 (API 28) | **SDK:** URFIDLibrary-v2.5.0718.aar

---

## What's Wrong (All Issues Found)

| # | File | Problem | Impact |
|---|------|---------|--------|
| 1 | `MainActivity.kt` | `init()` never called — SDK not initialized | **App never connects** |
| 2 | `MainActivity.kt` | `.rfidManager` (property) used instead of `.getRfidManager()` (method) | Returns null silently |
| 3 | `MainActivity.kt` | `enableRF()` and `disConnect()` don't exist in this SDK | Runtime crash |
| 4 | `MainActivity.kt` | Missing `InitListener` import | Can't call init even if tried |
| 5 | `MainActivity.kt` | Operations run before init callback returns | Race condition |

---

## The Root Cause

The `connectToScanner()` function jumps straight to using `rfidManager` 
without ever calling `RFIDSDKManager.getInstance().init()` first.

Without init, `getRfidManager()` returns null. Every operation after 
that silently fails. The app shows "Connected" in the UI but the 
hardware never actually responds.

---

## The Fix — MainActivity.kt

Replace the entire `MainActivity.kt` with this:

```kotlin
package africa.flockr.flockr_scanner_bridge

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.ubx.usdk.RFIDSDKManager
import com.ubx.usdk.listener.InitListener          // ← was missing
import com.ubx.usdk.rfid.aidl.IRfidCallback

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "RFID"
        private const val EVENT_CHANNEL = "africa.flockr.scanner/rfid"
        private const val METHOD_CHANNEL = "africa.flockr.scanner/rfid_commands"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile private var isConnected = false
    @Volatile private var isScanning = false
    private var totalScans = 0

    // ── SDK Callback ──────────────────────────────────────────────
    private val scanCallback = object : IRfidCallback {
        override fun onInventoryTag(epc: String?, data: String?, rssi: Int) {
            if (epc.isNullOrBlank()) return
            totalScans++
            val cleanEpc = epc.uppercase().trim()
            Log.d(TAG, "✓ TAG #$totalScans: $cleanEpc  RSSI: $rssi")
            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "epc" to cleanEpc,
                        "rssi" to rssi,
                        "timestamp" to System.currentTimeMillis(),
                        "count" to totalScans
                    )
                )
            }
        }

        override fun onInventoryTagEnd() {
            Log.d(TAG, "Inventory round ended")
            if (!isScanning) {
                mainHandler.post {
                    eventSink?.success(mapOf("event" to "scanComplete", "count" to totalScans))
                }
            }
        }
    }

    // ── Flutter Engine Setup ──────────────────────────────────────
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "Flutter connected to EventChannel")
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "Flutter disconnected from EventChannel")
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect"      -> connectToScanner(result)
                    "disconnect"   -> { disconnectScanner(); result.success(true) }
                    "startScan"    -> {
                        val mode = call.argument<String>("mode") ?: "continuous"
                        result.success(startScanning(mode))
                    }
                    "stopScan"     -> { stopScanning(); result.success(true) }
                    "isConnected"  -> result.success(isConnected)
                    "isScanning"   -> result.success(isScanning)
                    else           -> result.notImplemented()
                }
            }
    }

    // ── Connect — init SDK first, then use rfidManager ────────────
    private fun connectToScanner(result: MethodChannel.Result) {
        Log.d(TAG, "=== Initializing RFID SDK ===")

        // STEP 1: init() must be called first — everything else depends on it
        RFIDSDKManager.getInstance().init(applicationContext, object : InitListener {
            override fun onStatus(status: Boolean) {
                Log.d(TAG, "SDK init status: $status")

                if (!status) {
                    Log.e(TAG, "SDK init failed")
                    mainHandler.post { result.success(false) }
                    return
                }

                // STEP 2: Now safe to get rfidManager
                try {
                    val rfidManager = RFIDSDKManager.getInstance().getRfidManager()

                    if (rfidManager == null) {
                        Log.e(TAG, "getRfidManager() returned null after init")
                        mainHandler.post { result.success(false) }
                        return
                    }

                    // STEP 3: Configure and register callback
                    rfidManager.setOutputPower(30)
                    rfidManager.setBeepEnable(true)
                    rfidManager.registerCallback(scanCallback)

                    isConnected = true
                    totalScans = 0
                    Log.d(TAG, "=== Connected successfully ===")
                    mainHandler.post { result.success(true) }

                } catch (e: Exception) {
                    Log.e(TAG, "Post-init setup failed: ${e.message}", e)
                    mainHandler.post { result.success(false) }
                }
            }
        })
    }

    // ── Disconnect ────────────────────────────────────────────────
    private fun disconnectScanner() {
        Log.d(TAG, "Disconnecting...")
        stopScanning()
        try {
            RFIDSDKManager.getInstance().release()
        } catch (e: Exception) {
            Log.e(TAG, "Release error: ${e.message}")
        }
        isConnected = false
        Log.d(TAG, "Disconnected")
    }

    // ── Start Scanning ────────────────────────────────────────────
    private fun startScanning(mode: String): Boolean {
        if (!isConnected) {
            Log.e(TAG, "Cannot scan — not connected")
            return false
        }
        val rfidManager = RFIDSDKManager.getInstance().getRfidManager() ?: return false

        return try {
            rfidManager.stopInventory() // clear any previous state
            when (mode) {
                "single" -> {
                    Log.d(TAG, "Starting SINGLE scan")
                    rfidManager.inventorySingle()
                }
                else -> {
                    val timeout = if (mode == "timed") 5 else 0
                    Log.d(TAG, "Starting CONTINUOUS scan (timeout: ${timeout}s)")
                    val res = rfidManager.startInventoryWithTimeout(timeout)
                    if (res != 0) {
                        Log.e(TAG, "startInventoryWithTimeout error: $res")
                        return false
                    }
                }
            }
            isScanning = true
            Log.d(TAG, "Scanning started ($mode)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Start scan error: ${e.message}", e)
            false
        }
    }

    // ── Stop Scanning ─────────────────────────────────────────────
    private fun stopScanning() {
        if (!isScanning) return
        try {
            RFIDSDKManager.getInstance().getRfidManager()?.stopInventory()
        } catch (e: Exception) {
            Log.e(TAG, "Stop scan error: ${e.message}")
        }
        isScanning = false
        Log.d(TAG, "Scanning stopped")
    }

    // ── Hardware Trigger Button ───────────────────────────────────
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if ((event.keyCode == 523 || event.keyCode == 515) && event.repeatCount == 0) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                startScanning("continuous")
                return true
            } else if (event.action == KeyEvent.ACTION_UP) {
                stopScanning()
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    // ── Lifecycle ─────────────────────────────────────────────────
    override fun onStop() {
        stopScanning()
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "Resumed — connected: $isConnected")
    }

    override fun onDestroy() {
        Log.d(TAG, "Destroying — full cleanup")
        disconnectScanner()
        super.onDestroy()
    }
}
```

---

## What Changed and Why

### 1. Added `InitListener` import
```kotlin
// Before — missing entirely
// After
import com.ubx.usdk.listener.InitListener
```

### 2. `connectToScanner` now calls `init()` first
```kotlin
// Before — went straight to rfidManager (always null)
val rfidManager = RFIDSDKManager.getInstance().rfidManager

// After — init first, then use rfidManager in callback
RFIDSDKManager.getInstance().init(applicationContext, object : InitListener {
    override fun onStatus(status: Boolean) {
        if (status) {
            val rfidManager = RFIDSDKManager.getInstance().getRfidManager()
            // now safe to use
        }
    }
})
```

### 3. `.rfidManager` → `.getRfidManager()`
```kotlin
// Before — property access, returns null without init
RFIDSDKManager.getInstance().rfidManager

// After — method call, correct SDK usage
RFIDSDKManager.getInstance().getRfidManager()
```

### 4. Removed non-existent methods
```kotlin
// Before — these don't exist in this SDK, cause runtime crash
rfidManager.enableRF(true)
rfidManager.disConnect()

// After — removed. Use release() instead
RFIDSDKManager.getInstance().release()
```

### 5. `connectToScanner` result now async
Because `init()` is async (callback-based), `result.success()` is 
now called inside the callback on the main thread. This prevents 
Flutter from timing out waiting for a response.

---

## Expected Log After Fix

```
D/RFID: === Initializing RFID SDK ===
D/RFID: SDK init status: true
D/RFID: === Connected successfully ===
D/RFID: Scanning started (continuous)
D/RFID: ✓ TAG #1: E280699500005006FCD8F4C8  RSSI: 72
D/RFID: ✓ TAG #2: E2806890000040030B6631C9  RSSI: 68
```

---

## How to Test

```powershell
# Run app
flutter run -d 01082403006016

# Watch logs in separate terminal
$env:PATH += ";C:\Users\rodne\AppData\Local\Android\Sdk\platform-tools"
adb logcat | findstr "RFID"
```

1. Tap **Connect** in the app
2. Tap **Start Scanning**
3. Hold a yellow ear tag near the back of the device
4. Real EPCs should appear in the list and in logcat

---

## After Scanning Works

Once real EPCs appear:

1. Open **Settings** (gear icon) in the app
2. Enter Flockr API URL and Bearer Token
3. Uncomment the sync timer in `scan_manager.dart` (line 17-20)
4. Test that scans sync to the Flockr backend

---

## Proguard Rules

Make sure `android/app/proguard-rules.pro` contains:
```
-keep class com.ubx.**{*;}
-keep class com.rfid.**{*;}
-keep class com.rfiddevice.**{*;}
-keep class android.device.**{*;}
-keep class android.content.**{*;}
-keep class android.os.**{*;}
```
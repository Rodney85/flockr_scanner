# Flockr RFID Scanner — Development Guide
## Hardware ↔ Software Integration Fix

**Status:** UI works ✅ | Hardware not communicating ❌  
**Root cause:** App uses raw serial port reads. Device has an official SDK that must be used instead.

---

## The Problem in One Line

We were trying to read `/dev/ttyHSL0` as raw bytes. The device manufacturer provides `URFIDLibrary-xxxxxx.aar` — an Android SDK that handles all hardware communication. We must use this SDK.

---

## Step 1 — Get the AAR File

The SDK file is named `URFIDLibrary-xxxxxx.aar` (xxxx = version number).

**Where to find it:**
- It ships with the RFIDUH7-II device or on the manufacturer CD/USB
- Ask Craft Silicon if they have it — the device likely came with a demo APK and SDK package
- Check Scanner A's APK — extract it and look in the `lib/` folder
- Contact the device supplier (the company that sold the RFIDUH7-II units)

Once you have the `.aar` file, proceed.

---

## Step 2 — Add the AAR to the Project

```
android/
  app/
    libs/
      URFIDLibrary-xxxxxx.aar   ← place it here
```

In `android/app/build.gradle`, add:
```gradle
dependencies {
    implementation files('libs/URFIDLibrary-xxxxxx.aar')
    // ... existing dependencies
}
```

---

## Step 3 — Rewrite MainActivity.kt

Replace the entire current `MainActivity.kt` with this:

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
import com.ubx.usdk.listener.InitListener
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
            RFIDSDKManager.getInstance().getRfidManager()?.stopInventory()
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

    // ── Activity Lifecycle ────────────────────────────────────────
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

## Step 4 — Add Proguard Rules

In `android/app/proguard-rules.pro`:
```
-keep class com.ubx.**{*;}
-keep class com.rfid.**{*;}
-keep class com.rfiddevice.**{*;}
-keep class android.device.**{*;}
-keep class android.content.**{*;}
-keep class android.os.**{*;}
```

---

## Step 5 — Flutter Side (No Changes Needed)

The Flutter/Dart side is already correct. It listens on the same EventChannel and calls `scanManager.processScan(epc)`. No changes needed there.

---

## Step 6 — Build and Test

```powershell
flutter run -d 01082403006016
```

Watch logs:
```powershell
adb logcat | findstr "RFID"
```

**Expected log sequence:**
```
D/RFID: SDK initialized successfully
D/RFID: Inventory started, result: 0
D/RFID: Tag scanned: E280699500005006FCD8F4C8
D/RFID: Tag scanned: E2806890000040030B6631C9
```

---

## Troubleshooting

### "Cannot resolve symbol RFIDSDKManager"
The AAR isn't imported correctly. Check:
- File is in `android/app/libs/`
- `build.gradle` has `implementation files('libs/URFIDLibrary-xxxxxx.aar')`
- Run `flutter clean` then rebuild

### "SDK initialization failed"
- The AAR version may not match the device firmware
- Try calling `RFIDSDKManager.getInstance().enableLog(true)` before init for verbose output

### Tags scanned but nothing in Flutter
- Verify EVENT_CHANNEL name matches exactly in both Kotlin and Dart: `africa.flockr.scanner/rfid`
- Check that `eventSink` is not null when `onInventoryTag` fires

### Hardware trigger button doesn't work
- Try different key codes: `523`, `515`, `284`
- Add `Log.d("RFID", "Key: ${event.keyCode}")` in `dispatchKeyEvent` to find the right code

---

## Architecture After Fix

```
RFID Hardware
     ↓
URFIDLibrary-xxxxxx.aar (SDK)
     ↓ onInventoryTag(EPC, Data, RSSI)
MainActivity.kt (Kotlin)
     ↓ EventChannel "africa.flockr.scanner/rfid"
main.dart (Flutter/Dart)
     ↓ scanManager.processScan(epc)
SQLite DB + API sync
     ↓
Flockr Backend
```

---

## What Was Wrong Before

| Attempt | Why It Failed |
|---------|---------------|
| Android Intent BroadcastReceiver | Device doesn't broadcast intents |
| Raw FileInputStream on /dev/ttyHSL0 | Reads bytes but wrong protocol — binary frame format not understood |
| Binary start command `0xBB 0x00 0x22...` | May work but parsing response is complex without SDK |
| **Official SDK (current fix)** | **Correct approach — SDK handles all protocol details** |

---

## Next Steps After Hardware Works

1. ✅ Confirm real EPCs appear in logs
2. ✅ Confirm UI shows real EPCs (not TEST_ ones)
3. Go to Settings in the app → enter Flockr API URL and Bearer Token
4. Confirm `Sync successful` appears in logs
5. Test offline mode — disable WiFi, scan, re-enable, verify sync catches up
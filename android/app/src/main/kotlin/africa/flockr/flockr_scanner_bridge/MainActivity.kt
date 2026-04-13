package africa.flockr.flockr_scanner_bridge

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.ubx.usdk.RFIDSDKManager
import com.ubx.usdk.rfid.aidl.IRfidCallback

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "RFID"
        private const val EVENT_CHANNEL = "africa.flockr.scanner/rfid"
        private const val METHOD_CHANNEL = "africa.flockr.scanner/rfid_commands"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var isConnected = false

    @Volatile
    private var isScanning = false
    private var totalScans = 0

    // --- SDK Callback ---
    private val scanCallback = object : IRfidCallback {

        override fun onInventoryTag(epc: String?, data: String?, rssi: Int) {
            if (epc.isNullOrBlank()) return

            totalScans++
            val cleanEpc = epc.uppercase().trim()
            val count = totalScans

            Log.d(TAG, "✓ TAG #$count: $cleanEpc  RSSI: $rssi")

            mainHandler.post {
                eventSink?.success(
                    mapOf(
                        "epc" to cleanEpc,
                        "rssi" to rssi,
                        "timestamp" to System.currentTimeMillis(),
                        "count" to count
                    )
                )
            }
        }

        override fun onInventoryTagEnd() {
            Log.d(TAG, "Inventory round ended")
            // In continuous mode the SDK auto-restarts; in single mode this is the final callback.
            if (!isScanning) {
                mainHandler.post {
                    eventSink?.success(
                        mapOf(
                            "event" to "scanComplete",
                            "count" to totalScans
                        )
                    )
                }
            }
        }
    }

    // --- Lifecycle ---

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created — Urovo SDK RFID Scanner")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel — streams tag data to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "Flutter connected to EventChannel")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "Flutter disconnected from EventChannel")
                }
            }
        )

        // MethodChannel — receives commands from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val success = connectToScanner()
                    result.success(success)
                }

                "disconnect" -> {
                    disconnectScanner()
                    result.success(true)
                }

                "startScan" -> {
                    val mode = call.argument<String>("mode") ?: "continuous"
                    val success = startScanning(mode)
                    result.success(success)
                }

                "stopScan" -> {
                    stopScanning()
                    result.success(true)
                }

                "isConnected" -> result.success(isConnected)
                "isScanning" -> result.success(isScanning)

                else -> result.notImplemented()
            }
        }
    }

    // --- Scanner Operations ---

    private fun connectToScanner(): Boolean {
        return try {
            Log.d(TAG, "=== Connecting via Urovo SDK (Robust Mode) ===")

            // Reset power state to ensure a clean switch (True -> False)
            RFIDSDKManager.getInstance().enableScanHead(true)
            Thread.sleep(200)
            RFIDSDKManager.getInstance().enableScanHead(false)

            // Wait significantly longer for the power switch to stabilize and OTG to discover the module
            Log.d(TAG, "Waiting 1000ms for hardware initialization...")
            Thread.sleep(1000)

            val rfidManager = RFIDSDKManager.getInstance().rfidManager
            if (rfidManager == null) {
                Log.e(TAG, "RfidManager is null — SDK not available on this device")
                return false
            }

            // Enable the RFID Radio Frequency (Required for hardware communication)
            val rfResult = rfidManager.enableRF(true)
            Log.d(TAG, "rfidManager.enableRF(true) returned: $rfResult")

            // On the Urovo SDK, 0 is success. -1 or other values indicate failure.
            if (rfResult != 0) {
                Log.e(TAG, "Critical: enableRF failed. Scanner will not work.")
                return false
            }

            // Set scanning power to maximum (30 dBm) for optimal results
            rfidManager.setOutputPower(30)

            // Register our callback to receive tag data
            rfidManager.registerCallback(scanCallback)

            // Enable the hardware beep for each tag read
            rfidManager.setBeepEnable(true)

            isConnected = true
            totalScans = 0
            Log.d(TAG, "=== Connected successfully ===")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Connection failed: ${e.message}", e)
            false
        }
    }

    private fun disconnectScanner() {
        Log.d(TAG, "Disconnecting scanner...")
        stopScanning()
        try {
            val rfidManager = RFIDSDKManager.getInstance().rfidManager
            rfidManager?.enableRF(false)
            rfidManager?.disConnect()
            
            RFIDSDKManager.getInstance().enableScanHead(true)
            RFIDSDKManager.getInstance().release()
        } catch (e: Exception) {
            Log.e(TAG, "Release error: ${e.message}")
        }
        isConnected = false
        Log.d(TAG, "Disconnected")
    }

    private fun startScanning(mode: String): Boolean {
        if (!isConnected) {
            Log.e(TAG, "Cannot start — not connected")
            return false
        }

        val rfidManager = RFIDSDKManager.getInstance().rfidManager
        if (rfidManager == null) {
            Log.e(TAG, "RfidManager is null")
            return false
        }

        return try {
            // Ensure any previous inventory is stopped to avoid "Busy" error (-1)
            rfidManager.stopInventory()

            when (mode) {
                "single" -> {
                    Log.d(TAG, "Starting SINGLE inventory")
                    rfidManager.inventorySingle()
                }

                else -> {
                    // "continuous" or "timed" — use continuous with timeout
                    val timeout = if (mode == "timed") 5 else 0  // 0 = no timeout (continuous)
                    Log.d(TAG, "Starting CONTINUOUS inventory (timeout: ${timeout}s)")
                    val result = rfidManager.startInventoryWithTimeout(timeout)
                    if (result != 0) {
                        Log.e(TAG, "startInventoryWithTimeout returned error code: $result")
                        return false
                    }
                }
            }

            isScanning = true
            Log.d(TAG, "Scanning started ($mode mode)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Start scan failed: ${e.message}", e)
            false
        }
    }

    private fun stopScanning() {
        if (!isScanning) return

        Log.d(TAG, "Stopping scan...")
        try {
            RFIDSDKManager.getInstance().rfidManager?.stopInventory()
        } catch (e: Exception) {
            Log.e(TAG, "Stop scan error: ${e.message}")
        }
        isScanning = false
        Log.d(TAG, "Scan stopped")
    }

    // --- Activity Lifecycle Cleanup ---

    override fun onStop() {
        Log.d(TAG, "Activity stopped — releasing hardware")
        stopScanning()
        try {
            RFIDSDKManager.getInstance().enableScanHead(true)
        } catch (e: Exception) {
            Log.w(TAG, "enableScanHead on stop: ${e.message}")
        }
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        if (isConnected) {
            try {
                RFIDSDKManager.getInstance().enableScanHead(false)
            } catch (e: Exception) {
                Log.w(TAG, "enableScanHead on resume: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "Activity destroying — full cleanup")
        disconnectScanner()
        super.onDestroy()
    }
}
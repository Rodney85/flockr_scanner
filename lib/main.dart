import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database/database.dart';
import 'managers/scan_manager.dart';
import 'managers/api_client.dart';

// Global initialization
late final AppDatabase appDb;
late final ApiClient apiClient;
late final ScanManager scanManager;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appDb = AppDatabase();
  apiClient = ApiClient();
  scanManager = ScanManager(appDb, apiClient);
  scanManager.startSyncTimer();

  runApp(const FlockrScannerApp());
}

class FlockrScannerApp extends StatelessWidget {
  const FlockrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flockr RFID Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const EventChannel _rfidChannel =
      EventChannel('africa.flockr.scanner/rfid');
  static const MethodChannel _methodChannel =
      MethodChannel('africa.flockr.scanner/rfid_commands');

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isScanning = false;
  String _scanMode = 'continuous';
  String _lastEpc = '';
  int _lastRssi = 0;
  int _totalTags = 0;
  StreamSubscription? _scanSubscription;

  final List<String> _scanModes = ['continuous', 'single', 'timed'];
  final Map<String, String> _modeLabels = {
    'continuous': 'Continuous',
    'single': 'Single Tag',
    'timed': 'Timed (5s)',
  };

  @override
  void initState() {
    super.initState();
  }

  Future<void> _playScanSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (e) {
      debugPrint('Sound play failed: $e');
    }
  }

  Future<void> _connect() async {
    setState(() => _isConnecting = true);

    try {
      final result = await _methodChannel.invokeMethod<bool>('connect');
      if (result == true) {
        setState(() => _isConnected = true);
        _startListening();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connected to RFID scanner'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect — is the UHF module available?'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await _methodChannel.invokeMethod('disconnect');
      _scanSubscription?.cancel();
      setState(() {
        _isConnected = false;
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected')),
        );
      }
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  void _startListening() {
    _scanSubscription = _rfidChannel.receiveBroadcastStream().listen(
      (dynamic event) async {
        if (event is Map) {
          // Handle scan-complete events
          final eventType = event['event'] as String?;
          if (eventType == 'scanComplete') {
            setState(() => _isScanning = false);
            return;
          }

          final epc = event['epc'] as String? ?? '';
          final rssi = event['rssi'] as int? ?? 0;

          if (epc.isNotEmpty) {
            await _playScanSound();
            await scanManager.processScan(epc);

            setState(() {
              _lastEpc = epc;
              _lastRssi = rssi;
              _totalTags++;
            });
          }
        }
      },
      onError: (error) {
        debugPrint('RFID stream error: $error');
      },
    );
  }

  Future<void> _startScan() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await _methodChannel.invokeMethod<bool>('startScan', {
        'mode': _scanMode,
      });

      if (result == true) {
        setState(() => _isScanning = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scanning started ($_scanMode mode)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopScan() async {
    try {
      await _methodChannel.invokeMethod('stopScan');
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scanning stopped')),
        );
      }
    } catch (e) {
      debugPrint('Stop scan error: $e');
    }
  }

  Future<void> _clearData() async {
    await appDb.clearScans();
    setState(() {
      _totalTags = 0;
      _lastEpc = '';
      _lastRssi = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All scan data cleared')),
      );
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  /// Convert RSSI dBm value to a signal icon
  IconData _rssiIcon(int rssi) {
    if (rssi == 0) return Icons.signal_wifi_0_bar;
    final abs = rssi.abs();
    if (abs < 40) return Icons.signal_cellular_alt;
    if (abs < 60) return Icons.signal_cellular_alt_2_bar;
    if (abs < 80) return Icons.signal_cellular_alt_1_bar;
    return Icons.signal_cellular_0_bar;
  }

  Color _rssiColor(int rssi) {
    if (rssi == 0) return Colors.grey;
    final abs = rssi.abs();
    if (abs < 40) return Colors.green;
    if (abs < 60) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flockr RFID Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearData,
            tooltip: 'Clear all data',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Control Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border:
                  Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isConnected || _isConnecting) ? null : _connect,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.usb),
                        label: Text(_isConnecting ? 'CONNECTING...' : 'CONNECT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isConnected ? _disconnect : null,
                        icon: const Icon(Icons.usb_off),
                        label: const Text('DISCONNECT'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isConnecting
                          ? Icons.sync
                          : _isConnected
                              ? Icons.check_circle
                              : Icons.cancel,
                      color: _isConnecting
                          ? Colors.orange
                          : _isConnected
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnecting
                          ? 'Connecting...'
                          : _isConnected
                              ? 'Connected (Urovo SDK)'
                              : 'Disconnected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnecting
                            ? Colors.orange
                            : _isConnected
                                ? Colors.green
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scan Control Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Mode:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _scanMode,
                        isExpanded: true,
                        onChanged: _isScanning
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _scanMode = value);
                                }
                              },
                        items: _scanModes.map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(_modeLabels[mode] ?? mode),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Start/Stop Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScan : _startScan,
                    icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      _isScanning ? 'STOP SCANNING' : 'START SCANNING',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isScanning ? Colors.red : Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Last Scan Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              border: Border(
                top: BorderSide(color: Colors.teal.shade200),
                bottom: BorderSide(color: Colors.teal.shade200),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'LAST SCAN',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastEpc.isEmpty ? 'No tag scanned yet' : _lastEpc,
                  style: TextStyle(
                    fontSize: _lastEpc.isEmpty ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _lastEpc.isEmpty ? Colors.grey : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Total Tags: $_totalTags',
                      style: const TextStyle(fontSize: 14, color: Colors.teal),
                    ),
                    if (_lastRssi != 0) ...[
                      const SizedBox(width: 16),
                      Icon(
                        _rssiIcon(_lastRssi),
                        color: _rssiColor(_lastRssi),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'RSSI: $_lastRssi',
                        style: TextStyle(
                          fontSize: 14,
                          color: _rssiColor(_lastRssi),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Scanned Tags List
          Expanded(
            child: StreamBuilder<List<Scan>>(
              stream: appDb.watchAllScans(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final scans = snapshot.data!;

                if (scans.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No tags scanned yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Connect and start scanning',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scanned Tags (${scans.length})',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Latest first',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: scans.length,
                        itemBuilder: (context, index) {
                          final scan = scans[index];
                          final isNew = index == 0;

                          return ListTile(
                            leading: Icon(
                              Icons.nfc,
                              color: isNew ? Colors.teal : Colors.grey,
                            ),
                            title: Text(
                              scan.epc,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(_formatTimestamp(scan.scannedAt)),
                            trailing: isNew
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.teal,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

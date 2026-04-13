import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' hide Column;
import '../database/database.dart';
import 'api_client.dart';

class ScanManager {
  final AppDatabase db;
  final ApiClient apiClient;
  
  String? _lastScannedEpc;
  DateTime? _lastScanTime;
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  ScanManager(this.db, this.apiClient);

  void startSyncTimer() {
    // API sync disabled for now - enable after confirming RFID scanning works
    // _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    //   _syncPendingScans();
    // });
    debugPrint('API sync disabled - scanning mode only');
  }

  void dispose() {
    _syncTimer?.cancel();
  }

  Future<void> _syncPendingScans() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingScans = await db.getPendingScans();
      if (pendingScans.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (final scan in pendingScans) {
        try {
          final result = await apiClient.sendScan(scan.epc);
          await db.updateScan(
            scan.id, 
            'completed', 
            found: result['found'], 
            animalName: result['animalName']
          );
          debugPrint('Sync successful: ${scan.epc}');
        } catch (e) {
          debugPrint('Sync failed for ${scan.epc}: $e');
          // Stays pending for the next polling cycle
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
  
  // App-level deduplication: same EPC within 5 seconds
  Future<void> processScan(String epc) async {
    final now = DateTime.now();
    
    if (_lastScannedEpc == epc && _lastScanTime != null) {
      if (now.difference(_lastScanTime!).inSeconds < 5) {
        debugPrint('Scan ignored: Duplicate EPC within 5 seconds ($epc)');
        return;
      }
    }
    
    _lastScannedEpc = epc;
    _lastScanTime = now;
    
    // Save to local DB first (persistence)
    await db.into(db.scans).insert(ScansCompanion.insert(
      epc: epc,
      scannedAt: now,
      status: const Value('pending'),
    ));
    
    debugPrint('Scan saved to DB: $epc');
    
    // API sync disabled - data stored locally only
    // _syncPendingScans();
  }
}

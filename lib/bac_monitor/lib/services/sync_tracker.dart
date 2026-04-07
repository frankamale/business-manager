import 'package:sqflite/sqflite.dart';
import '../../../shared/database/unified_db_helper.dart';

/// Sync Tracker Service
/// 
/// Manages persistent synchronization timestamps for different sync types.
/// Supports incremental data synchronization by tracking the last successful
/// sync time for each data category (KPI, baseline, historical).
class SyncTracker {
  static final SyncTracker _instance = SyncTracker._internal();

  /// Singleton instance
  static SyncTracker get instance => _instance;

  /// Database helper instance
  final UnifiedDatabaseHelper _dbHelper = UnifiedDatabaseHelper.instance;

  /// Table name for sync tracking
  static const String _tableName = 'sync_tracker';

  /// Internal constructor
  SyncTracker._internal();

  /// Sync type constants
  static const String syncTypeKPI = 'kpi';
  static const String syncTypeBaseline = 'baseline';
  static const String syncTypeHistorical = 'historical';

  /// Sync status constants
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';
  static const String statusInProgress = 'in_progress';

  /// Initialize the sync tracker table
  /// 
  /// Creates the sync_tracker table if it doesn't exist.
  /// This should be called during app initialization or after database creation.
  /// 
  /// Example:
  /// ```dart
  /// await SyncTracker.instance.initialize();
  /// ```
  Future<void> initialize() async {
    try {
      final db = _dbHelper.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_type TEXT NOT NULL,
          last_sync_timestamp TEXT NOT NULL,
          sync_status TEXT DEFAULT '$statusCompleted',
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      print('[SyncTracker] Table initialized successfully');
    } catch (e) {
      print('[SyncTracker] Error initializing table: $e');
      rethrow;
    }
  }

  /// Get the last successful sync time for a specific sync type
  /// 
  /// Returns the timestamp of the last completed sync for the given type,
  /// or null if no sync has been recorded.
  /// 
  /// Parameters:
  /// - [syncType]: The type of sync to query (e.g., 'kpi', 'baseline', 'historical')
  /// 
  /// Returns:
  /// - ISO 8601 timestamp string of the last sync, or null
  /// 
  /// Example:
  /// ```dart
  /// final lastSync = await SyncTracker.instance.getLastSyncTime(SyncTracker.syncTypeKPI);
  /// if (lastSync != null) {
  ///   print('Last KPI sync was at: $lastSync');
  /// }
  /// ```
  Future<String?> getLastSyncTime(String syncType) async {
    try {
      final db = _dbHelper.database;
      final results = await db.query(
        _tableName,
        columns: ['last_sync_timestamp'],
        where: 'sync_type = ? AND sync_status = ?',
        whereArgs: [syncType, statusCompleted],
        orderBy: 'updated_at DESC',
        limit: 1,
      );

      if (results.isNotEmpty) {
        final timestamp = results.first['last_sync_timestamp'] as String?;
        print('[SyncTracker] Last sync time for $syncType: $timestamp');
        return timestamp;
      }

      print('[SyncTracker] No sync record found for $syncType');
      return null;
    } catch (e) {
      print('[SyncTracker] Error getting last sync time for $syncType: $e');
      return null;
    }
  }

  /// Record a successful synchronization
  /// 
  /// Inserts or updates the sync record for the given sync type.
  /// If a record already exists for the sync type, it updates the timestamp
  /// and updated_at fields. Otherwise, it creates a new record.
  /// 
  /// Parameters:
  /// - [syncType]: The type of sync being recorded
  /// - [timestamp]: The ISO 8601 timestamp of the sync completion
  /// - [status]: Optional status (defaults to 'completed')
  /// 
  /// Example:
  /// ```dart
  /// await SyncTracker.instance.recordSync(
  ///   SyncTracker.syncTypeKPI,
  ///   DateTime.now().toIso8601String(),
  /// );
  /// ```
  Future<void> recordSync(String syncType, String timestamp, {String status = statusCompleted}) async {
    try {
      final db = _dbHelper.database;
      final now = DateTime.now().toIso8601String();

      // Check if record exists
      final existing = await db.query(
        _tableName,
        columns: ['id'],
        where: 'sync_type = ?',
        whereArgs: [syncType],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Update existing record
        await db.update(
          _tableName,
          {
            'last_sync_timestamp': timestamp,
            'sync_status': status,
            'updated_at': now,
          },
          where: 'sync_type = ?',
          whereArgs: [syncType],
        );
        print('[SyncTracker] Updated sync record for $syncType');
      } else {
        // Insert new record
        await db.insert(
          _tableName,
          {
            'sync_type': syncType,
            'last_sync_timestamp': timestamp,
            'sync_status': status,
            'created_at': now,
            'updated_at': now,
          },
        );
        print('[SyncTracker] Created new sync record for $syncType');
      }
    } catch (e) {
      print('[SyncTracker] Error recording sync for $syncType: $e');
      rethrow;
    }
  }

  /// Get all sync timestamps for all sync types
  /// 
  /// Returns a map where keys are sync types and values are the
  /// last sync timestamps. Only includes sync types that have
  /// been recorded.
  /// 
  /// Returns:
  /// - Map<String, String> of sync_type -> last_sync_timestamp
  /// 
  /// Example:
  /// ```dart
  /// final allSyncTimes = await SyncTracker.instance.getAllSyncTimes();
  /// allSyncTimes.forEach((type, time) {
  ///   print('$type: $time');
  /// });
  /// ```
  Future<Map<String, String>> getAllSyncTimes() async {
    try {
      final db = _dbHelper.database;
      final results = await db.query(
        _tableName,
        columns: ['sync_type', 'last_sync_timestamp'],
        orderBy: 'sync_type ASC',
      );

      final Map<String, String> syncTimes = {};
      for (final row in results) {
        final syncType = row['sync_type'] as String;
        final timestamp = row['last_sync_timestamp'] as String;
        syncTimes[syncType] = timestamp;
      }

      print('[SyncTracker] Retrieved ${syncTimes.length} sync times');
      return syncTimes;
    } catch (e) {
      print('[SyncTracker] Error getting all sync times: $e');
      return {};
    }
  }

  /// Clear all sync history
  /// 
  /// Deletes all records from the sync_tracker table.
  /// Use this when you need to force a full resync of all data.
  /// 
  /// Example:
  /// ```dart
  /// await SyncTracker.instance.clearSyncHistory();
  /// ```
  Future<void> clearSyncHistory() async {
    try {
      final db = _dbHelper.database;
      final deleted = await db.delete(_tableName);
      print('[SyncTracker] Cleared $deleted sync records');
    } catch (e) {
      print('[SyncTracker] Error clearing sync history: $e');
      rethrow;
    }
  }

  /// Clear sync history for a specific sync type
  /// 
  /// Deletes only the records for the specified sync type.
  /// Useful when you need to force a resync of specific data.
  /// 
  /// Parameters:
  /// - [syncType]: The type of sync to clear
  /// 
  /// Example:
  /// ```dart
  /// await SyncTracker.instance.clearSyncType(SyncTracker.syncTypeKPI);
  /// ```
  Future<void> clearSyncType(String syncType) async {
    try {
      final db = _dbHelper.database;
      final deleted = await db.delete(
        _tableName,
        where: 'sync_type = ?',
        whereArgs: [syncType],
      );
      print('[SyncTracker] Cleared $deleted sync records for $syncType');
    } catch (e) {
      print('[SyncTracker] Error clearing sync type $syncType: $e');
      rethrow;
    }
  }

  /// Calculate data delta for incremental updates
  /// 
  /// Returns the timestamp from which to fetch incremental updates.
  /// If no previous sync exists, returns null to indicate a full sync is needed.
  /// 
  /// Parameters:
  /// - [syncType]: The type of sync to calculate delta for
  /// 
  /// Returns:
  /// - The last sync timestamp, or null if no sync exists
  /// 
  /// Example:
  /// ```dart
  /// final deltaFrom = await SyncTracker.instance.getDeltaTimestamp(SyncTracker.syncTypeKPI);
  /// if (deltaFrom == null) {
  ///   // Perform full sync
  ///   await fetchAllKPIData();
  /// } else {
  ///   // Perform incremental sync
  ///   await fetchKPIDataSince(deltaFrom);
  /// }
  /// ```
  Future<String?> getDeltaTimestamp(String syncType) async {
    return await getLastSyncTime(syncType);
  }

  /// Check if a sync type has ever been synced
  /// 
  /// Parameters:
  /// - [syncType]: The type of sync to check
  /// 
  /// Returns:
  /// - true if the sync type has been recorded, false otherwise
  Future<bool> hasSynced(String syncType) async {
    try {
      final db = _dbHelper.database;
      final results = await db.query(
        _tableName,
        columns: ['id'],
        where: 'sync_type = ? AND sync_status = ?',
        whereArgs: [syncType, statusCompleted],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      print('[SyncTracker] Error checking sync status for $syncType: $e');
      return false;
    }
  }

  /// Record a failed synchronization attempt
  /// 
  /// Updates the sync record to indicate a failed status.
  /// This is useful for tracking sync issues and retry logic.
  /// 
  /// Parameters:
  /// - [syncType]: The type of sync that failed
  /// - [timestamp]: The timestamp when the failure occurred
  Future<void> recordFailedSync(String syncType, String timestamp) async {
    await recordSync(syncType, timestamp, status: statusFailed);
  }
}

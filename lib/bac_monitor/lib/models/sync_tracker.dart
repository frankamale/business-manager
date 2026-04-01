/// Sync Tracker Model
/// 
/// Data models for tracking synchronization state and progress.
/// Used by the staged sync flow to persist sync timestamps and
/// enable incremental/delta-based synchronization.

/// Enum representing the phase of synchronization
enum SyncPhase {
  idle,
  kpiFetch,
  baselineFetch,
  complete,
  historicalFetch,
  error,
}

/// Model representing a sync operation record
class SyncRecord {
  final int? id;
  final String syncType;          // 'full', 'incremental', 'historical', 'staged', 'partial'
  final String syncStatus;        // 'in_progress', 'completed', 'failed', 'completed_with_errors'
  final DateTime startTimestamp;
  final DateTime? endTimestamp;
  final int recordsFetched;
  final String? dateRangeStart;
  final String? dateRangeEnd;
  final String? errorMessage;
  final DateTime? lastSyncTimestamp;

  SyncRecord({
    this.id,
    required this.syncType,
    this.syncStatus = 'in_progress',
    required DateTime completedAt,
    this.recordsFetched = 0,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.errorMessage,
    DateTime? lastSyncTimestamp,
  }) : startTimestamp = lastSyncTimestamp ?? DateTime.now().subtract(const Duration(seconds: 1)),
       endTimestamp = completedAt,
       lastSyncTimestamp = lastSyncTimestamp;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_type': syncType,
      'sync_status': syncStatus,
      'start_timestamp': startTimestamp.millisecondsSinceEpoch ~/ 1000,
      'end_timestamp': endTimestamp!.millisecondsSinceEpoch ~/ 1000,
      'records_fetched': recordsFetched,
      'date_range_start': dateRangeStart,
      'date_range_end': dateRangeEnd,
      'error_message': errorMessage,
    };
  }

  factory SyncRecord.fromMap(Map<String, dynamic> map) {
    final endTimestampValue = map['end_timestamp'] as int?;
    final startTimestampValue = map['start_timestamp'] as int?;
    
    return SyncRecord(
      id: map['id'] as int?,
      syncType: map['sync_type'] as String? ?? 'unknown',
      syncStatus: map['sync_status'] as String? ?? 'in_progress',
      completedAt: endTimestampValue != null
          ? DateTime.fromMillisecondsSinceEpoch(endTimestampValue * 1000)
          : DateTime.now(),
      recordsFetched: map['records_fetched'] as int? ?? 0,
      dateRangeStart: map['date_range_start'] as String?,
      dateRangeEnd: map['date_range_end'] as String?,
      errorMessage: map['error_message'] as String?,
      lastSyncTimestamp: startTimestampValue != null
          ? DateTime.fromMillisecondsSinceEpoch(startTimestampValue * 1000)
          : null,
    );
  }

  SyncRecord copyWith({
    int? id,
    String? syncType,
    String? syncStatus,
    DateTime? startTimestamp,
    DateTime? endTimestamp,
    int? recordsFetched,
    String? dateRangeStart,
    String? dateRangeEnd,
    String? errorMessage,
  }) {
    return SyncRecord(
      id: id ?? this.id,
      syncType: syncType ?? this.syncType,
      syncStatus: syncStatus ?? this.syncStatus,
      completedAt: endTimestamp ?? this.endTimestamp ?? DateTime.now(),
      recordsFetched: recordsFetched ?? this.recordsFetched,
      dateRangeStart: dateRangeStart ?? this.dateRangeStart,
      dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncTimestamp: startTimestamp ?? this.startTimestamp,
    );
  }
}

/// Result of baseline data synchronization
class BaselineSyncResult {
  final List<dynamic> servicePoints;
  final Map<String, dynamic> companyDetails;
  final List<dynamic> inventory;
  final List<dynamic> customers;

  BaselineSyncResult({
    required this.servicePoints,
    required this.companyDetails,
    required this.inventory,
    required this.customers,
  });

  int get totalRecords {
    return servicePoints.length + 
           (companyDetails.isNotEmpty ? 1 : 0) + 
           inventory.length + 
           customers.length;
  }
}

/// Result of incremental sync operation
class IncrementalSyncResult {
  final String syncType; // 'full', 'incremental', 'skipped'
  final int recordsFetched;
  final DateTime? lastSyncTimestamp;

  IncrementalSyncResult({
    required this.syncType,
    required this.recordsFetched,
    this.lastSyncTimestamp,
  });

  bool get wasSkipped => syncType == 'skipped';
  bool get wasFullSync => syncType == 'full';
  bool get wasIncremental => syncType == 'incremental';
}

/// Result of partial sync operation (when some datasets fail)
class PartialSyncResult {
  final bool kpiSuccess;
  final bool baselineSuccess;
  final List<String> failedDatasets;
  final int totalRecordsFetched;

  PartialSyncResult({
    required this.kpiSuccess,
    required this.baselineSuccess,
    required this.failedDatasets,
    required this.totalRecordsFetched,
  });

  bool get isCompleteSuccess => kpiSuccess && baselineSuccess && failedDatasets.isEmpty;
  bool get isPartialSuccess => kpiSuccess || baselineSuccess;
  bool get isCompleteFailure => !kpiSuccess && !baselineSuccess;
}

/// Immutable state class for sync progress
class SyncState {
  final SyncPhase phase;
  final double progress;          // 0.0 to 1.0
  final String message;
  final int recordsFetched;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.progress = 0.0,
    this.message = '',
    this.recordsFetched = 0,
    this.lastSyncTime,
    this.errorMessage,
  });

  bool get isLoading => phase == SyncPhase.kpiFetch ||
      phase == SyncPhase.baselineFetch ||
      phase == SyncPhase.historicalFetch;

  bool get isComplete => phase == SyncPhase.complete;
  bool get hasError => phase == SyncPhase.error;

  SyncState copyWith({
    SyncPhase? phase,
    double? progress,
    String? message,
    int? recordsFetched,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      recordsFetched: recordsFetched ?? this.recordsFetched,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'SyncState(phase: $phase, progress: $progress, message: $message, recordsFetched: $recordsFetched)';
  }
}

enum CloudSyncStatus { localOnly, pendingSync, synced, syncError }

enum SyncQueueOperation { upsert, delete }

enum CloudSyncPhase {
  idle,
  syncing,
  pending,
  restored,
  offline,
  timeout,
  error,
}

class CloudSyncState {
  final CloudSyncPhase phase;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final DateTime? lastRestoreAt;
  final DateTime? lastAttemptAt;
  final String? lastError;

  const CloudSyncState({
    this.phase = CloudSyncPhase.idle,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.lastRestoreAt,
    this.lastAttemptAt,
    this.lastError,
  });

  bool get isSyncing => phase == CloudSyncPhase.syncing;

  CloudSyncState copyWith({
    CloudSyncPhase? phase,
    int? pendingCount,
    DateTime? lastSyncedAt,
    DateTime? lastRestoreAt,
    DateTime? lastAttemptAt,
    String? lastError,
    bool clearError = false,
  }) {
    return CloudSyncState(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastRestoreAt: lastRestoreAt ?? this.lastRestoreAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phase': phase.name,
      'pendingCount': pendingCount,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'lastRestoreAt': lastRestoreAt?.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  factory CloudSyncState.fromMap(Map<String, dynamic> map) {
    return CloudSyncState(
      phase: CloudSyncPhase.values.firstWhere(
        (phase) => phase.name == map['phase'],
        orElse: () => CloudSyncPhase.idle,
      ),
      pendingCount: (map['pendingCount'] as num?)?.toInt() ?? 0,
      lastSyncedAt: DateTime.tryParse(map['lastSyncedAt']?.toString() ?? ''),
      lastRestoreAt: DateTime.tryParse(map['lastRestoreAt']?.toString() ?? ''),
      lastAttemptAt: DateTime.tryParse(map['lastAttemptAt']?.toString() ?? ''),
      lastError: map['lastError']?.toString(),
    );
  }
}

class SyncQueueItem {
  final String idempotencyKey;
  final String collection;
  final String documentId;
  final SyncQueueOperation operation;
  final Map<String, dynamic> payload;
  final int attemptCount;
  final String? lastError;
  final DateTime? nextRetryAt;
  final DateTime createdAt;

  SyncQueueItem({
    required this.idempotencyKey,
    required this.collection,
    required this.documentId,
    required this.operation,
    required this.payload,
    this.attemptCount = 0,
    this.lastError,
    this.nextRetryAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get canRetry {
    final retryAt = nextRetryAt;
    return retryAt == null || !DateTime.now().isBefore(retryAt);
  }

  SyncQueueItem markFailure(Object error) {
    final attempts = attemptCount + 1;
    final delaySeconds = (2 << attempts).clamp(4, 300);
    return copyWith(
      attemptCount: attempts,
      lastError: error.toString(),
      nextRetryAt: DateTime.now().add(Duration(seconds: delaySeconds)),
    );
  }

  SyncQueueItem copyWith({
    int? attemptCount,
    String? lastError,
    DateTime? nextRetryAt,
  }) {
    return SyncQueueItem(
      idempotencyKey: idempotencyKey,
      collection: collection,
      documentId: documentId,
      operation: operation,
      payload: payload,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idempotencyKey': idempotencyKey,
      'collection': collection,
      'documentId': documentId,
      'operation': operation.name,
      'payload': payload,
      'attemptCount': attemptCount,
      'lastError': lastError,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      collection: map['collection']?.toString() ?? '',
      documentId: map['documentId']?.toString() ?? '',
      operation: SyncQueueOperation.values.firstWhere(
        (operation) => operation.name == map['operation'],
        orElse: () => SyncQueueOperation.upsert,
      ),
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
      attemptCount: (map['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: map['lastError']?.toString(),
      nextRetryAt: DateTime.tryParse(map['nextRetryAt']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

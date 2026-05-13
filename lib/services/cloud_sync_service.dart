import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:study_hub/models/certificate.dart';
import 'package:study_hub/models/cloud_sync.dart';
import 'package:study_hub/models/study_event.dart';
import 'package:study_hub/models/study_goal.dart';
import 'package:study_hub/models/study_log.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/sync_merge_resolver.dart';

class CloudCollections {
  static const records = 'records';
  static const notes = 'notes';
  static const legacyAchievements = 'achievements';

  static const studyLogs = 'studyLogs';
  static const studyEvents = 'studyEvents';
  static const goals = 'goals';
  static const certificates = 'certificates';
  static const achievements = certificates;
  static const settings = 'settings';
  static const localConfig = 'localConfig';
  static const syncMeta = 'syncMeta';
}

class CloudConfigDocs {
  static const app = 'app';
  static const studySchema = 'studySchema';
  static const categories = 'categories';
  static const timerStats = 'timerStats';
  static const state = 'state';
}

class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final StorageService _storage = StorageService();

  static const Duration syncRunTimeout = Duration(seconds: 35);
  static const Duration collectionTimeout = Duration(seconds: 10);
  static const Duration writeTimeout = Duration(seconds: 12);

  CloudSyncState _state = const CloudSyncState();
  bool _isWorking = false;
  bool _isFlushingQueue = false;
  int _runToken = 0;

  CloudSyncState get state => _state;
  bool get canUseFirebase => Firebase.apps.isNotEmpty;

  User? get _currentUser {
    if (!canUseFirebase) return null;
    return FirebaseAuth.instance.currentUser;
  }

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final user = _currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  CollectionReference<Map<String, dynamic>>? _userCollection(
    String collection,
  ) {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc.collection(collection);
  }

  Future<void> loadState() async {
    _state = await _storage.getCloudSyncState();
    _state = _state.copyWith(pendingCount: await pendingCount());
    notifyListeners();
  }

  Future<int> pendingCount() async => (await _storage.getSyncQueue()).length;

  Future<void> enqueueStudyLog(StudyLog log) async {
    await _enqueue(
      collection: CloudCollections.studyLogs,
      documentId: log.id,
      operation: log.deletedAt == null
          ? SyncQueueOperation.upsert
          : SyncQueueOperation.delete,
      payload: log.toMap(),
    );
  }

  Future<void> enqueueStudyEvent(StudyEvent event) async {
    await _enqueue(
      collection: CloudCollections.studyEvents,
      documentId: event.id,
      operation: event.deletedAt == null
          ? SyncQueueOperation.upsert
          : SyncQueueOperation.delete,
      payload: event.toMap(),
    );
  }

  Future<void> enqueueGoal(StudyGoal goal) async {
    await _enqueue(
      collection: CloudCollections.goals,
      documentId: goal.id,
      operation: goal.deletedAt == null
          ? SyncQueueOperation.upsert
          : SyncQueueOperation.delete,
      payload: goal.toMap(),
    );
  }

  Future<void> enqueueAchievement(Certificate certificate) async {
    await enqueueCertificate(certificate);
  }

  Future<void> enqueueCertificate(Certificate certificate) async {
    await _enqueue(
      collection: CloudCollections.certificates,
      documentId: certificate.id,
      operation: SyncQueueOperation.upsert,
      payload: certificate.toMap(),
    );
  }

  Future<void> enqueueAchievementDelete(Certificate certificate) async {
    await enqueueDelete(
      collection: CloudCollections.certificates,
      documentId: certificate.id,
      payload: certificate.toMap(),
    );
  }

  Future<void> enqueueSettings(Map<String, dynamic> settings) async {
    await _enqueue(
      collection: CloudCollections.settings,
      documentId: CloudConfigDocs.app,
      operation: SyncQueueOperation.upsert,
      payload: {...settings, 'updatedAt': DateTime.now().toIso8601String()},
    );
  }

  Future<void> enqueueLocalConfig() async {
    final config = await _storage.getLocalConfigSnapshot();
    await _enqueue(
      collection: CloudCollections.localConfig,
      documentId: CloudConfigDocs.studySchema,
      operation: SyncQueueOperation.upsert,
      payload: {
        'studySchema': config['studySchema'],
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    await _enqueue(
      collection: CloudCollections.localConfig,
      documentId: CloudConfigDocs.categories,
      operation: SyncQueueOperation.upsert,
      payload: {
        'categories': config['categories'],
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    await _enqueue(
      collection: CloudCollections.localConfig,
      documentId: CloudConfigDocs.timerStats,
      operation: SyncQueueOperation.upsert,
      payload: {
        'timerStats': config['timerStats'],
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> enqueueDelete({
    required String collection,
    required String documentId,
    Map<String, dynamic> payload = const {},
  }) async {
    final deletedAt = DateTime.now().toIso8601String();
    await _enqueue(
      collection: _normalizeCollection(collection),
      documentId: documentId,
      operation: SyncQueueOperation.delete,
      payload: {
        ...payload,
        'id': documentId,
        'deletedAt': deletedAt,
        'updatedAt': deletedAt,
      },
    );
  }

  Future<void> _enqueue({
    required String collection,
    required String documentId,
    required SyncQueueOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    final normalizedCollection = _normalizeCollection(collection);
    await _storage.enqueueSync(
      SyncQueueItem(
        idempotencyKey: '$normalizedCollection/$documentId',
        collection: normalizedCollection,
        documentId: documentId,
        operation: operation,
        payload: _payloadForQueue(normalizedCollection, payload),
      ),
    );
    await _setState(
      _state.copyWith(pendingCount: await pendingCount(), clearError: true),
    );
  }

  Future<void> restoreAndMergeLocalData() => synchronize(restoreFirst: true);

  Future<void> synchronize({
    bool restoreFirst = true,
    Future<void> Function(String collection)? onCollectionRestored,
  }) async {
    if (_isWorking) {
      debugPrint('[CloudSyncService] sync skipped: already running');
      return;
    }
    if (_currentUser == null) {
      await _setState(
        _state.copyWith(
          phase: CloudSyncPhase.idle,
          pendingCount: await pendingCount(),
        ),
      );
      debugPrint('[CloudSyncService] sync skipped: no authenticated user');
      return;
    }
    if (!await _isOnlineNow()) {
      await _setState(
        _state.copyWith(
          phase: CloudSyncPhase.offline,
          pendingCount: await pendingCount(),
          lastAttemptAt: DateTime.now(),
          lastError: 'Offline mode active',
        ),
      );
      debugPrint('[CloudSyncService] sync skipped: offline');
      return;
    }

    _isWorking = true;
    final runToken = ++_runToken;
    await _setState(
      _state.copyWith(
        phase: CloudSyncPhase.syncing,
        pendingCount: await pendingCount(),
        lastAttemptAt: DateTime.now(),
        clearError: true,
      ),
    );

    try {
      debugPrint('[CloudSyncService] sync start restoreFirst=$restoreFirst');
      await _runSynchronize(
        runToken: runToken,
        restoreFirst: restoreFirst,
        onCollectionRestored: onCollectionRestored,
      ).timeout(syncRunTimeout);
    } on TimeoutException catch (e) {
      debugPrint('[CloudSyncService] sync timeout after $syncRunTimeout');
      if (_runToken == runToken) {
        _runToken++;
        await _setState(
          _state.copyWith(
            phase: CloudSyncPhase.timeout,
            pendingCount: await pendingCount(),
            lastError: e.toString(),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[CloudSyncService] synchronize failed: $e\n$stackTrace');
      if (_runToken == runToken) {
        await _setState(
          _state.copyWith(
            phase: CloudSyncPhase.error,
            pendingCount: await pendingCount(),
            lastError: e.toString(),
          ),
        );
      }
    } finally {
      _isWorking = false;
    }
  }

  Future<void> _runSynchronize({
    required int runToken,
    required bool restoreFirst,
    Future<void> Function(String collection)? onCollectionRestored,
  }) async {
    await _ensureUserProfile();
    if (_runToken != runToken) return;
    var restoredAny = false;
    if (restoreFirst) {
      restoredAny = await _restoreAll(
        runToken: runToken,
        onCollectionRestored: onCollectionRestored,
      );
      if (_runToken != runToken) return;
      await _enqueueLocalSnapshot();
    }
    if (_runToken != runToken) return;
    await flushQueue();
    if (_runToken != runToken) return;

    final syncedAt = DateTime.now();
    await _writeSyncMeta(syncedAt);
    if (_runToken != runToken) return;
    await _setState(
      _state.copyWith(
        phase: (await pendingCount()) > 0
            ? CloudSyncPhase.pending
            : CloudSyncPhase.restored,
        pendingCount: await pendingCount(),
        lastSyncedAt: syncedAt,
        lastRestoreAt: restoredAny ? syncedAt : _state.lastRestoreAt,
        clearError: true,
      ),
    );
    debugPrint('[CloudSyncService] sync complete');
  }

  Future<void> flushQueue() async {
    if (_currentUser == null) return;
    if (_isFlushingQueue) return;
    _isFlushingQueue = true;
    final queue = await _storage.getSyncQueue();
    try {
      for (final item in queue) {
        final normalizedCollection = _normalizeCollection(item.collection);
        if (!item.canRetry) continue;
        final collection = _userCollection(normalizedCollection);
        if (collection == null) continue;

        try {
          final payload = await _payloadForWrite(item);
          final doc = collection.doc(item.documentId);
          await doc
              .set(_firestoreSafeMap(payload), SetOptions(merge: true))
              .timeout(writeTimeout);
          await _storage.removeQueuedSync(item.idempotencyKey);
        } on TimeoutException catch (e) {
          debugPrint('[CloudSyncService] queue item timeout: $e');
          await _storage.replaceQueuedSync(item.markFailure(e));
        } catch (e) {
          debugPrint('[CloudSyncService] queue item failed: $e');
          await _storage.replaceQueuedSync(item.markFailure(e));
        }
      }
      await _setState(_state.copyWith(pendingCount: await pendingCount()));
    } catch (e) {
      debugPrint('[CloudSyncService] queue flush failed: $e');
    } finally {
      _isFlushingQueue = false;
    }
  }

  Future<void> _ensureUserProfile() async {
    final user = _currentUser;
    final userDoc = _userDoc;
    if (user == null || userDoc == null) return;
    await userDoc
        .set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'updatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true))
        .timeout(writeTimeout);
  }

  Future<bool> _restoreAll({
    required int runToken,
    Future<void> Function(String collection)? onCollectionRestored,
  }) async {
    var restoredAny = false;
    Future<void> restore(
      String collection,
      Future<void> Function() body,
    ) async {
      final restored = await _restoreSafely(
        collection: collection,
        runToken: runToken,
        body: body,
      );
      if (_runToken == runToken && restored) {
        restoredAny = true;
        await onCollectionRestored?.call(collection);
      }
    }

    await restore(CloudCollections.records, _restoreLegacyRecords);
    await restore(CloudCollections.studyLogs, _restoreStudyLogs);
    await restore(CloudCollections.studyEvents, _restoreStudyEvents);
    await restore(CloudCollections.goals, _restoreGoals);
    await restore(
      CloudCollections.legacyAchievements,
      _restoreLegacyAchievements,
    );
    await restore(CloudCollections.certificates, _restoreCertificates);
    await restore(CloudCollections.settings, _restoreSettings);
    await restore(CloudCollections.localConfig, _restoreLocalConfig);
    return restoredAny;
  }

  Future<bool> _restoreSafely({
    required String collection,
    required int runToken,
    required Future<void> Function() body,
  }) async {
    if (_runToken != runToken) return false;
    try {
      debugPrint('[CloudSyncService] restore start: $collection');
      await body().timeout(collectionTimeout);
      if (_runToken != runToken) {
        return false;
      }
      debugPrint('[CloudSyncService] restore complete: $collection');
      return true;
    } on TimeoutException catch (e) {
      debugPrint('[CloudSyncService] restore timeout $collection: $e');
      await _setState(
        _state.copyWith(
          phase: CloudSyncPhase.timeout,
          pendingCount: await pendingCount(),
          lastError: '$collection restore timeout',
        ),
      );
      return false;
    } catch (e, stackTrace) {
      debugPrint(
        '[CloudSyncService] restore failed $collection: $e\n$stackTrace',
      );
      await _setState(
        _state.copyWith(
          phase: CloudSyncPhase.error,
          pendingCount: await pendingCount(),
          lastError: '$collection restore failed: $e',
        ),
      );
      return false;
    }
  }

  Future<void> _restoreLegacyRecords() async {
    final docs = await _getCollectionDocs(CloudCollections.records);
    if (docs.isEmpty) return;

    final logsById = {
      for (final log in await _storage.getStudyLogs()) log.id: log,
    };
    final eventsById = {
      for (final event in await _storage.getStudyEvents()) event.id: event,
    };

    for (final doc in docs) {
      final data = doc.data();
      final payload = data['data'];
      if (payload is! Map) continue;
      final payloadMap = Map<String, dynamic>.from(payload);
      final type = data['type']?.toString();

      if (type == 'studyLog') {
        final remote = StudyLog.fromMap(payloadMap);
        final local = logsById[remote.id];
        logsById[remote.id] = local == null
            ? remote
            : SyncMergeResolver.newest(
                local: local,
                remote: remote,
                localUpdatedAt: local.updatedAt,
                remoteUpdatedAt: remote.updatedAt,
              );
      } else if (type == 'studyEvent') {
        final remote = StudyEvent.fromMap(payloadMap);
        final local = eventsById[remote.id];
        eventsById[remote.id] = local == null
            ? remote
            : SyncMergeResolver.newest(
                local: local,
                remote: remote,
                localUpdatedAt: local.updatedAt,
                remoteUpdatedAt: remote.updatedAt,
              );
      }
    }

    await _storage.saveStudyLogs(logsById.values.toList());
    await _storage.saveStudyEvents(eventsById.values.toList());
  }

  Future<void> _restoreStudyLogs() async {
    final docs = await _getCollectionDocs(CloudCollections.studyLogs);
    final byId = {for (final log in await _storage.getStudyLogs()) log.id: log};
    for (final doc in docs) {
      final remote = StudyLog.fromMap(doc.data());
      final local = byId[remote.id];
      if (remote.deletedAt != null) {
        if (local == null ||
            SyncMergeResolver.remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
              localDeletedAt: local.deletedAt,
              remoteDeletedAt: remote.deletedAt,
            )) {
          byId.remove(remote.id);
        }
        continue;
      }
      byId[remote.id] = local == null
          ? remote
          : SyncMergeResolver.newest(
              local: local,
              remote: remote,
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            );
    }
    await _storage.saveStudyLogs(byId.values.toList());
  }

  Future<void> _restoreStudyEvents() async {
    final docs = await _getCollectionDocs(CloudCollections.studyEvents);
    final byId = {
      for (final event in await _storage.getStudyEvents()) event.id: event,
    };
    for (final doc in docs) {
      final remote = StudyEvent.fromMap(doc.data());
      final local = byId[remote.id];
      if (remote.deletedAt != null) {
        if (local == null ||
            SyncMergeResolver.remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
              localDeletedAt: local.deletedAt,
              remoteDeletedAt: remote.deletedAt,
            )) {
          byId.remove(remote.id);
        }
        continue;
      }
      byId[remote.id] = local == null
          ? remote
          : SyncMergeResolver.newest(
              local: local,
              remote: remote,
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            );
    }
    await _storage.saveStudyEvents(byId.values.toList());
  }

  Future<void> _restoreGoals() async {
    final docs = await _getCollectionDocs(CloudCollections.goals);
    final byId = {
      for (final goal in await _storage.getStudyGoals()) goal.id: goal,
    };
    for (final doc in docs) {
      final remote = StudyGoal.fromMap(doc.data());
      final local = byId[remote.id];
      if (remote.deletedAt != null) {
        if (local == null ||
            SyncMergeResolver.remoteWins(
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
              localDeletedAt: local.deletedAt,
              remoteDeletedAt: remote.deletedAt,
            )) {
          byId.remove(remote.id);
        }
        continue;
      }
      byId[remote.id] = local == null
          ? remote
          : SyncMergeResolver.newest(
              local: local,
              remote: remote,
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            );
    }
    await _storage.saveStudyGoals(byId.values.toList());
  }

  Future<void> _restoreCertificates() async {
    final docs = await _getCollectionDocs(CloudCollections.certificates);
    final byId = {
      for (final certificate in await _storage.getCertificates())
        certificate.id: certificate,
    };
    for (final doc in docs) {
      final data = doc.data();
      final deletedAt = DateTime.tryParse(data['deletedAt']?.toString() ?? '');
      if (deletedAt != null) {
        final local = byId[doc.id];
        if (local == null || deletedAt.isAfter(local.updatedAt)) {
          byId.remove(doc.id);
        }
        continue;
      }

      final remote = Certificate.fromMap(data);
      final local = byId[remote.id];
      byId[remote.id] = _mergeCertificateMetadataOnly(local, remote);
    }
    await _storage.saveCertificates(byId.values.toList());
  }

  Future<void> _restoreLegacyAchievements() async {
    final docs = await _getCollectionDocs(CloudCollections.legacyAchievements);
    if (docs.isEmpty) return;

    final byId = {
      for (final certificate in await _storage.getCertificates())
        certificate.id: certificate,
    };
    for (final doc in docs) {
      final data = doc.data();
      if (data['deletedAt'] != null) {
        byId.remove(doc.id);
        continue;
      }
      final remote = Certificate.fromMap(data);
      final local = byId[remote.id];
      byId[remote.id] = _mergeCertificateMetadataOnly(local, remote);
    }
    await _storage.saveCertificates(byId.values.toList());
  }

  Certificate _mergeCertificateMetadataOnly(
    Certificate? local,
    Certificate remote,
  ) {
    if (local == null) return remote;
    final newest = SyncMergeResolver.newest(
      local: local,
      remote: remote,
      localUpdatedAt: local.updatedAt,
      remoteUpdatedAt: remote.updatedAt,
    );
    if (identical(newest, remote) &&
        remote.attachments.isEmpty &&
        local.attachments.isNotEmpty) {
      return remote.copyWith(attachments: local.attachments);
    }
    return newest;
  }

  Future<void> _restoreSettings() async {
    final doc = await _userCollection(
      CloudCollections.settings,
    )?.doc(CloudConfigDocs.app).get().timeout(collectionTimeout);
    final data = doc?.data();
    if (data == null || data['deletedAt'] != null) return;
    await _storage.applyCloudSettingsSnapshot(data);
  }

  Future<void> _restoreLocalConfig() async {
    final collection = _userCollection(CloudCollections.localConfig);
    if (collection == null) return;
    final schema =
        (await collection
                .doc(CloudConfigDocs.studySchema)
                .get()
                .timeout(collectionTimeout))
            .data();
    final categories =
        (await collection
                .doc(CloudConfigDocs.categories)
                .get()
                .timeout(collectionTimeout))
            .data();
    final timerStats =
        (await collection
                .doc(CloudConfigDocs.timerStats)
                .get()
                .timeout(collectionTimeout))
            .data();
    await _storage.applyLocalConfigSnapshot({
      if (schema?['studySchema'] != null) 'studySchema': schema!['studySchema'],
      if (categories?['categories'] != null)
        'categories': categories!['categories'],
      if (timerStats?['timerStats'] != null)
        'timerStats': timerStats!['timerStats'],
    });
  }

  Future<void> _enqueueLocalSnapshot() async {
    for (final log in await _storage.getStudyLogs()) {
      await enqueueStudyLog(log);
    }
    for (final event in await _storage.getStudyEvents()) {
      await enqueueStudyEvent(event);
    }
    for (final goal in await _storage.getStudyGoals()) {
      await enqueueGoal(goal);
    }
    for (final certificate in await _storage.getCertificates()) {
      await enqueueCertificate(certificate);
    }
    await enqueueSettings(await _storage.getCloudSettingsSnapshot());
    await enqueueLocalConfig();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _getCollectionDocs(
    String collection,
  ) async {
    final ref = _userCollection(collection);
    if (ref == null) return const [];
    try {
      final lastSyncedAt = _state.lastSyncedAt;
      if (lastSyncedAt != null) {
        return (await ref
                .where(
                  'updatedAt',
                  isGreaterThan: lastSyncedAt.toIso8601String(),
                )
                .get()
                .timeout(collectionTimeout))
            .docs;
      }
      return (await ref.get().timeout(collectionTimeout)).docs;
    } catch (e) {
      debugPrint('[CloudSyncService] incremental pull fallback: $e');
      return (await ref.get().timeout(collectionTimeout)).docs;
    }
  }

  Future<Map<String, dynamic>> _payloadForWrite(SyncQueueItem item) async {
    var payload = Map<String, dynamic>.from(item.payload);
    payload['id'] = item.documentId;
    payload['updatedAt'] =
        payload['updatedAt']?.toString() ?? DateTime.now().toIso8601String();

    if (item.operation == SyncQueueOperation.delete) {
      payload['deletedAt'] =
          payload['deletedAt']?.toString() ?? DateTime.now().toIso8601String();
      return payload;
    }

    return payload;
  }

  Map<String, dynamic> _payloadForQueue(
    String collection,
    Map<String, dynamic> payload,
  ) {
    if (collection != CloudCollections.certificates) return payload;
    return certificateMetadataOnlyPayload(payload);
  }

  @visibleForTesting
  static Map<String, dynamic> certificateMetadataOnlyPayload(
    Map<String, dynamic> payload,
  ) {
    return {
      ...payload,
      'attachments': const <Map<String, dynamic>>[],
      'attachmentSync': 'localOnly',
    };
  }

  Future<void> _writeSyncMeta(DateTime syncedAt) async {
    await _userCollection(CloudCollections.syncMeta)
        ?.doc(CloudConfigDocs.state)
        .set({
          'lastSyncedAt': syncedAt.toIso8601String(),
          'pendingCount': await pendingCount(),
          'updatedAt': syncedAt.toIso8601String(),
        }, SetOptions(merge: true))
        .timeout(writeTimeout);
  }

  Future<bool> _isOnlineNow() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.any((item) => item != ConnectivityResult.none);
    } catch (e) {
      debugPrint('[CloudSyncService] connectivity check failed: $e');
      return true;
    }
  }

  Future<void> _setState(CloudSyncState state) async {
    _state = state;
    await _storage.saveCloudSyncState(state);
    notifyListeners();
  }

  String _normalizeCollection(String collection) {
    return switch (collection) {
      CloudCollections.records => CloudCollections.studyLogs,
      CloudCollections.legacyAchievements => CloudCollections.certificates,
      _ => collection,
    };
  }

  Map<String, dynamic> _firestoreSafeMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _firestoreSafeValue(value)));
  }

  dynamic _firestoreSafeValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is List) return value.map(_firestoreSafeValue).toList();
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _firestoreSafeValue(nestedValue)),
      );
    }
    return value;
  }
}

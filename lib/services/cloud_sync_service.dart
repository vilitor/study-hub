import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const goals = 'goals';
  static const notes = 'notes';
  static const achievements = 'achievements';
  static const settings = 'settings';
}

class CloudRecordTypes {
  static const studyLog = 'studyLog';
  static const studyEvent = 'studyEvent';
}

class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final StorageService _storage = StorageService();
  bool _isFlushing = false;

  bool get canUseFirebase => Firebase.apps.isNotEmpty;

  User? get _currentUser {
    if (!canUseFirebase) return null;
    return FirebaseAuth.instance.currentUser;
  }

  CollectionReference<Map<String, dynamic>>? _userCollection(
    String collection,
  ) {
    final user = _currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection(collection);
  }

  Future<int> pendingCount() async => (await _storage.getSyncQueue()).length;

  Future<void> enqueueStudyLog(StudyLog log) async {
    await _enqueue(
      collection: CloudCollections.records,
      documentId: log.id,
      operation: log.deletedAt == null
          ? SyncQueueOperation.upsert
          : SyncQueueOperation.delete,
      payload: {
        'type': CloudRecordTypes.studyLog,
        'data': log.toMap(),
        'updatedAt': log.updatedAt.toIso8601String(),
        'deletedAt': log.deletedAt?.toIso8601String(),
      },
    );
    await enqueueNoteForLog(log);
  }

  Future<void> enqueueStudyEvent(StudyEvent event) async {
    await _enqueue(
      collection: CloudCollections.records,
      documentId: event.id,
      operation: event.deletedAt == null
          ? SyncQueueOperation.upsert
          : SyncQueueOperation.delete,
      payload: {
        'type': CloudRecordTypes.studyEvent,
        'data': event.toMap(),
        'updatedAt': event.updatedAt.toIso8601String(),
        'deletedAt': event.deletedAt?.toIso8601String(),
      },
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
    await _enqueue(
      collection: CloudCollections.achievements,
      documentId: certificate.id,
      operation: SyncQueueOperation.upsert,
      payload: certificate.toMap(),
    );
  }

  Future<void> enqueueAchievementDelete(Certificate certificate) async {
    await _enqueue(
      collection: CloudCollections.achievements,
      documentId: certificate.id,
      operation: SyncQueueOperation.delete,
      payload: certificate.toMap(),
    );
  }

  Future<void> enqueueNoteForLog(StudyLog log) async {
    final note = log.localNote;
    if (note == null || note.isEmpty) return;
    await _enqueue(
      collection: CloudCollections.notes,
      documentId: log.id,
      operation: log.deletedAt == null
          ? SyncQueueOperation.upsert
          : SyncQueueOperation.delete,
      payload: {
        'recordId': log.id,
        'subject': note.subject,
        'contentName': note.contentName,
        'summary': note.summary,
        'updatedAt': log.updatedAt.toIso8601String(),
      },
    );
  }

  Future<void> enqueueSettings(Map<String, dynamic> settings) async {
    await _enqueue(
      collection: CloudCollections.settings,
      documentId: 'app',
      operation: SyncQueueOperation.upsert,
      payload: {...settings, 'updatedAt': DateTime.now().toIso8601String()},
    );
  }

  Future<void> enqueueDelete({
    required String collection,
    required String documentId,
  }) async {
    await _enqueue(
      collection: collection,
      documentId: documentId,
      operation: SyncQueueOperation.delete,
      payload: {'deletedAt': DateTime.now().toIso8601String()},
    );
  }

  Future<void> _enqueue({
    required String collection,
    required String documentId,
    required SyncQueueOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    await _storage.enqueueSync(
      SyncQueueItem(
        idempotencyKey: '$collection/$documentId/${operation.name}',
        collection: collection,
        documentId: documentId,
        operation: operation,
        payload: payload,
      ),
    );
  }

  Future<void> flushQueue() async {
    if (_isFlushing || _currentUser == null) return;
    _isFlushing = true;
    try {
      final queue = await _storage.getSyncQueue();
      for (final item in queue) {
        if (!item.canRetry) continue;
        final collection = _userCollection(item.collection);
        if (collection == null) return;

        try {
          final doc = collection.doc(item.documentId);
          if (item.operation == SyncQueueOperation.delete) {
            await doc.delete();
          } else {
            await doc.set(
              _firestoreSafeMap(item.payload),
              SetOptions(merge: true),
            );
          }
          await _storage.removeQueuedSync(item.idempotencyKey);
        } catch (e) {
          debugPrint('[CloudSyncService] Sync failed: $e');
          await _storage.replaceQueuedSync(item.markFailure(e));
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> restoreAndMergeLocalData() async {
    if (_currentUser == null) return;
    await _restoreRecords();
    await _restoreGoals();
    await _restoreAchievements();
    await _enqueueLocalSnapshot();
    await flushQueue();
  }

  Future<void> _restoreRecords() async {
    final collection = _userCollection(CloudCollections.records);
    if (collection == null) return;
    final snapshot = await collection.get();
    final localLogs = await _storage.getStudyLogs();
    final localEvents = await _storage.getStudyEvents();
    final logsById = {for (final log in localLogs) log.id: log};
    final eventsById = {for (final event in localEvents) event.id: event};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type']?.toString();
      final payload = data['data'];
      if (payload is! Map) continue;
      final payloadMap = Map<String, dynamic>.from(payload);

      if (type == CloudRecordTypes.studyLog) {
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
      } else if (type == CloudRecordTypes.studyEvent) {
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

  Future<void> _restoreGoals() async {
    final collection = _userCollection(CloudCollections.goals);
    if (collection == null) return;
    final snapshot = await collection.get();
    final goalsById = {
      for (final goal in await _storage.getStudyGoals()) goal.id: goal,
    };

    for (final doc in snapshot.docs) {
      final remote = StudyGoal.fromMap(doc.data());
      final local = goalsById[remote.id];
      goalsById[remote.id] = local == null
          ? remote
          : SyncMergeResolver.newest(
              local: local,
              remote: remote,
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            );
    }
    await _storage.saveStudyGoals(goalsById.values.toList());
  }

  Future<void> _restoreAchievements() async {
    final collection = _userCollection(CloudCollections.achievements);
    if (collection == null) return;
    final snapshot = await collection.get();
    final certificatesById = {
      for (final certificate in await _storage.getCertificates())
        certificate.id: certificate,
    };

    for (final doc in snapshot.docs) {
      final remote = Certificate.fromMap(doc.data());
      final local = certificatesById[remote.id];
      certificatesById[remote.id] = local == null
          ? remote
          : SyncMergeResolver.newest(
              local: local,
              remote: remote,
              localUpdatedAt: local.updatedAt,
              remoteUpdatedAt: remote.updatedAt,
            );
    }
    await _storage.saveCertificates(certificatesById.values.toList());
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
      await enqueueAchievement(certificate);
    }
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

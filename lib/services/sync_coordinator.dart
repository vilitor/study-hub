import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_hub/providers/certificate_provider.dart';
import 'package:study_hub/providers/goal_provider.dart';
import 'package:study_hub/providers/auth_session_provider.dart';
import 'package:study_hub/providers/local_study_schema_provider.dart';
import 'package:study_hub/providers/settings_provider.dart';
import 'package:study_hub/providers/study_event_provider.dart';
import 'package:study_hub/providers/study_log_provider.dart';
import 'package:study_hub/services/cloud_sync_service.dart';

class SyncCoordinator extends StatefulWidget {
  final Widget child;

  const SyncCoordinator({super.key, required this.child});

  @override
  State<SyncCoordinator> createState() => _SyncCoordinatorState();
}

class _SyncCoordinatorState extends State<SyncCoordinator>
    with WidgetsBindingObserver {
  StreamSubscription<dynamic>? _connectivitySub;
  String? _lastSyncedUid;
  String? _lastAuthProfileKey;
  DateTime? _lastSyncRequestAt;
  static const _retryCooldown = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(CloudSyncService.instance.loadState());
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (_isOnline(result)) {
        _requestSync(reason: 'connectivity-restored');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestSync(reason: 'app-open');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestSync(reason: 'app-resumed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSessionProvider>();
    if (!auth.isLoading) {
      final profileKey = auth.isSignedIn
          ? '${auth.uid}|${auth.email}|${auth.displayName}|${auth.photoUrl}'
          : 'signed-out';
      if (profileKey != _lastAuthProfileKey) {
        _lastAuthProfileKey = profileKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            context.read<SettingsProvider>().syncGoogleProfileFromAuth(
              email: auth.isSignedIn ? auth.email : null,
              name: auth.isSignedIn ? auth.displayName : null,
              photoUrl: auth.isSignedIn ? auth.photoUrl : null,
            ),
          );
        });
      }
    }
    if (auth.isSignedIn && auth.uid != null && auth.uid != _lastSyncedUid) {
      _lastSyncedUid = auth.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestSync(reason: 'auth-user-ready', force: true);
      });
    }
    return widget.child;
  }

  bool _isOnline(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }
    if (result is ConnectivityResult) return result != ConnectivityResult.none;
    return true;
  }

  void _requestSync({required String reason, bool force = false}) {
    if (!mounted) return;
    final auth = context.read<AuthSessionProvider>();
    if (!auth.isSignedIn) {
      return;
    }

    final now = DateTime.now();
    final last = _lastSyncRequestAt;
    if (!force && last != null && now.difference(last) < _retryCooldown) {
      debugPrint('[SyncCoordinator] sync skipped by cooldown: $reason');
      return;
    }
    _lastSyncRequestAt = now;
    debugPrint('[SyncCoordinator] sync requested: $reason');
    unawaited(_syncAndReload());
  }

  Future<void> _syncAndReload() async {
    await CloudSyncService.instance.synchronize(
      restoreFirst: true,
      onCollectionRestored: _reloadForCollection,
    );
    if (!mounted) return;
    await context.read<AuthSessionProvider>().refreshSyncStatus();
  }

  Future<void> _reloadForCollection(String collection) async {
    if (!mounted) return;
    debugPrint('[SyncCoordinator] provider reload: $collection');
    switch (collection) {
      case CloudCollections.records:
        final logs = context.read<StudyLogProvider>();
        final events = context.read<StudyEventProvider>();
        await logs.loadLogs();
        await events.loadEvents();
        break;
      case CloudCollections.studyLogs:
        final logs = context.read<StudyLogProvider>();
        await logs.loadLogs();
        break;
      case CloudCollections.studyEvents:
        final events = context.read<StudyEventProvider>();
        await events.loadEvents();
        break;
      case CloudCollections.goals:
        final goals = context.read<GoalProvider>();
        await goals.reloadGoals();
        break;
      case CloudCollections.legacyAchievements:
      case CloudCollections.certificates:
        final certificates = context.read<CertificateProvider>();
        await certificates.loadCertificates();
        break;
      case CloudCollections.settings:
        final settings = context.read<SettingsProvider>();
        await settings.loadSettings();
        break;
      case CloudCollections.localConfig:
        final schema = context.read<LocalStudySchemaProvider>();
        final settings = context.read<SettingsProvider>();
        await schema.loadFields();
        await settings.loadSettings();
        break;
    }
  }
}

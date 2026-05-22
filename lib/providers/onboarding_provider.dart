import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_hub/models/onboarding_state.dart';
import 'package:study_hub/models/study_profile.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/onboarding_migration_service.dart';
import 'package:study_hub/services/starter_subject_seeding_service.dart';
import 'package:study_hub/services/storage_service.dart';
import 'package:study_hub/services/study_profile_catalog.dart';

class OnboardingProvider extends ChangeNotifier {
  final StorageService _storage;
  final OnboardingMigrationService _migration;
  final StarterSubjectSeedingService _seeding;
  final CloudSyncService _cloudSync;
  final Duration _seedingTimeout;

  OnboardingProvider({
    StorageService? storage,
    OnboardingMigrationService? migration,
    StarterSubjectSeedingService? seeding,
    CloudSyncService? cloudSync,
    Duration seedingTimeout = const Duration(seconds: 8),
    bool autoLoad = true,
  }) : _storage = storage ?? StorageService(),
       _migration = migration ?? OnboardingMigrationService(storage: storage),
       _seeding = seeding ?? StarterSubjectSeedingService(storage: storage),
       _cloudSync = cloudSync ?? CloudSyncService.instance,
       _seedingTimeout = seedingTimeout {
    if (autoLoad) unawaited(load());
  }

  OnboardingState _state = const OnboardingState();
  bool _isLoading = true;
  String? _lastError;
  String? _loadedNamespace;

  OnboardingState get state => _state;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get shouldShowOnboarding => _state.shouldShowOnboarding;
  String? get loadedNamespace => _loadedNamespace;
  bool get isLoadedForActiveNamespace =>
      !_isLoading && _loadedNamespace == _storage.activeNamespace;

  Future<void> load() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      var next = await _storage.getOnboardingState();
      debugPrint('[ONBOARDING] local state loaded');
      if (!next.legacyMigrationCompleted && !next.onboardingCompleted) {
        final snapshot = await _migration.inspect();
        if (snapshot.isLegacy) {
          next = next.copyWith(
            legacyMigrationCompleted: true,
            legacyMigrationCompletedAt: DateTime.now(),
          );
          await _storage.saveOnboardingState(next);
          await _queueSettings();
        }
      }
      _state = next;
      _loadedNamespace = _storage.activeNamespace;
      final classification = _state.legacyMigrationCompleted
          ? 'legacy'
          : _state.onboardingCompleted
          ? 'returning'
          : 'new';
      debugPrint('[ONBOARDING] classification completed $classification');
    } catch (e) {
      _lastError = 'Não foi possível carregar o onboarding.';
      debugPrint('[OnboardingProvider] load failed: $e');
      _state = const OnboardingState();
      _loadedNamespace = _storage.activeNamespace;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding({
    required StudyProfile profile,
    StudyFocus? focus,
  }) async {
    _lastError = null;
    debugPrint('[ONBOARDING] profile selected ${profile.id}');
    final now = DateTime.now();
    var next = _state.copyWith(
      onboardingCompleted: true,
      onboardingVersion: StudyProfileCatalog.currentOnboardingVersion,
      onboardingCompletedAt: now,
      profilePersonalizationCompleted: true,
      profilePersonalizationCompletedAt: now,
      selectedStudyProfileId: profile.id,
      selectedStudyProfileLabel: profile.label,
      selectedStudyFocusId: focus?.id,
      selectedStudyFocusLabel: focus?.label,
      clearFocus: focus == null,
    );
    debugPrint('[ONBOARDING] saving state');
    await _storage.saveOnboardingState(next);
    try {
      next = await _seeding.seedIfNeeded(next).timeout(_seedingTimeout);
    } catch (e) {
      _lastError =
          'Não foi possível preparar as matérias iniciais. Você pode continuar e editar tudo depois.';
      debugPrint('[ONBOARDING] seeding subjects error: $e');
    }
    _state = next;
    _loadedNamespace = _storage.activeNamespace;
    try {
      await _queueSettings();
    } catch (e) {
      debugPrint('[ONBOARDING] settings sync queue failed: $e');
    }
    debugPrint('[ONBOARDING] navigation allowed');
    notifyListeners();
  }

  Future<void> skipOnboarding() async {
    _lastError = null;
    final now = DateTime.now();
    final next = _state.copyWith(
      onboardingCompleted: true,
      onboardingVersion: StudyProfileCatalog.currentOnboardingVersion,
      onboardingCompletedAt: now,
      profilePersonalizationCompleted: false,
    );
    await _storage.saveOnboardingState(next);
    _state = next;
    _loadedNamespace = _storage.activeNamespace;
    try {
      await _queueSettings();
    } catch (e) {
      debugPrint('[ONBOARDING] settings sync queue failed: $e');
    }
    debugPrint('[ONBOARDING] navigation allowed');
    notifyListeners();
  }

  Future<void> setContextualGuideCompleted(bool completed) async {
    final next = _state.copyWith(contextualGuideCompleted: completed);
    await _storage.saveOnboardingState(next);
    _state = next;
    await _queueSettings();
    notifyListeners();
  }

  Future<void> replayContextualGuide() => setContextualGuideCompleted(false);

  Future<void> _queueSettings() async {
    await _cloudSync.enqueueSettings(await _storage.getCloudSettingsSnapshot());
    unawaited(_cloudSync.flushQueue());
  }
}

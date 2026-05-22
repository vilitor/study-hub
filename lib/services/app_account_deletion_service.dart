import 'package:flutter/foundation.dart';
import 'package:study_hub/repositories/auth_repository.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/storage_service.dart';

class AppAccountDeletionService {
  final StorageService _storage;
  final CloudSyncService _cloudSync;
  final AuthRepository _authRepository;

  AppAccountDeletionService({
    StorageService? storage,
    CloudSyncService? cloudSync,
    AuthRepository? authRepository,
  }) : _storage = storage ?? StorageService(),
       _cloudSync = cloudSync ?? CloudSyncService.instance,
       _authRepository = authRepository ?? AuthRepository();

  Future<void> deleteAppAccount({required bool isGuest, String? uid}) async {
    debugPrint('[DELETE_ACCOUNT] started');
    try {
      debugPrint('[DELETE_ACCOUNT] stopping sync');
      _cloudSync.resetRunContext();
      if (!isGuest) {
        debugPrint('[DELETE_ACCOUNT] deleting Firestore data');
        await _cloudSync.deleteCurrentUserData(uid: uid);
        if (uid != null && uid.isNotEmpty) {
          await _storage.useUidNamespace(uid);
        }
      } else {
        debugPrint('[DELETE_ACCOUNT] clearing guest app data');
        await _storage.useGuestNamespace();
      }

      debugPrint('[DELETE_ACCOUNT] clearing local namespace');
      debugPrint('[DELETE_ACCOUNT] clearing sync queue');
      await _storage.clearActiveAccountData();
      await _cloudSync.resetLocalState();

      debugPrint('[DELETE_ACCOUNT] signing out');
      try {
        if (isGuest) {
          await _authRepository.logout();
        } else {
          debugPrint('[DELETE_ACCOUNT] disconnecting Google app session');
          await _authRepository.disconnect();
        }
      } catch (e) {
        debugPrint('[DELETE_ACCOUNT] sign out warning: $e');
        try {
          await _authRepository.logout();
        } catch (fallbackError) {
          debugPrint(
            '[DELETE_ACCOUNT] fallback sign out warning: $fallbackError',
          );
        }
      }
      debugPrint('[DELETE_ACCOUNT] completed');
    } catch (e) {
      debugPrint('[DELETE_ACCOUNT] error: $e');
      rethrow;
    }
  }
}

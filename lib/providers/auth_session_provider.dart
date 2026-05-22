import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_hub/models/auth_session.dart';
import 'package:study_hub/repositories/auth_repository.dart';
import 'package:study_hub/services/cloud_sync_service.dart';
import 'package:study_hub/services/storage_service.dart';

class AuthSessionProvider extends ChangeNotifier {
  AuthSessionProvider({
    AuthRepository? authRepository,
    Duration sessionTimeout = const Duration(seconds: 45),
    bool autoLoad = true,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _sessionTimeout = sessionTimeout {
    _startFirebaseUserListener();
    if (autoLoad) unawaited(loadSession());
  }

  static const _entryChoiceKey = 'auth_entry_choice';
  static const _entryGuest = 'guest';
  static const _entryGoogle = 'google';
  final AuthRepository _authRepository;
  final StorageService _storage = StorageService();
  final CloudSyncService _cloudSync = CloudSyncService.instance;
  final Duration _sessionTimeout;

  AuthSessionStatus _status = AuthSessionStatus.signedOut;
  AuthDiagnostic? _lastDiagnostic;
  String? _uid;
  String? _email;
  String? _displayName;
  String? _photoUrl;
  int _pendingSyncCount = 0;
  int _sessionRevision = 0;
  bool _isLoading = true;
  bool _hasEntryChoice = false;
  StreamSubscription<User?>? _firebaseUserSub;

  AuthSessionStatus get status => _status;
  AuthDiagnostic? get lastDiagnostic => _lastDiagnostic;
  String? get uid => _uid;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get photoUrl => _photoUrl;
  int get pendingSyncCount => _pendingSyncCount;
  int get sessionRevision => _sessionRevision;
  String get accountNamespace =>
      isSignedIn && _uid != null ? 'uid:$_uid' : StorageService.guestNamespace;
  bool get isLoading => _isLoading;
  bool get hasEntryChoice => _hasEntryChoice;
  bool get isGuest => _status == AuthSessionStatus.guest;
  bool get isSignedIn => _status == AuthSessionStatus.signedIn;

  @override
  void dispose() {
    _firebaseUserSub?.cancel();
    super.dispose();
  }

  Future<void> loadSession() async {
    debugPrint('[AuthSessionProvider] loadSession start');
    _startFirebaseUserListener();
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final entryChoice = prefs.getString(_entryChoiceKey);
      _hasEntryChoice = entryChoice != null;

      final user = Firebase.apps.isEmpty
          ? null
          : FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('[AUTH] uid detected ${_safeId(user.uid)}');
        debugPrint(
          '[ONBOARDING] auth user changed null -> ${_safeId(user.uid)}',
        );
        await _applyAuthenticatedUser(user: user, persist: true);
        debugPrint(
          '[AuthSessionProvider] Firebase user restored: ${_safeId(user.uid)}',
        );
      } else if (entryChoice == _entryGuest) {
        await _switchToGuestNamespace(
          migrateLegacyUnscoped: true,
          forceRevision: true,
        );
        _status = AuthSessionStatus.guest;
        _clearUser();
        debugPrint('[GUEST] local state loaded');
        debugPrint('[AuthSessionProvider] Guest session restored');
      } else {
        await _switchToGuestNamespace(forceRevision: true);
        _status = AuthSessionStatus.signedOut;
        _clearUser();
        debugPrint('[AuthSessionProvider] No local auth session');
      }
      _pendingSyncCount = await _cloudSync.pendingCount();
    } catch (e) {
      debugPrint('[AUTH] session load failed: $e');
      _status = AuthSessionStatus.signedOut;
      _clearUser();
      await _switchToGuestNamespace(forceRevision: true);
    } finally {
      _isLoading = false;
      debugPrint('[AUTH] loading cleared');
      debugPrint('[AuthSessionProvider] loadSession complete: ${_status.name}');
      notifyListeners();
    }
  }

  Future<void> continueAsGuest() async {
    debugPrint('[GUEST] entry started');
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _sessionTimeout,
      );
      await prefs.setString(_entryChoiceKey, _entryGuest);
      _hasEntryChoice = true;
      _status = AuthSessionStatus.guest;
      _lastDiagnostic = null;
      _clearUser();
      await _switchToGuestNamespace(
        migrateLegacyUnscoped: true,
        forceRevision: true,
      );
      _pendingSyncCount = await _cloudSync.pendingCount();
      debugPrint('[GUEST] local state loaded');
      debugPrint('[GUEST] route selected');
    } catch (e) {
      _status = AuthSessionStatus.authError;
      _lastDiagnostic = AuthDiagnostic(
        reason: AuthFailureReason.unknown,
        message: 'Não foi possível iniciar o modo visitante.',
        rawError: e,
      );
      debugPrint('[GUEST] entry failed: $e');
    } finally {
      _isLoading = false;
      debugPrint('[AUTH] loading cleared');
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    debugPrint('[AUTH] login started');
    _status = AuthSessionStatus.signingIn;
    _isLoading = true;
    _lastDiagnostic = null;
    notifyListeners();

    try {
      final result = await _authRepository.login().timeout(_sessionTimeout);
      if (!result.isSuccess || result.googleAccount == null) {
        final recovered = await _recoverFirebaseSessionAfterLoginFailure(
          result.diagnostic,
        );
        if (recovered) return true;
        _lastDiagnostic = result.diagnostic;
        _status = AuthSessionStatus.authError;
        debugPrint(
          '[AuthSessionProvider] signInWithGoogle failed: '
          '${result.diagnostic?.reason.name}',
        );
        return false;
      }

      final prefs = await SharedPreferences.getInstance().timeout(
        _sessionTimeout,
      );
      await prefs.setString(_entryChoiceKey, _entryGoogle);
      final account = result.googleAccount!;
      final user = result.firebaseCredential?.user;
      debugPrint('[AUTH] Firebase sign-in success');
      if (user != null) debugPrint('[AUTH] uid detected ${_safeId(user.uid)}');
      await _applyAuthenticatedUser(
        user: user,
        fallbackEmail: account.email,
        fallbackDisplayName: account.displayName,
        fallbackPhotoUrl: account.photoUrl,
        persist: true,
        forceRevision: true,
      );

      _pendingSyncCount = await _cloudSync.pendingCount();
      debugPrint(
        '[AuthSessionProvider] signInWithGoogle success: ${_safeId(_uid)}',
      );
      return true;
    } on TimeoutException catch (e) {
      debugPrint('[AUTH] login timeout: $e');
      return await _recoverFirebaseSessionAfterLoginFailure(
        const AuthDiagnostic(
          reason: AuthFailureReason.network,
          message:
              'O login demorou mais que o esperado. Se o Firebase concluiu a entrada, a sessão será restaurada localmente.',
        ),
      );
    } catch (e) {
      debugPrint('[AUTH] login failed: $e');
      return await _recoverFirebaseSessionAfterLoginFailure(
        AuthDiagnostic(
          reason: AuthFailureReason.unknown,
          message: 'Falha inesperada durante o login.',
          rawError: e,
        ),
      );
    } finally {
      _isLoading = false;
      debugPrint('[AUTH] loading cleared');
      notifyListeners();
    }
  }

  Future<void> signOut({bool keepGuestMode = true}) async {
    debugPrint('[AuthSessionProvider] signOut keepGuestMode=$keepGuestMode');
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.logout().timeout(_sessionTimeout);
      await _storage.saveGoogleEmail('');
      await _storage.saveGoogleName('');
      await _storage.saveGooglePhotoUrl('');

      final prefs = await SharedPreferences.getInstance().timeout(
        _sessionTimeout,
      );
      if (keepGuestMode) {
        await prefs.setString(_entryChoiceKey, _entryGuest);
        _hasEntryChoice = true;
        _status = AuthSessionStatus.guest;
        await _switchToGuestNamespace(forceRevision: true);
      } else {
        await prefs.remove(_entryChoiceKey);
        _hasEntryChoice = false;
        _status = AuthSessionStatus.signedOut;
        await _switchToGuestNamespace(forceRevision: true);
      }
      _clearUser();
      _pendingSyncCount = await _cloudSync.pendingCount();
    } catch (e) {
      debugPrint('[AUTH] signOut failed: $e');
    } finally {
      _isLoading = false;
      debugPrint('[AUTH] loading cleared');
      notifyListeners();
    }
  }

  Future<void> refreshSyncStatus() async {
    _pendingSyncCount = await _cloudSync.pendingCount();
    notifyListeners();
  }

  Future<void> resetAfterAccountDeletion() async {
    try {
      await _authRepository.disconnect().timeout(_sessionTimeout);
    } catch (e) {
      debugPrint('[AUTH] account deletion session cleanup warning: $e');
    }
    final prefs = await SharedPreferences.getInstance().timeout(
      _sessionTimeout,
    );
    await prefs.remove(_entryChoiceKey);
    _lastDiagnostic = null;
    _status = AuthSessionStatus.signedOut;
    _hasEntryChoice = false;
    _clearUser();
    await _switchToGuestNamespace(forceRevision: true);
    _pendingSyncCount = await _cloudSync.pendingCount();
    notifyListeners();
  }

  @visibleForTesting
  void debugSetSignedInProfile({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    _uid = uid;
    _email = _clean(email);
    _displayName = _clean(displayName);
    _photoUrl = _clean(photoUrl);
    _status = AuthSessionStatus.signedIn;
    _hasEntryChoice = true;
    _isLoading = false;
    unawaited(_switchToUidNamespace(uid, migrateLegacyUnscoped: true));
    notifyListeners();
  }

  @visibleForTesting
  void debugSetSignedOut() {
    _clearUser();
    _status = AuthSessionStatus.signedOut;
    _hasEntryChoice = false;
    _isLoading = false;
    unawaited(_switchToGuestNamespace());
    notifyListeners();
  }

  void _startFirebaseUserListener() {
    if (_firebaseUserSub != null || Firebase.apps.isEmpty) return;
    _firebaseUserSub = FirebaseAuth.instance.userChanges().listen(
      (user) => unawaited(_handleFirebaseUserChange(user)),
      onError: (Object error) {
        debugPrint('[AuthSessionProvider] Firebase user stream error: $error');
      },
    );
  }

  Future<void> _handleFirebaseUserChange(User? user) async {
    if (user != null) {
      debugPrint(
        '[ONBOARDING] auth user changed ${_safeId(_uid)} -> ${_safeId(user.uid)}',
      );
      final changed = await _applyAuthenticatedUser(
        user: user,
        persist: true,
        forceRevision: _status == AuthSessionStatus.signingIn,
      );
      _isLoading = false;
      if (changed) notifyListeners();
      return;
    }

    if (_status == AuthSessionStatus.signingIn) return;

    final prefs = await SharedPreferences.getInstance().timeout(
      _sessionTimeout,
    );
    final entryChoice = prefs.getString(_entryChoiceKey);
    final nextStatus = entryChoice == _entryGuest
        ? AuthSessionStatus.guest
        : AuthSessionStatus.signedOut;
    final nextHasEntryChoice = entryChoice != null;
    final changed =
        _status != nextStatus ||
        _hasEntryChoice != nextHasEntryChoice ||
        _uid != null ||
        _email != null ||
        _displayName != null ||
        _photoUrl != null;

    _status = nextStatus;
    _hasEntryChoice = nextHasEntryChoice;
    _clearUser();
    await _switchToGuestNamespace(forceRevision: changed);
    await _persistGoogleProfile();
    _pendingSyncCount = await _cloudSync.pendingCount();
    if (changed) notifyListeners();
  }

  Future<bool> _applyAuthenticatedUser({
    User? user,
    String? fallbackEmail,
    String? fallbackDisplayName,
    String? fallbackPhotoUrl,
    bool persist = false,
    bool forceRevision = false,
  }) async {
    final nextUid = user?.uid;
    final nextEmail = _clean(user?.email) ?? _clean(fallbackEmail);
    final nextDisplayName =
        _clean(user?.displayName) ?? _clean(fallbackDisplayName);
    final nextPhotoUrl = _clean(user?.photoURL) ?? _clean(fallbackPhotoUrl);
    final changed =
        _uid != nextUid ||
        _email != nextEmail ||
        _displayName != nextDisplayName ||
        _photoUrl != nextPhotoUrl ||
        _status != AuthSessionStatus.signedIn ||
        !_hasEntryChoice;

    _uid = nextUid;
    _email = nextEmail;
    _displayName = nextDisplayName;
    _photoUrl = nextPhotoUrl;
    _status = AuthSessionStatus.signedIn;
    _hasEntryChoice = true;
    _lastDiagnostic = null;

    if (nextUid != null && nextUid.isNotEmpty) {
      await _switchToUidNamespace(
        nextUid,
        migrateLegacyUnscoped: true,
        forceRevision: forceRevision || changed,
      );
    }

    if (persist) {
      await _persistGoogleProfile();
    }
    return changed;
  }

  Future<void> _persistGoogleProfile() async {
    await _storage.saveGoogleEmail(_email ?? '');
    await _storage.saveGoogleName(_displayName ?? '');
    await _storage.saveGooglePhotoUrl(_photoUrl ?? '');
  }

  Future<void> _switchToUidNamespace(
    String uid, {
    bool migrateLegacyUnscoped = false,
    bool forceRevision = false,
  }) async {
    final oldNamespace = _storage.activeNamespace;
    debugPrint('[SESSION] namespace switching');
    await _storage.useUidNamespace(
      uid,
      migrateLegacyUnscoped: migrateLegacyUnscoped,
    );
    if (oldNamespace != _storage.activeNamespace || forceRevision) {
      _sessionRevision++;
      _cloudSync.resetRunContext();
      debugPrint(
        '[AUTH] uid changed ${_safeId(oldNamespace)} -> ${_safeId(_storage.activeNamespace)}',
      );
      debugPrint('[SESSION] loading account-scoped data for uid');
    }
  }

  Future<void> _switchToGuestNamespace({
    bool migrateLegacyUnscoped = false,
    bool forceRevision = false,
  }) async {
    final oldNamespace = _storage.activeNamespace;
    debugPrint('[SESSION] namespace switching');
    await _storage.useGuestNamespace(
      migrateLegacyUnscoped: migrateLegacyUnscoped,
    );
    if (oldNamespace != _storage.activeNamespace || forceRevision) {
      _sessionRevision++;
      _cloudSync.resetRunContext();
      debugPrint('[AUTH] uid changed ${_safeId(oldNamespace)} -> guest');
      debugPrint('[SESSION] clearing previous account state');
      debugPrint('[GUEST] namespace active');
    }
  }

  Future<bool> _recoverFirebaseSessionAfterLoginFailure(
    AuthDiagnostic? diagnostic,
  ) async {
    try {
      final user = Firebase.apps.isEmpty
          ? null
          : FirebaseAuth.instance.currentUser;
      if (user == null) {
        _lastDiagnostic = diagnostic;
        _status = AuthSessionStatus.authError;
        return false;
      }

      debugPrint('[AUTH] Firebase sign-in success');
      debugPrint('[AUTH] uid detected ${_safeId(user.uid)}');
      final prefs = await SharedPreferences.getInstance().timeout(
        _sessionTimeout,
      );
      await prefs.setString(_entryChoiceKey, _entryGoogle);
      await _applyAuthenticatedUser(
        user: user,
        persist: true,
        forceRevision: true,
      );
      _pendingSyncCount = await _cloudSync.pendingCount();
      return true;
    } catch (e) {
      _lastDiagnostic = diagnostic;
      _status = AuthSessionStatus.authError;
      debugPrint('[AUTH] Firebase session recovery failed: $e');
      return false;
    }
  }

  void _clearUser() {
    _uid = null;
    _email = null;
    _displayName = null;
    _photoUrl = null;
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _safeId(String? value) {
    if (value == null || value.isEmpty) return 'null';
    if (value == StorageService.guestNamespace) return 'guest';
    final suffix = value.length <= 4
        ? '****'
        : value.substring(value.length - 4);
    return '***$suffix';
  }
}

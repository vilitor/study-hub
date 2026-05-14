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
  AuthSessionProvider({AuthRepository? authRepository, bool autoLoad = true})
    : _authRepository = authRepository ?? AuthRepository() {
    _startFirebaseUserListener();
    if (autoLoad) unawaited(loadSession());
  }

  static const _entryChoiceKey = 'auth_entry_choice';
  static const _entryGuest = 'guest';
  static const _entryGoogle = 'google';

  final AuthRepository _authRepository;
  final StorageService _storage = StorageService();
  final CloudSyncService _cloudSync = CloudSyncService.instance;

  AuthSessionStatus _status = AuthSessionStatus.signedOut;
  AuthDiagnostic? _lastDiagnostic;
  String? _uid;
  String? _email;
  String? _displayName;
  String? _photoUrl;
  int _pendingSyncCount = 0;
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
        await _applyAuthenticatedUser(user: user, persist: true);
        debugPrint('[AuthSessionProvider] Firebase user restored: ${user.uid}');
      } else if (entryChoice == _entryGuest) {
        _status = AuthSessionStatus.guest;
        _clearUser();
        debugPrint('[AuthSessionProvider] Guest session restored');
      } else {
        _status = AuthSessionStatus.signedOut;
        _clearUser();
        debugPrint('[AuthSessionProvider] No local auth session');
      }
      _pendingSyncCount = await _cloudSync.pendingCount();
    } finally {
      _isLoading = false;
      debugPrint('[AuthSessionProvider] loadSession complete: ${_status.name}');
      notifyListeners();
    }
  }

  Future<void> continueAsGuest() async {
    debugPrint('[AuthSessionProvider] continueAsGuest');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_entryChoiceKey, _entryGuest);
    _hasEntryChoice = true;
    _status = AuthSessionStatus.guest;
    _lastDiagnostic = null;
    _clearUser();
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    debugPrint('[AuthSessionProvider] signInWithGoogle start');
    _status = AuthSessionStatus.signingIn;
    _lastDiagnostic = null;
    notifyListeners();

    final result = await _authRepository.login();
    if (!result.isSuccess || result.googleAccount == null) {
      _lastDiagnostic = result.diagnostic;
      _status = AuthSessionStatus.authError;
      debugPrint(
        '[AuthSessionProvider] signInWithGoogle failed: '
        '${result.diagnostic?.reason.name}',
      );
      notifyListeners();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_entryChoiceKey, _entryGoogle);
    final account = result.googleAccount!;
    final user = result.firebaseCredential?.user;
    await _applyAuthenticatedUser(
      user: user,
      fallbackEmail: account.email,
      fallbackDisplayName: account.displayName,
      fallbackPhotoUrl: account.photoUrl,
      persist: true,
    );
    notifyListeners();

    _pendingSyncCount = await _cloudSync.pendingCount();
    debugPrint('[AuthSessionProvider] signInWithGoogle success: $_uid');
    notifyListeners();
    return true;
  }

  Future<void> signOut({bool keepGuestMode = true}) async {
    debugPrint('[AuthSessionProvider] signOut keepGuestMode=$keepGuestMode');
    await _authRepository.logout();
    await _storage.saveGoogleEmail('');
    await _storage.saveGoogleName('');
    await _storage.saveGooglePhotoUrl('');

    final prefs = await SharedPreferences.getInstance();
    if (keepGuestMode) {
      await prefs.setString(_entryChoiceKey, _entryGuest);
      _hasEntryChoice = true;
      _status = AuthSessionStatus.guest;
    } else {
      await prefs.remove(_entryChoiceKey);
      _hasEntryChoice = false;
      _status = AuthSessionStatus.signedOut;
    }
    _clearUser();
    _pendingSyncCount = await _cloudSync.pendingCount();
    notifyListeners();
  }

  Future<void> refreshSyncStatus() async {
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
    notifyListeners();
  }

  @visibleForTesting
  void debugSetSignedOut() {
    _clearUser();
    _status = AuthSessionStatus.signedOut;
    _hasEntryChoice = false;
    _isLoading = false;
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
      final changed = await _applyAuthenticatedUser(user: user, persist: true);
      if (changed) notifyListeners();
      return;
    }

    if (_status == AuthSessionStatus.signingIn) return;

    final prefs = await SharedPreferences.getInstance();
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
}

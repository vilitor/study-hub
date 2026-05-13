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
  AuthSessionProvider({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository() {
    unawaited(loadSession());
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

  Future<void> loadSession() async {
    debugPrint('[AuthSessionProvider] loadSession start');
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
        _applyFirebaseUser(user);
        _status = AuthSessionStatus.signedIn;
        _hasEntryChoice = true;
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
    _uid = user?.uid;
    _email = user?.email ?? account.email;
    _displayName = user?.displayName ?? account.displayName;
    _photoUrl = user?.photoURL ?? account.photoUrl;
    _status = AuthSessionStatus.signedIn;
    _hasEntryChoice = true;

    await _storage.saveGoogleEmail(_email ?? '');
    await _storage.saveGoogleName(_displayName ?? '');
    await _storage.saveGooglePhotoUrl(_photoUrl ?? '');
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

  void _applyFirebaseUser(User user) {
    _uid = user.uid;
    _email = user.email;
    _displayName = user.displayName;
    _photoUrl = user.photoURL;
  }

  void _clearUser() {
    _uid = null;
    _email = null;
    _displayName = null;
    _photoUrl = null;
  }
}

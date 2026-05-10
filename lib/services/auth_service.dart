import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:study_hub/config/app_constants.dart';
import 'package:study_hub/models/auth_session.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleFirebaseSignInResult {
  final GoogleSignInAccount? googleAccount;
  final UserCredential? firebaseCredential;
  final AuthDiagnostic? diagnostic;

  const GoogleFirebaseSignInResult._({
    this.googleAccount,
    this.firebaseCredential,
    this.diagnostic,
  });

  bool get isSuccess => googleAccount != null && firebaseCredential != null;

  factory GoogleFirebaseSignInResult.success({
    required GoogleSignInAccount googleAccount,
    required UserCredential firebaseCredential,
  }) {
    return GoogleFirebaseSignInResult._(
      googleAccount: googleAccount,
      firebaseCredential: firebaseCredential,
    );
  }

  factory GoogleFirebaseSignInResult.failure(AuthDiagnostic diagnostic) {
    return GoogleFirebaseSignInResult._(diagnostic: diagnostic);
  }
}

class AuthService {
  static const String serverClientId = AppConstants.googleWebClientId;
  static const List<String> calendarScopes = [
    calendar.CalendarApi.calendarScope,
    calendar.CalendarApi.calendarEventsScope,
  ];

  static bool get hasConfiguredServerClientId =>
      serverClientId.trim().isNotEmpty &&
      serverClientId.endsWith('.apps.googleusercontent.com');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: serverClientId,
    scopes: calendarScopes,
  );

  Future<GoogleFirebaseSignInResult> signInWithGoogleAndFirebase() async {
    if (Firebase.apps.isEmpty) {
      return GoogleFirebaseSignInResult.failure(
        const AuthDiagnostic(
          reason: AuthFailureReason.firebaseNotInitialized,
          message: 'Firebase nao foi inicializado antes do login.',
        ),
      );
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return GoogleFirebaseSignInResult.failure(
          const AuthDiagnostic(
            reason: AuthFailureReason.cancelled,
            message: 'Login cancelado pelo usuario.',
          ),
        );
      }

      _logAccountState(account);
      final googleAuth = await account.authentication;
      final hasIdToken = _hasToken(googleAuth.idToken);
      final hasAccessToken = _hasToken(googleAuth.accessToken);
      _logTokenState(hasIdToken: hasIdToken, hasAccessToken: hasAccessToken);
      if (!hasIdToken || !hasAccessToken) {
        return GoogleFirebaseSignInResult.failure(
          diagnosticForMissingTokens(
            hasIdToken: hasIdToken,
            hasAccessToken: hasAccessToken,
          ),
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      debugPrint(
        '[AuthService] Exchanging Google credential with FirebaseAuth: '
        'idTokenPresent=$hasIdToken '
        'accessTokenPresent=$hasAccessToken',
      );
      final firebaseCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      _logFirebaseSuccess(firebaseCredential);

      return GoogleFirebaseSignInResult.success(
        googleAccount: account,
        firebaseCredential: firebaseCredential,
      );
    } catch (e) {
      final diagnostic = diagnosticForAuthError(e);
      _logAuthFailure(e, diagnostic);
      return GoogleFirebaseSignInResult.failure(diagnostic);
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('[AuthService] Silent sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[AuthService] Error during sign-out: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseAuth.instance.signOut();
      }
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('[AuthService] Error during disconnect: $e');
    }
  }

  Future<http.Client?> getAuthenticatedClient() async {
    final account = _googleSignIn.currentUser ?? await signInSilently();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    return GoogleAuthClient(authHeaders);
  }

  static AuthDiagnostic diagnosticForAuthError(Object error) {
    final text = _diagnosticText(error);
    if (error is FirebaseAuthException) {
      if (error.code == 'operation-not-allowed') {
        return AuthDiagnostic(
          reason: AuthFailureReason.providerDisabled,
          message: 'Google Sign-In esta desativado no Firebase Auth.',
          rawError: error,
        );
      }
      if (error.code == 'network-request-failed') {
        return AuthDiagnostic(
          reason: AuthFailureReason.network,
          message: 'Falha de rede durante autenticacao.',
          rawError: error,
        );
      }
      if (error.code == 'invalid-credential' ||
          error.code == 'account-exists-with-different-credential') {
        return AuthDiagnostic(
          reason: AuthFailureReason.missingOAuthClient,
          message: 'Firebase rejeitou a credencial Google recebida.',
          manualAction:
              'Confirme que o Android OAuth client do Firebase corresponde ao package com.victor.study_hub e ao SHA do APK release.',
          rawError: error,
        );
      }
    }

    if (error is PlatformException) {
      if (text.contains('12501') ||
          error.code.toLowerCase().contains('canceled') ||
          error.code.toLowerCase().contains('cancelled')) {
        return AuthDiagnostic(
          reason: AuthFailureReason.cancelled,
          message: 'Login cancelado pelo usuario.',
          rawError: error,
        );
      }
      if (text.contains('12500') ||
          text.contains('12502') ||
          text.contains('play services') ||
          text.contains('google play')) {
        return AuthDiagnostic(
          reason: AuthFailureReason.playServicesUnavailable,
          message:
              'Google Play Services falhou ou nao esta disponivel para o login.',
          manualAction:
              'Atualize o Google Play Services no dispositivo e teste novamente o APK release assinado.',
          rawError: error,
        );
      }
    }

    if (text.contains('api_exception: 10') ||
        text.contains('apiexception: 10') ||
        text.contains('developer_error') ||
        text.contains('oauth') ||
        text.contains('client')) {
      return AuthDiagnostic(
        reason: AuthFailureReason.missingOAuthClient,
        message: 'A configuracao OAuth Android/Firebase nao esta valida.',
        manualAction:
            'Valide SHA1/SHA256 do app com package com.victor.study_hub, baixe um google-services.json atualizado e reuse os clientes OAuth existentes.',
        rawError: error,
      );
    }
    if (text.contains('network')) {
      return AuthDiagnostic(
        reason: AuthFailureReason.network,
        message: 'Falha de rede durante autenticacao.',
        rawError: error,
      );
    }
    if (text.contains('access_denied') ||
        text.contains('disallowed') ||
        text.contains('tester')) {
      return AuthDiagnostic(
        reason: AuthFailureReason.consentOrTesterRestriction,
        message:
            'A tela de consentimento ou lista de testadores bloqueou o login.',
        rawError: error,
      );
    }
    return AuthDiagnostic(
      reason: AuthFailureReason.unknown,
      message: 'Falha inesperada durante autenticacao Google/Firebase.',
      rawError: error,
    );
  }

  static AuthDiagnostic diagnosticForMissingTokens({
    required bool hasIdToken,
    required bool hasAccessToken,
  }) {
    if (!hasIdToken) {
      return const AuthDiagnostic(
        reason: AuthFailureReason.missingGoogleIdToken,
        message:
            'Google Sign-In foi concluido, mas nenhum idToken foi retornado para o Firebase.',
        manualAction:
            'Verifique se o Web OAuth client esta configurado como serverClientId e se o Android OAuth client existente corresponde ao package/signing SHA do APK release.',
      );
    }

    return const AuthDiagnostic(
      reason: AuthFailureReason.missingGoogleAccessToken,
      message:
          'Google Sign-In foi concluido, mas nenhum accessToken foi retornado.',
      manualAction:
          'Confirme a conta Google, conectividade e consentimento para os escopos solicitados.',
    );
  }

  static bool _hasToken(String? token) => token != null && token.isNotEmpty;

  static String _diagnosticText(Object error) {
    if (error is PlatformException) {
      return [
        error.code,
        if (error.message != null) error.message,
        if (error.details != null) error.details.toString(),
      ].join(' ').toLowerCase();
    }
    return error.toString().toLowerCase();
  }

  void _logAccountState(GoogleSignInAccount account) {
    debugPrint(
      '[AuthService] Google account selected: '
      'serverClientIdConfigured=$hasConfiguredServerClientId '
      'hasEmail=${account.email.isNotEmpty} '
      'hasId=${account.id.isNotEmpty}',
    );
  }

  void _logTokenState({
    required bool hasIdToken,
    required bool hasAccessToken,
  }) {
    debugPrint(
      '[AuthService] Google auth tokens: '
      'serverClientIdConfigured=$hasConfiguredServerClientId '
      'idTokenPresent=$hasIdToken '
      'accessTokenPresent=$hasAccessToken',
    );
  }

  void _logFirebaseSuccess(UserCredential credential) {
    final user = credential.user;
    debugPrint(
      '[AuthService] FirebaseAuth sign-in success: '
      'hasUid=${user?.uid.isNotEmpty ?? false} '
      'hasEmail=${user?.email?.isNotEmpty ?? false} '
      'providerId=${credential.additionalUserInfo?.providerId ?? 'unknown'}',
    );
  }

  void _logAuthFailure(Object error, AuthDiagnostic diagnostic) {
    if (error is FirebaseAuthException) {
      debugPrint(
        '[AuthService] FirebaseAuth sign-in failed: '
        'reason=${diagnostic.reason.name} '
        'code=${error.code} '
        'message=${error.message}',
      );
      return;
    }
    if (error is PlatformException) {
      debugPrint(
        '[AuthService] Google Sign-In platform failure: '
        'reason=${diagnostic.reason.name} '
        'code=${error.code} '
        'message=${error.message} '
        'details=${error.details}',
      );
      return;
    }
    debugPrint(
      '[AuthService] Google/Firebase login failed: '
      'reason=${diagnostic.reason.name} '
      'error=$error',
    );
  }
}

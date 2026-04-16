import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;

/// Authenticated HTTP Client to be used with the googleapis package.
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

/// Service that handles Google OAuth 2.0 Authentication.
class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      calendar.CalendarApi.calendarScope,
      calendar.CalendarApi.calendarEventsScope,
    ],
  );

  /// Triggers the Google Sign-In flow.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      debugPrint('[AuthService] Critical Error during Google Login: $e');
      debugPrint('Setup Checklist:');
      debugPrint('1. Verify SHA-1 fingerprint in Google Cloud Console.');
      debugPrint('2. Ensure Support Email is configured in OAuth Consent Screen.');
      debugPrint('3. If in Testing, ensure your email is added to the Testers list.');
      return null;
    }
  }

  /// Disconnects the current user session.
  Future<void> signOut() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('[AuthService] Error during sign-out: $e');
    }
  }

  /// Attempts to sign in silently if a previous session exists.
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('[AuthService] Silent sign-in error: $e');
      return null;
    }
  }

  /// Returns an authenticated HTTP client for Google API calls.
  Future<http.Client?> getAuthenticatedClient() async {
    final account = _googleSignIn.currentUser ?? await signInSilently();
    if (account == null) return null;

    final authHeaders = await account.authHeaders;
    return GoogleAuthClient(authHeaders);
  }
}

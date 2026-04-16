import 'package:google_sign_in/google_sign_in.dart';
import 'package:study_hub/services/auth_service.dart';
import 'package:http/http.dart' as http;

/// Repository that manages authentication state and Google OAuth flows
class AuthRepository {
  final AuthService _authService = AuthService();

  /// Initiates the Google Sign-in flow
  Future<GoogleSignInAccount?> login() async {
    return await _authService.signIn();
  }

  /// Disconnects the current user from Google
  Future<void> logout() async {
    return await _authService.signOut();
  }

  /// Attempts to sign in silently if a previous session exists
  Future<GoogleSignInAccount?> getSession() async {
    return await _authService.signInSilently();
  }

  /// Returns an authenticated HTTP client for API calls
  Future<http.Client?> getAuthenticatedClient() async {
    return await _authService.getAuthenticatedClient();
  }
}

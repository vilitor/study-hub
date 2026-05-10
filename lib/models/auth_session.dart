enum AuthSessionStatus { guest, signedIn, signingIn, signedOut, authError }

enum AuthFailureReason {
  firebaseNotInitialized,
  missingOAuthClient,
  missingGoogleIdToken,
  missingGoogleAccessToken,
  cancelled,
  consentOrTesterRestriction,
  network,
  providerDisabled,
  playServicesUnavailable,
  unknown,
}

class AuthDiagnostic {
  final AuthFailureReason reason;
  final String message;
  final String? manualAction;
  final Object? rawError;

  const AuthDiagnostic({
    required this.reason,
    required this.message,
    this.manualAction,
    this.rawError,
  });
}

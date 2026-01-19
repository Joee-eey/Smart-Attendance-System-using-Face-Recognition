import 'package:google_sign_in/google_sign_in.dart';

/// Model representing a Google user after sign-in
class GoogleUser {
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? idToken;
  final String? accessToken;

  GoogleUser({
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.idToken,
    this.accessToken,
  });
}

/// Service for handling Google OAuth sign-in and sign-out
class GoogleAuthService {
    final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Client ID from Google Cloud Console
    // This is optional - the plugin will use the default client ID from google-services.json
    // if not provided. For explicit configuration, uncomment and set:
    // clientId: '745689690839-7o5h9f6o3d27a0t40siqk5ab6epn48mg.apps.googleusercontent.com',
  );

  /// Signs in with Google and returns user information
  /// Returns null if sign-in was cancelled
Future<GoogleUser?> signInWithGoogle({bool forceAccountChooser = false}) async {
  try {
    if (forceAccountChooser) {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
  }

    final GoogleSignInAccount? account = await _googleSignIn.signIn();

    if (account == null) {
      // User cancelled the sign-in
      return null;
    }

    final GoogleSignInAuthentication authentication =
        await account.authentication;

    return GoogleUser(
      displayName: account.displayName ?? '',
      email: account.email,
      photoUrl: account.photoUrl,
      idToken: authentication.idToken,
      accessToken: authentication.accessToken,
    );
  } catch (e) {
    return null;
  }
}

  /// Signs out the current Google user
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      throw Exception('Google sign-out failed: $e');
    }
  }

  /// Checks if a user is currently signed in
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Gets the current signed-in user (if any)
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }
}

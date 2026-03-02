import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:msal_auth/msal_auth.dart';

/// Model representing a Microsoft user after sign-in
class MicrosoftUser {
  final String displayName;
  final String email;
  final String providerId;
  final String? idToken;
  final String? accessToken;

  MicrosoftUser({
    required this.displayName,
    required this.email,
    required this.providerId,
    this.idToken,
    this.accessToken,
  });
}

/// Service for handling Microsoft OAuth sign-in and sign-out
class MicrosoftAuthService {
  static const List<String> _scopes = <String>[
    'openid',
    'profile',
    'email',
    'User.Read',
  ];

  SingleAccountPca? _publicClientApplication;
  MicrosoftUser? _currentUser;

  Future<SingleAccountPca> _getPublicClientApplication() async {
    if (_publicClientApplication != null) {
      return _publicClientApplication!;
    }

    final clientId = (dotenv.env['MS_CLIENT_ID'] ?? '').trim();
    final tenantId = (dotenv.env['MS_TENANT_ID'] ?? '').trim();
    final androidRedirectUri = (dotenv.env['MS_ANDROID_REDIRECT_URI'] ?? '').trim();

    if (clientId.isEmpty || tenantId.isEmpty) {
      throw Exception('Missing Microsoft OAuth configuration (MS_CLIENT_ID or MS_TENANT_ID).');
    }
    if (Platform.isAndroid && androidRedirectUri.isEmpty) {
      throw Exception('Missing Microsoft OAuth configuration (MS_ANDROID_REDIRECT_URI).');
    }

  _publicClientApplication = await SingleAccountPca.create(
    clientId: clientId,
    androidConfig: Platform.isAndroid
      ? AndroidConfig(
          configFilePath:
              'assets/msal_config.json',
          redirectUri: androidRedirectUri,
        )
      : null,
    appleConfig: (Platform.isIOS || Platform.isMacOS)
      ? AppleConfig(
          authorityType: AuthorityType.aad,
        )
      : null,
);

    return _publicClientApplication!;
  }

  /// Signs in with Microsoft and returns user information
  /// Returns null if sign-in was cancelled
  Future<MicrosoftUser?> signInWithMicrosoft({bool forceAccountChooser = false}) async {
    try {
      final client = await _getPublicClientApplication();

      if (forceAccountChooser) {
        try {
          await client.signOut();
        } on MsalException {
          // Ignore sign-out errors before interactive login.
        }
      }

      final AuthenticationResult authentication = await client.acquireToken(
        scopes: _scopes,
        prompt: forceAccountChooser ? Prompt.selectAccount : Prompt.whenRequired,
      );

      final String email = (authentication.account.username ?? '').trim();
      if (email.isEmpty) {
        throw Exception('Microsoft account did not return an email address.');
      }

      final user = MicrosoftUser(
        displayName: (authentication.account.name ?? '').trim(),
        email: email,
        providerId: authentication.account.id,
        idToken: authentication.idToken,
        accessToken: authentication.accessToken,
      );

      _currentUser = user;
      return user;
    } on MsalUserCancelException {
      return null;
    } on MsalException catch (e) {
      throw Exception('Microsoft sign-in failed: ${e.message}');
    } catch (e) {
      throw Exception('Microsoft sign-in failed: $e');
    }
  }

  /// Signs out the current Microsoft user
  Future<void> signOut() async {
    try {
      final client = await _getPublicClientApplication();
      await client.signOut();
      _currentUser = null;
    } on MsalException catch (e) {
      throw Exception('Microsoft sign-out failed: ${e.message}');
    } catch (e) {
      throw Exception('Microsoft sign-out failed: $e');
    }
  }

  /// Checks if a user is currently signed in
  Future<bool> isSignedIn() async {
    return _currentUser != null;
  }

  /// Gets the current signed-in user (if any)
  Future<MicrosoftUser?> getCurrentUser() async {
    return _currentUser;
  }
}

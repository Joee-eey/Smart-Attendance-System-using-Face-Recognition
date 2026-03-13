import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:userinterface/services/google_auth_service.dart';
import 'package:userinterface/services/microsoft_auth_service.dart';

/// Provider for managing authentication state
/// Handles Google sign in state and user information
class AuthProvider with ChangeNotifier {

  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final MicrosoftAuthService _microsoftAuthService = MicrosoftAuthService();
  
  GoogleUser? _currentUser;
  MicrosoftUser? _currentMicrosoftUser;
  bool _isLoading = false;
  String? _errorMessage;

  /// For custom login
  int? _userId;

  // SSO SETTINGS
  bool _googleSSOEnabled = true;
  bool _microsoftSSOEnabled = true;

  GoogleUser? get currentUser => _currentUser;
  MicrosoftUser? get currentMicrosoftUser => _currentMicrosoftUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null || _currentMicrosoftUser != null || _userId != null;

  /// Getter for custom login userId
  int? get userId => _userId;

  bool get googleSSOEnabled => _googleSSOEnabled;
  bool get microsoftSSOEnabled => _microsoftSSOEnabled;

  /// Load saved settings
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _googleSSOEnabled = prefs.getBool('google_sso') ?? true;
    _microsoftSSOEnabled = prefs.getBool('microsoft_sso') ?? true;

    notifyListeners();
  }

  /// Update Google SSO
  Future<void> setGoogleSSO(bool value) async {
    _googleSSOEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_sso', value);

    notifyListeners();
  }

  /// Update Microsoft SSO
  Future<void> setMicrosoftSSO(bool value) async {
    _microsoftSSOEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('microsoft_sso', value);

    notifyListeners();
  }

  /// Signs in with Google
  Future<bool> signInWithGoogle({bool forceChooser = false}) async {

    if (!_googleSSOEnabled) {
      _setError("Google SSO disabled by administrator.");
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final user = await _googleAuthService.signInWithGoogle(
        forceAccountChooser: forceChooser,
      );

      if (user == null) {
        // User cancelled account chooser
        return false;
      }

      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Sign-in failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _googleAuthService.signOut();
      if (_currentMicrosoftUser != null) {
        await _microsoftAuthService.signOut();
      }
      _currentUser = null;
      _currentMicrosoftUser = null;
      _userId = null; // Clear custom login userId too
      notifyListeners();
    } catch (e) {
      _setError('Sign-out failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Signs in with Microsoft
  Future<bool> signInWithMicrosoft({bool forceChooser = false}) async {

    if (!_microsoftSSOEnabled) {
      _setError("Microsoft SSO disabled by administrator.");
      return false;
    }
    
    _setLoading(true);
    _clearError();

    try {
      final user = await _microsoftAuthService.signInWithMicrosoft(
        forceAccountChooser: forceChooser,
      );

      if (user == null) {
        // User cancelled account chooser
        return false;
      }

      _currentMicrosoftUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Sign-in failed: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Set userId for custom login
  void setUserId(int id) {
    _userId = id;
    notifyListeners();
  }

  /// Clears the current user state (without calling Google sign-out)
  void clearUser() {
    _currentUser = null;
    _currentMicrosoftUser = null;
    _userId = null; // clear custom login userId
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

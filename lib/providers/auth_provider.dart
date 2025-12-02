import 'package:flutter/foundation.dart';
import 'package:userinterface/services/google_auth_service.dart';

/// Provider for managing authentication state
/// Handles Google sign-in state and user information
class AuthProvider with ChangeNotifier {
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  
  GoogleUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  GoogleUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Signs in with Google
  Future<void> signInWithGoogle({bool forceChooser = false}) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _googleAuthService.signInWithGoogle(forceAccountChooser: forceChooser);
      
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      } else {
        // User cancelled sign-in
      }
    } catch (e) {
      _setError('Sign-in failed: ${e.toString()}');
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
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError('Sign-out failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Clears the current user state (without calling Google sign-out)
  void clearUser() {
    _currentUser = null;
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

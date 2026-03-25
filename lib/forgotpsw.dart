import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  // State Variables
  bool _isLoading = false;
  bool _isCodeSent = false;
  bool _obscurePassword = true;

  int _resendTimer = 0;
  Timer? _timer;

  void _startTimer() {
    setState(() => _resendTimer = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        _timer?.cancel();
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Password Requirement Helpers
  bool get hasEightChars => _newPasswordController.text.length >= 8;
  bool get hasUppercase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get hasLowercase => _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get hasDigit => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get hasSpecial => _newPasswordController.text.contains(RegExp(r'[^A-Za-z0-9]'));

Widget _buildRequirementItem(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: met ? const Color(0xFF00B38A) : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: met ? const Color(0xFF00B38A) : Colors.black54,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(() {
      setState(() {});
    });
  }

  /// STEP 1: Request the 6-digit code
  Future<void> _requestVerificationCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog("Missing Email", "Please enter your email address.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      final url = Uri.parse('$baseUrl/forgot-password');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _startTimer();
        setState(() => _isCodeSent = true);
      } else {
        _showErrorDialog("Error", data['message'] ?? "Error sending code");
      }
    } catch (e) {
      _showErrorDialog("Connection Error", "Please check your internet connection.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// STEP 2: Submit the code and the new password
  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final newPass = _newPasswordController.text.trim();

    if (code.isEmpty || newPass.isEmpty) {
      _showErrorDialog("Missing Fields", "Please fill in all fields.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      final url = Uri.parse('$baseUrl/reset-password');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text.trim(),
          'code': code,
          'new_password': newPass
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showAnimatedDialog(
          context,
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF00B38A),
          title: "Success",
          message: "Your password has been reset successfully!",
          buttonText: "Back to Login",
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context); // Back to Login
          },
        );
      } else {
        _showErrorDialog("Invalid Code", data['message'] ?? "Invalid or expired code.");
      }
    } catch (e) {
      _showErrorDialog("Connection Error", "Please try again later.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    _showAnimatedDialog(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFEA324C),
      title: title,
      message: message,
      buttonText: "OK",
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true, 
          title: Text(
            _isCodeSent ? "Reset Password" : "Forgot Password",
            style: const TextStyle(
              color: Colors.black, // Ensure text is visible on white background
              fontSize: 20, 
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // FIELD 1: Email
              TextField(
                controller: _emailController,
                enabled: !_isCodeSent,
                decoration: _inputDecoration("Email Address"),
              ),

              // FIELDS 2 & 3: Only shown AFTER email is verified
              if (_isCodeSent) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration("6-Digit Code"),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration("New Password").copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                // Resend Code Section
                const SizedBox(height: 15),
                _buildRequirementItem("At least 8 characters", hasEightChars),
                _buildRequirementItem("At least one uppercase letter", hasUppercase),
                _buildRequirementItem("At least one lowercase letter", hasLowercase),
                _buildRequirementItem("At least one number", hasDigit),
                _buildRequirementItem("At least one special character", hasSpecial),
                Center(
                  child: TextButton(
                    onPressed: _resendTimer > 0 ? null : _requestVerificationCode,
                    child: Text(
                      _resendTimer > 0 
                        ? "Resend code in ${_resendTimer}s" 
                        : "Didn't receive a code? Resend",
                      style: TextStyle(
                        color: _resendTimer > 0 ? Colors.grey : const Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 15),

              // Button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading 
                    ? null 
                    : (_isCodeSent ? _resetPassword : _requestVerificationCode),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isCodeSent ? "Reset Password" : "Send Code", 
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16, 
                        color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to match Login Page's Input Style
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF1565C0)),
      ),
    );
  }

  void _showAnimatedDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 70),
                  const SizedBox(height: 20),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 15)),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    onPressed: onPressed,
                    child: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
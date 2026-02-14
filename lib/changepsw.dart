import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:provider/provider.dart';
import 'package:userinterface/providers/auth_provider.dart';

/*void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChangePasswordPage(),
    );
  }
}*/

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // New state variables for visibility
  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;


  Future<void> _updatePassword() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    // Validate new password length
    if (_newPasswordController.text.length < 6) {
      if (mounted) {
        _showAnimatedDialog(
          context,
          icon: Icons.warning_rounded,
          iconColor: Colors.red,
          title: "Weak Password",
          message: "Password must be at least 6 characters long.",
          buttonText: "OK",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
      return;
    }

    // Check if new password and confirm password match
    if (_newPasswordController.text != _confirmPasswordController.text) {
      if (mounted) {
        _showAnimatedDialog(
          context,
          icon: Icons.warning_rounded,
          iconColor: Colors.red,
          title: "Passwords Do Not Match",
          message: "The new password and confirm password must be identical.",
          buttonText: "OK",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
      return;
    }

    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final url = Uri.parse('$cleanBaseUrl/sa/users/change-password');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "current_password": _currentPasswordController.text,
          "new_password": _newPasswordController.text,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          _showAnimatedDialog(
            context,
            icon: Icons.check_circle_rounded,
            iconColor: Colors.green,
            title: "Success",
            message:
                responseData['message'] ?? "Password updated successfully!",
            buttonText: "OK",
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).maybePop(); // Go back to previous page
            },
          );
        }
      } else {
        if (mounted) {
          _showAnimatedDialog(
            context,
            icon: Icons.error_rounded,
            iconColor: Colors.red,
            title: "Error",
            message: responseData['message'] ?? "Current password is incorrect",
            buttonText: "OK",
            onPressed: () => Navigator.of(context).pop(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showAnimatedDialog(
          context,
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          title: "Connection Failed",
          message: "Failed to connect to server",
          buttonText: "OK",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration buildPasswordDecoration(
        String hint, bool obscure, VoidCallback toggle) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: Colors.grey.shade400,
            size: 20,
          ),
          onPressed: toggle,
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              TextField(
                controller: _currentPasswordController,
                obscureText: _currentObscure,
                decoration: buildPasswordDecoration(
                  "Current Password",
                  _currentObscure,
                  () => setState(() => _currentObscure = !_currentObscure),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPasswordController,
                obscureText: _newObscure,
                decoration: buildPasswordDecoration(
                  "New Password (at least 6 characters)",
                  _newObscure,
                  () => setState(() => _newObscure = !_newObscure),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _confirmObscure,
                decoration: buildPasswordDecoration(
                  "Confirm New Password",
                  _confirmObscure,
                  () => setState(() => _confirmObscure = !_confirmObscure),
                ),
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => log("Navigate to Forgot Password Page"),
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _updatePassword,
                  child: const Text(
                    "Confirm Change",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      pageBuilder: (context, animation1, animation2) {
        return const SizedBox();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        );
        final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeIn),
        );

        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Opacity(
              opacity: opacity.value,
              child: Transform.scale(
                scale: scale.value,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.all(24),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: iconColor, size: 70),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        onPressed: onPressed,
                        child: Text(
                          buttonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
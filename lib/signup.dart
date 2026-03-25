import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:userinterface/login.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  @override
  void initState() {
    super.initState();
  }

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;

  bool _hasMinLength = false;
  bool _hasDigit = false;
  bool _hasLower = false;
  bool _hasUpper = false;
  bool _hasSymbol = false;
  bool get _isPasswordStrong =>
      _hasMinLength && _hasDigit && _hasLower && _hasUpper && _hasSymbol;


  Future<void> registerUser(
    String username,
    String email,
    String password,
  ) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/signup');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      Map<String, dynamic>? data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        data = null;
      }

      // Success dialog
      if (response.statusCode == 201) {
        _showAnimatedDialog(
          context,
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF00B38A),
          title: "Sign Up Successful!",
          message: "Your account has been created successfully.",
          buttonText: "Continue to Login",
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        );
        return;
      }

      // Error dialog
      _showAnimatedDialog(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFEA324C),
        title: "Sign Up Failed",
        message: data != null && data.containsKey('message')
            ? data['message']
            : "Please try again later.",
        buttonText: "OK",
        onPressed: () => Navigator.of(context).pop(),
      );
    } catch (e) {
      // Connection error dialog
      _showAnimatedDialog(
        context,
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFF1565C0),
        title: "Connection Error",
        message:
            "Unable to reach the server.\nPlease check your internet connection.",
        buttonText: "OK",
        onPressed: () => Navigator.of(context).pop(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
    Widget _buildRequirementRow(String text, bool met) {
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

  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 55.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 5),
            const Text(
              "Welcome",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            const Text(
              "Create an account",
              style: TextStyle(fontSize: 15, color: Color(0xB2000000)),
            ),
            const SizedBox(height: 38),

            // Username
            SizedBox(
              height: 48,
              child: TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Username',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            SizedBox(
              height: 48,
              child: TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Email',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            SizedBox(
              height: 48,
              child: TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.grey),
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
                onChanged: (value) {
                  setState(() {
                    _hasMinLength = value.length >= 8;
                    _hasDigit = RegExp(r'[0-9]').hasMatch(value);
                    _hasLower = RegExp(r'[a-z]').hasMatch(value);
                    _hasUpper = RegExp(r'[A-Z]').hasMatch(value);
                    _hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            // Requirements block
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequirementRow("At least 8 characters", _hasMinLength),
                  _buildRequirementRow("Contains a digit", _hasDigit),
                  _buildRequirementRow("Contains a lowercase letter", _hasLower),
                  _buildRequirementRow("Contains an uppercase letter", _hasUpper),
                  _buildRequirementRow("Contains a symbol", _hasSymbol),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sign up button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading
                    ? null
                    : !_acceptedTerms
                        ? () {
                            _showAnimatedDialog(
                              context,
                              icon: Icons.error_outline_rounded,
                              iconColor: const Color(0xFFEA324C),
                              title: "Terms Not Accepted",
                              message:
                                  "You must accept the Terms & Policy to continue.",
                              buttonText: "OK",
                              onPressed: () => Navigator.of(context).pop(),
                            );
                          }
                        : () {
                          if (!_isPasswordStrong) {
                            _showAnimatedDialog(
                              context,
                              icon: Icons.error_outline_rounded,
                              iconColor: const Color(0xFFEA324C),
                              title: "Weak Password",
                              message:
                                  "Password must be at least 8 characters and include a digit, "
                                  "a lowercase letter, an uppercase letter, and a symbol.",
                              buttonText: "OK",
                              onPressed: () => Navigator.of(context).pop(),
                            );
                            return;
                          }
                            setState(() => _isLoading = true);
                            registerUser(
                              _usernameController.text.trim(),
                              _emailController.text.trim(),
                              _passwordController.text.trim(),
                            );
                          },
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Sign Up",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Terms & Policy checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _acceptedTerms = !_acceptedTerms;
                    });
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _acceptedTerms ? Colors.transparent : Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: Color(0xB3000000),
                        width: 1,
                      ),
                    ),
                    child: _acceptedTerms
                        ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF1565C0))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _acceptedTerms = !_acceptedTerms;
                      });
                    },
                    child: RichText(
                      textAlign: TextAlign.justify,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xB3000000),
                          height: 18 / 14,
                          fontSize: 14,
                        ),
                        children: [
                          const TextSpan(
                              text:
                                  'By creating an account, you are confirming that you have read and agree to our '),
                          TextSpan(
                            text: 'Terms of Use',
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            // Add tap recognizer for external/internal navigation if needed
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            // Add tap recognizer for external/internal navigation if needed
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Row(
              children: const [
                Expanded(
                  child: Divider(thickness: 1, color: Color(0xFFE0E0E0)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    "Or continue with",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: Divider(thickness: 1, color: Color(0xFFE0E0E0)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Log in with Google/Microsoft SSO
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Google or Microsoft account? ",
                  style: TextStyle(color: Color(0xB2000000)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Log in with SSO",
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60),

            // Log in link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account? ",
                  style: TextStyle(color: Color(0xB2000000)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Log in",
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Animated Popup Helper Function
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
                    borderRadius: BorderRadius.circular(8),
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
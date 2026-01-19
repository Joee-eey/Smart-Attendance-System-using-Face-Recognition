import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:userinterface/signup.dart';
import 'package:userinterface/dashboard.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:userinterface/providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> handleGoogleSignIn(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);

    try {
      await authProvider.signInWithGoogle();

      if (authProvider.isAuthenticated) {
        _showAnimatedDialog(
          context,
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF00B38A),
          title: "Sign In Successful",
          message: "Welcome! You have signed in with Google successfully.",
          buttonText: "Continue",
          onPressed: () {
            Navigator.of(context).pop();
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          },
        );
      } else if (authProvider.errorMessage != null) {
        _showAnimatedDialog(
          context,
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFEA324C),
          title: "Sign In Failed",
          message: authProvider.errorMessage ?? "Google sign-in failed. Please try again.",
          buttonText: "OK",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
    } catch (e) {
      _showAnimatedDialog(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFEA324C),
        title: "Sign In Failed",
        message: "Google sign-in failed. Please try again.",
        buttonText: "OK",
        onPressed: () => Navigator.of(context).pop(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> loginUser(
      BuildContext context, String email, String password) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/login');
    //final url = Uri.parse('http://192.168.100.22:5001/login');

    // Missing email or password dialog
    if (email.isEmpty || password.isEmpty) {
      _showAnimatedDialog(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFEA324C),
        title: "Missing Information",
        message: "Please enter both email and password to continue.",
        buttonText: "OK",
        onPressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      Map<String, dynamic>? data;
      try {
        data = json.decode(response.body);
      } catch (_) {
        data = null;
      }

      final message = data?['message'] ?? 'Unexpected server response';

      // Incorrect password or email not registered dialog
      if (response.statusCode == 401 &&
          message.contains("Incorrect password")) {
        _showAnimatedDialog(
          context,
          icon: Icons.lock_rounded,
          iconColor: const Color(0xFF1565C0),
          title: "Incorrect Password",
          message: "The password you entered is incorrect. Please try again.",
          buttonText: "Retry",
          onPressed: () => Navigator.of(context).pop(),
        );
      } else if (response.statusCode == 404 &&
          message.contains("Email not registered")) {
        _showAnimatedDialog(
          context,
          icon: Icons.person_off_rounded,
          iconColor: const Color(0xFF1565C0),
          title: "Email Not Registered",
          message:
              "The email address you entered is not registered.\nPlease sign up for a new account.",
          buttonText: "Sign Up",
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SignupPage()),
            );
          },
        );
      }

      // Successful login dialog
      else if (response.statusCode == 200) {
        _showAnimatedDialog(
          context,
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF00B38A),
          title: "Login Successful",
          message: "Welcome back! You have logged in successfully.",
          buttonText: "Continue",
          onPressed: () {
            Navigator.of(context).pop();
            navigator.pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          },
        );
      } else {
        // Default case dialog
        _showAnimatedDialog(
          context,
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFEA324C),
          title: "Login Failed",
          message: message,
          buttonText: "OK",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Connection error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
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
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
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
              "Log in to continue",
              style: TextStyle(fontSize: 15, color: Color(0xB2000000)),
            ),
            const SizedBox(height: 38),

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
                obscureText: true,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  overlayColor: Colors.transparent,
                ),
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Login button
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
                  overlayColor: Colors.transparent,
                ),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _isLoading = true);
                        loginUser(context, _emailController.text,
                            _passwordController.text);
                      },
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Log in",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
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

            // Google Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        handleGoogleSignIn(context);
                      },
                icon: Image.asset(
                  'assets/images/google.png',
                  width: 20,
                  height: 20,
                ),
                label: const Text(
                  "Google",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.transparent),
                  backgroundColor: const Color(0xFFF7F8FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Microsoft Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: Image.asset(
                  'assets/images/Microsoft.png',
                  width: 20,
                  height: 20,
                ),
                label: const Text(
                  "Microsoft",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.transparent),
                  backgroundColor: const Color(0xFFF7F8FA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 50),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Color(0xB2000000)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupPage(),
                      ),
                    );
                  },
                  child: Text(
                    "Sign Up",
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

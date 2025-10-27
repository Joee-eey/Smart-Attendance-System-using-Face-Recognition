import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:userinterface/signup.dart';
import 'package:userinterface/dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> loginUser(
      BuildContext context, String email, String password) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final url = Uri.parse('http://192.168.1.58:5001/login');

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

      // Use captured scaffoldMessenger safely after async gap
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );

      if (response.statusCode == 200) {
        Future.delayed(const Duration(seconds: 2), () {
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          );
        });
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
                onPressed: () {},
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

            const SizedBox(height: 85),

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
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:userinterface/providers/auth_provider.dart';
import 'package:userinterface/sa_dashboard.dart';

class SuperAdminLoginPage extends StatefulWidget {
  const SuperAdminLoginPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SuperAdminLoginPageState createState() => _SuperAdminLoginPageState();
}

class _SuperAdminLoginPageState extends State<SuperAdminLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> loginSuperAdmin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showDialog(
        title: 'Missing Information',
        message: 'Please enter both email and password.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/sa/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'role': 'superadmin',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final user = responseData['user'];
        if (user == null || user['id'] == null) {
          throw Exception('Invalid user data');
        }
        final int userId = user['id'];

        Provider.of<AuthProvider>(context, listen: false).setUserId(userId);

        _showDialog(
          title: 'Login Successful',
          message: 'Welcome back, Super Admin!',
          onOk: () {
            Navigator.of(context).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => SuperAdminDashboardPage()),
            );
          },
        );
      } else if (response.statusCode == 401) {
        _showDialog(
          title: 'Incorrect Password',
          message: 'The password you entered is incorrect. Please try again.',
        );
      } else if (response.statusCode == 404) {
        _showDialog(
          title: 'Email Not Registered',
          message: 'The email address is not registered as a Super Admin.',
        );
      } else {
        _showDialog(
          title: 'Login Failed',
          message: 'Unexpected error: ${response.body}',
        );
      }
    } catch (e) {
      _showDialog(
        title: 'Connection Error',
        message: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDialog(
      {required String title, required String message, VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onOk != null) onOk();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFF1565C0),
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: Color(0xFF1565C0),
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Key icon
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFFF4B942), width: 3),
                      ),
                      padding: EdgeInsets.all(20),
                      child: Icon(
                        Icons.vpn_key_rounded,
                        color: Color(0xFFF4B942),
                        size: 50,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Title
                    Text(
                      'Super Admin Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'Enter your credentials to access the admin dashboard',
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),

                    // Email
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle:
                              TextStyle(color: Color(0xB3FFFFFF), fontSize: 15),
                          filled: true,
                          fillColor: Color(0x1A000000),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                        ),
                        style: TextStyle(color: Color(0xB3FFFFFF)),
                      ),
                    ),
                    SizedBox(height: 15),

                    // Password
                    SizedBox(
                      height: 48,
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle:
                              TextStyle(color: Color(0xB3FFFFFF), fontSize: 15),
                          filled: true,
                          fillColor: Color(0x1A000000),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 10),
                        ),
                        style: TextStyle(color: Color(0xB3FFFFFF)),
                      ),
                    ),
                    SizedBox(height: 5),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    SizedBox(height: 5),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : loginSuperAdmin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF4B942),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Color(0xFFBA8E23),
                              width: 1,
                            ),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Log in',
                                style: TextStyle(
                                  color: Color(0xFFFFFFFF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 15),

                    // Secure area note
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Color(0x1A000000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              color: Color(0xB3FFFFFF), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This is a secure, restricted area. Unauthorized access is prohibited.',
                              style: TextStyle(
                                  color: Color(0xB3FFFFFF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),

                    // Non-super admins
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Not a Super Admin?',
                            style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.normal)),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          child: Text('Log in here',
                              style: TextStyle(
                                  color: Color(0xFFBA8E23),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}

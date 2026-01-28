import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:userinterface/providers/auth_provider.dart';
import 'package:userinterface/main.dart';
import 'dart:developer';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool attendanceReminders = true;
  String _username = "";
  String _email = "";
  bool _isProfileLoading = true;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _usernameController.text = data['username'] ?? '';
          _emailController.text = data['email'] ?? '';
          _isProfileLoading = false;
        });
      } else {
        log("Failed to load profile: ${response.body}");
      }
    } catch (e) {
      log("Error fetching profile: $e");
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Choose existing photo'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.photo_rounded),
                title: const Text('View Photo'),
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  // void _handleSignOut() async {
  //   await Provider.of<AuthProvider>(context, listen: false).signOut();

  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(builder: (_) => const HomePage()),
  //     (_) => false,
  //   );
  // }

  void _handleSignOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId; // get the current user id

    try {
      // Call backend to log the sign out
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/logout');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId}),
      );

      if (response.statusCode == 200) {
        log('Sign out logged successfully');
      } else {
        log('Failed to log sign out: ${response.body}');
      }
    } catch (e) {
      log('Error logging sign out: $e');
    }

    // Sign out locally
    await authProvider.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: AppBar(
            backgroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            centerTitle: true),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          currentIndex: 3,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedIconTheme: const IconThemeData(size: 24),
          unselectedIconTheme: const IconThemeData(size: 24),
          onTap: (index) {
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/dashboard');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, '/enroll');
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, '/reports');
            } else if (index == 3) {
              // Stay on Settings
            }
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt_rounded), label: 'Enrollment'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x1A000000)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Account Settings",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0x50000000),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: const Color(0x1A000000),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _showPhotoOptions,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Update Photo",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  ".JPG, .PNG, max 5MB",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Username",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      enabled: false,
                      controller: _usernameController,
                      style: const TextStyle(
                        color: Colors.black54, // ensures the text is visible
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF6F6F6),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide:
                              BorderSide(color: Color(0x1A000000), width: 1),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide:
                              BorderSide(color: Color(0x1A000000), width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Email",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      enabled: false,
                      controller: _emailController,
                      style: const TextStyle(
                        color: Colors.black54, // ensures the text is visible
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF6F6F6),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide:
                              BorderSide(color: Color(0x1A000000), width: 1),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide:
                              BorderSide(color: Color(0x1A000000), width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          "Change Password",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x1A000000)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Preferences",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0x50000000)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: const Color(0x1A000000),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Attendance Reminders"),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: attendanceReminders,
                            activeThumbColor: const Color(0xFF1565C0),
                            activeTrackColor: const Color(0x331565C0),
                            inactiveThumbColor: Colors.grey.shade400,
                            inactiveTrackColor: Colors.grey.shade300,
                            splashRadius: 0,
                            trackOutlineColor:
                                WidgetStateProperty.all(Colors.transparent),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (value) {
                              setState(() => attendanceReminders = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA324C),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _handleSignOut,
                  child: const Text(
                    "Sign Out",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

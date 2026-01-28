import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:userinterface/providers/auth_provider.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();

//   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

//   runApp(const SuperAdminDashboardApp());
// }

class SuperAdminDashboardApp extends StatelessWidget {
  const SuperAdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SA - Dashboard',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: false,
      ),
      home: const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.white,
          systemNavigationBarContrastEnforced: true,
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: SuperAdminDashboardPage(),
      ),
    );
  }
}

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  int _totalUsers = 0;
  double _growthPercent = 0.0;
  bool _isStatsLoading = true;
  int _totalAdmins = 0;
  double _adminGrowthPercent = 0.0;
  bool _isAdminStatsLoading = true;
  int _totalStudents = 0;
  double _studentGrowthPercent = 0.0;
  bool _isStudentStatsLoading = true;
  String _username = "";
  String _email = "";
  bool _isUserLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserStats();
    _fetchAdminStats();
    _fetchStudentStats();
  }

  Future<void> _fetchUserStats() async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final response = await http.get(Uri.parse('$baseUrl/sa/stats/users'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _totalUsers = data['total_users'];
          _growthPercent = (data['growth_percentage'] as num).toDouble();
          _isStatsLoading = false;
        });
      } else {
        throw Exception("Failed to load user stats");
      }
    } catch (e) {
      log("Error fetching user stats: $e");
      setState(() => _isStatsLoading = false);
    }
  }

  Future<void> _fetchAdminStats() async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final response = await http.get(Uri.parse('$baseUrl/sa/stats/admins'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _totalAdmins = data['total_admins'];
          _adminGrowthPercent = (data['growth_percentage'] as num).toDouble();
          _isAdminStatsLoading = false;
        });
      } else {
        throw Exception("Failed to load admin stats");
      }
    } catch (e) {
      log("Error fetching admin stats: $e");
      setState(() => _isAdminStatsLoading = false);
    }
  }

  Future<void> _fetchStudentStats() async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final response = await http.get(Uri.parse('$baseUrl/sa/stats/students'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _totalStudents = data['total'];
          _studentGrowthPercent = (data['growth_percent'] as num).toDouble();
          _isStudentStatsLoading = false;
        });
      } else {
        throw Exception("Failed to load stats");
      }
    } catch (e) {
      log("Error fetching student stats: $e");
      setState(() => _isStudentStatsLoading = false);
    }
  }

  Future<void> _fetchUserProfile(int userId) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final response = await http.get(Uri.parse('$baseUrl/sa/user/$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _username = data['username'];
          _email = data['email'];
          _isUserLoading = false;
        });
      } else {
        setState(() {
          _username = "Unknown";
          _email = "Unknown";
          _isUserLoading = false;
        });
      }
    } catch (e) {
      log("Error fetching user profile: $e");
      setState(() => _isUserLoading = false);
    }
  }

  // Profile Dialog
  Future<void> _showProfileDialog() async {
    // final String username = "Alex Rivera";
    // final String email = "alex.rivera@company.com";
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;
    setState(() => _isUserLoading = true);
    await _fetchUserProfile(userId!);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Account Settings",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0x80000000),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.black54, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFF6F6F6)),
                const SizedBox(height: 15),

                // Avatar Upload Section
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0x1A000000),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: Color(0xB3000000),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Update Photo",
                          style: TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "JPG or PNG, max 5MB",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                const Text(
                  "Username",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0x1A000000),
                      width: 1,
                    ),
                  ),
                  child: _isUserLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          _username,
                          style: const TextStyle(color: Colors.black87),
                        ),
                ),
                const SizedBox(height: 10),

                const Text(
                  "Email",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0x1A000000),
                      width: 1,
                    ),
                  ),
                  child: _isUserLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          _email,
                          style: const TextStyle(color: Colors.black87),
                        ),
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "Change Password",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Container(height: 1, color: const Color(0xFFF6F6F6)),
                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEB3349),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      final userId = authProvider.userId;

                      try {
                        final baseUrl = dotenv.env['BASE_URL']!;
                        final response = await http.post(
                          Uri.parse('$baseUrl/sa/logout'),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({"user_id": userId}),
                        );

                        if (response.statusCode == 200) {
                          log("Logout logged successfully");
                        } else {
                          log("Failed to log logout: ${response.body}");
                        }
                      } catch (e) {
                        log("Error logging logout: $e");
                      }
                      await authProvider.signOut();
                      Navigator.pushReplacementNamed(
                          context, "/sa/login"); // or your login page
                    },
                    child: const Text(
                      "Sign Out",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _addNewAdmin(String name, String email, String password) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse(
          '$baseUrl/sa/add'); // Backend endpoint to handle adding superadmin

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': name,
          'email': email,
          'password': password,
          'role': 'superadmin',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Failed: ${response.statusCode} ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  // Add Admin Dialog
  void _showAddAdminDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "New Admin",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0x80000000),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.black54, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFF6F6F6)),
                const SizedBox(height: 15),

                // Name TextField
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Enter Name",
                    hintStyle: TextStyle(
                      color: Color(0x4D000000),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Email TextField
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: "Enter Email",
                    hintStyle: TextStyle(
                      color: Color(0x4D000000),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Password TextField
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Enter Password",
                    hintStyle: TextStyle(
                      color: Color(0x4D000000),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text;

                      if (name.isEmpty || email.isEmpty || password.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("All fields are required.")),
                        );
                        return;
                      }

                      // Call backend API
                      final success = await _addNewAdmin(name, email, password);

                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("New Super Admin added successfully!")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text("Failed to add new Super Admin.")),
                        );
                      }
                    },
                    child: const Text(
                      "Add",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Profifle Avatar
              Positioned(
                top: -10,
                right: 16,
                child: GestureDetector(
                  onTap: _showProfileDialog,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0x1A000000),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 30,
                      color: Color(0xB3000000),
                    ),
                  ),
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "Overview",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF000000),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),

              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x1A000000),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        // height: 110, // removed
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1565C0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Users",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            Text(
                              _isStatsLoading ? "—" : _totalUsers.toString(),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  _growthPercent >= 0
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: _growthPercent >= 0
                                      ? const Color(0xFF00B38A)
                                      : Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isStatsLoading
                                      ? "-- %"
                                      : "${_growthPercent >= 0 ? "+" : ""}${_growthPercent.toStringAsFixed(1)} %",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _growthPercent >= 0
                                        ? const Color(0xFF00B38A)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        // height: 110, // removed
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x1A1565C0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Total Admins",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                            Text(
                              _isAdminStatsLoading
                                  ? "—"
                                  : _totalAdmins.toString(),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  _adminGrowthPercent >= 0
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: _adminGrowthPercent >= 0
                                      ? const Color(0xFF00B38A)
                                      : Colors.red,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isAdminStatsLoading
                                      ? "-- %"
                                      : "${_adminGrowthPercent >= 0 ? "+" : ""}${_adminGrowthPercent.toStringAsFixed(1)} %",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _adminGrowthPercent >= 0
                                        ? const Color(0xFF00B38A)
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                // height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "User Enrollment",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0x99FFFFFF),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _isStudentStatsLoading
                                      ? "—"
                                      : _totalStudents.toString(),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0x80FFFFFF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _studentGrowthPercent >= 0
                                            ? Icons.arrow_upward_rounded
                                            : Icons.arrow_downward_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _isStudentStatsLoading
                                            ? "-- %"
                                            : "${_studentGrowthPercent >= 0 ? "+" : ""}${_studentGrowthPercent.toStringAsFixed(1)} %",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Image.asset(
                        'assets/images/happy.png',
                        width: 35,
                        height: 35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Quick Access",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: _showAddAdminDialog,
                    child: Container(
                      // width: 80,
                      // height: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(0x1A000000),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_add_alt_rounded,
                            size: 30,
                            color: Color(0xFF1565C0),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Add Admin",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamed(context, '/sa/dashboard');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/sa/users');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/sa/logs');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/sa/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: 'Logs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

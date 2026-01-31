import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:userinterface/providers/auth_provider.dart';

// void main() {
//   WidgetsFlutterBinding.ensureInitialized();

//   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

//   SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//     systemNavigationBarColor: Colors.white,
//     systemNavigationBarDividerColor: Colors.white,
//     systemNavigationBarIconBrightness: Brightness.dark,
//     systemNavigationBarContrastEnforced: true,
//     statusBarColor: Colors.white,
//     statusBarIconBrightness: Brightness.dark,
//   ));

//   runApp(const SuperAdminUsersApp());
// }

class SuperAdminUsersApp extends StatelessWidget {
  const SuperAdminUsersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SA - Users',
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
        child: SuperAdminUsersPage(),
      ),
    );
  }
}

class UserItem {
  final int id;
  String name;
  String email;
  String role;
  String provider;

  UserItem(this.id, this.name, this.email, this.role, this.provider);

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      json['id'],
      json['name'],
      json['email'],
      json['role'],
      json['provider'],
    );
  }
}

class SuperAdminUsersPage extends StatefulWidget {
  const SuperAdminUsersPage({super.key});

  @override
  State<SuperAdminUsersPage> createState() => _SuperAdminUsersPageState();
}

class _SuperAdminUsersPageState extends State<SuperAdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();

  List<String> selectedFilters = ["All"];
  String sortOrder = "A-Z";

  List<UserItem> users = [];
  List<UserItem> usersBackup = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  String formatRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1);
  }

  // Future<void> fetchUsers({String search = ""}) async {
  //   final baseUrl = dotenv.env['BASE_URL']!;
  //   final url = Uri.parse('$baseUrl/sa/users?search=$search');

  //   try {
  //     final response = await http.get(url);

  //     if (response.statusCode == 200) {
  //       final List data = jsonDecode(response.body);

  //       setState(() {
  //         users = data.map((e) => UserItem.fromJson(e)).toList();
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint("Error fetching users: $e");
  //   }
  // }

  Future<void> fetchUsers({String search = ""}) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/sa/users?search=$search');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        setState(() {
          users = data.map((e) => UserItem.fromJson(e)).toList();
          usersBackup =
              List.from(users); // <-- keep a copy for filtering/sorting
          _applyFilterAndSort(); // optional: apply any existing filter/sort
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }
  }

  final GlobalKey _filterKey = GlobalKey();

  void _showFilterPopup() {
    final RenderBox renderBox =
        _filterKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx - 130,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        0,
      ),
      color: const Color(0xE61565C0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 0,
      items: [
        PopupMenuItem(
          enabled: false,
          child: StatefulBuilder(
            builder: (context, menuSetState) {
              const subFilters = [
                "Admin",
                "Superadmin",
                "Email",
                "Google",
                "Microsoft"
              ];

              return IconTheme(
                data: const IconThemeData(
                  color: Color(0xFFFFFFFF),
                  size: 18,
                ),
                child: SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5.0, top: 5.0),
                        child: Text(
                          "Sort & Filter",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Divider(color: Color(0xFFFFFFFF), thickness: 1),

                      // Filters
                      ...["All", ...subFilters].map((item) {
                        bool checked = selectedFilters.contains(item);
                        return _buildSelectionRow(
                          label: item,
                          icon: checked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          onTap: () {
                            menuSetState(() {
                              if (item == "All") {
                                if (checked) {
                                  selectedFilters = [];
                                } else {
                                  selectedFilters = ["All", ...subFilters];
                                }
                              } else {
                                if (checked) {
                                  selectedFilters.remove(item);
                                  selectedFilters.remove("All");
                                } else {
                                  selectedFilters.add(item);
                                  if (subFilters.every((element) =>
                                      selectedFilters.contains(element))) {
                                    selectedFilters.add("All");
                                  }
                                }
                              }
                            });

                            _applyFilterAndSort(); // <-- Apply filter + sort
                          },
                        );
                      }).toList(),

                      const Divider(color: Color(0xFFFFFFFF), thickness: 1),

                      // Sort options
                      _buildSelectionRow(
                        label: "A to Z",
                        icon: sortOrder == "A-Z"
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        onTap: () {
                          menuSetState(() => sortOrder = "A-Z");
                          _applyFilterAndSort(); // Apply after change
                        },
                      ),
                      _buildSelectionRow(
                        label: "Z to A",
                        icon: sortOrder == "Z-A"
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        onTap: () {
                          menuSetState(() => sortOrder = "Z-A");
                          _applyFilterAndSort(); // Apply after change
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Filter and sort users based on selectedFilters and sortOrder
  void _applyFilterAndSort() {
    List<UserItem> filtered = List.from(usersBackup); // original list

    // Filtering
    if (!selectedFilters.contains("All") && selectedFilters.isNotEmpty) {
      filtered = filtered.where((user) {
        // Lowercase for comparison
        final userRole = user.role.toLowerCase();
        final userProvider = user.provider.toLowerCase();

        bool roleMatch =
            (selectedFilters.contains("Admin") && userRole == "admin") ||
                (selectedFilters.contains("Superadmin") &&
                    userRole == "superadmin");

        bool providerMatch = (selectedFilters.contains("Email") &&
                userProvider == "email") ||
            (selectedFilters.contains("Google") && userProvider == "google") ||
            (selectedFilters.contains("Microsoft") &&
                userProvider == "microsoft");

        return roleMatch || providerMatch;
      }).toList();
    }

    // Sorting
    if (sortOrder == "A-Z") {
      filtered
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (sortOrder == "Z-A") {
      filtered
          .sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    }

    setState(() {
      users = filtered; // update UI
    });
  }

  Widget _buildSelectionRow({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFFFFF), size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search",
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            suffixIcon:
                const Icon(Icons.search_rounded, color: Color(0x4D000000)),
            contentPadding:
                const EdgeInsets.only(left: 10, top: 12, bottom: 12),
            filled: true,
            fillColor: const Color(0xFFF6F6F6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0x1A000000), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF6F6F6), width: 1),
            ),
          ),
          onChanged: (value) {
            // Call your search function every time the user types
            fetchUsers(search: value);
          },
        ),
        const SizedBox(height: 5),
        IconButton(
          key: _filterKey,
          icon: const Icon(Icons.filter_alt_rounded, color: Color(0xFF1565C0)),
          onPressed: _showFilterPopup,
        ),
      ],
    );
  }

  Widget _userCard(UserItem user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0xFFEFECE8),
            child:
                Icon(Icons.person_rounded, color: Color(0xFFC6C3BD), size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15),
                    ),
                    const SizedBox(width: 5),
                    _rolePill(formatRole(user.role)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  user.email,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xB3000000)),
                ),
                const SizedBox(height: 5),
                // _providerPill(user.provider),
                _providerPill(formatRole(user.provider)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            color: const Color(0xE61565C0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(user);
              } else if (value == 'delete') {
                _showDeleteDialog(user);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: const [
                    Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 5),
                    Text('Edit', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: const [
                    Icon(Icons.delete_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 5),
                    Text('Delete', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rolePill(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: role == "Admin" ? Color(0x1A1565C0) : Color(0x1A1565C0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 13,
          color: role == "Admin" ? Color(0xFF1565C0) : Color(0xFF1565C0),
        ),
      ),
    );
  }

  Widget _providerPill(String provider) {
    IconData icon;
    switch (provider) {
      case "Google":
        icon = Icons.person_rounded;
        break;
      case "Microsoft":
        icon = Icons.window_rounded;
        break;
      default:
        icon = Icons.email_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x1A000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xB3000000)),
          const SizedBox(width: 5),
          Text(
            provider,
            style: const TextStyle(fontSize: 13, color: Color(0xB3000000)),
          ),
        ],
      ),
    );
  }

  Future<bool> _editUser(
      int userId, String name, String email, int adminId) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/sa/user/edit');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id_to_edit': userId,
          'admin_id': adminId,
          'name': name,
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        log("Failed to edit user: ${response.statusCode} ${response.body}");
        return false;
      }
    } catch (e) {
      log("Error editing user: $e");
      return false;
    }
  }

  void _showEditDialog(UserItem user) {
    final TextEditingController nameController =
        TextEditingController(text: user.name);
    final TextEditingController emailController =
        TextEditingController(text: user.email);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Edit User",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0x80000000),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFF6F6F6)),
                const SizedBox(height: 15),
                TextField(
                  controller: nameController,
                  decoration: _inputDecoration("Name"),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: _inputDecoration("Email"),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final authProvider =
                          Provider.of<AuthProvider>(context, listen: false);
                      final adminId = authProvider.userId;

                      if (adminId == null) {
                        Navigator.pop(dialogContext);

                        if (!mounted) return;

                        _showAnimatedDialog(
                          icon: Icons.error_outline,
                          iconColor: Colors.red,
                          title: "Error",
                          message: "Admin not logged in.",
                          buttonText: "OK",
                          onPressed: () => Navigator.pop(context),
                        );
                        return;
                      }

                      final success = await _editUser(
                        user.id,
                        nameController.text.trim(),
                        emailController.text.trim(),
                        adminId,
                      );

                      // ✅ Close edit dialog FIRST
                      Navigator.pop(dialogContext);

                      if (!mounted) return;

                      if (success) {
                        setState(() {
                          user.name = nameController.text.trim();
                          user.email = emailController.text.trim();
                        });

                        _showAnimatedDialog(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF00B38A),
                          title: "Success",
                          message: "User updated successfully!",
                          buttonText: "OK",
                          onPressed: () => Navigator.pop(context),
                        );
                      } else {
                        _showAnimatedDialog(
                          icon: Icons.error_outline,
                          iconColor: Colors.red,
                          title: "Failed",
                          message: "Failed to update user. Try again.",
                          buttonText: "OK",
                          onPressed: () => Navigator.pop(context),
                        );
                      }
                    },
                    child: const Text(
                      "Confirm Changes",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<bool> _deleteUser(int userId, int adminId) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/sa/user/delete');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_id_to_delete": userId,
          "admin_id": adminId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        log("Failed to delete: ${response.statusCode} ${response.body}");
        return false;
      }
    } catch (e) {
      log("Error deleting user: $e");
      return false;
    }
  }

  void _showAnimatedDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(UserItem user) {
    showDialog(
      context: context, // Use page context
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFF84F31), size: 48),
                const SizedBox(height: 12),
                const Text("Are you sure?",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  "Do you really want to delete this user?\nThis process cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6F6F6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF84F31),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: () async {
                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          final adminId = authProvider.userId;

                          Navigator.of(dialogContext)
                              .pop(); // close delete dialog first

                          if (adminId == null) {
                            _showAnimatedDialog(
                              icon: Icons.error_outline,
                              iconColor: Colors.red,
                              title: "Error",
                              message: "Admin not logged in.",
                              buttonText: "OK",
                              onPressed: () => Navigator.of(context).pop(),
                            );
                            return;
                          }

                          final success = await _deleteUser(user.id, adminId);

                          if (success) {
                            setState(() => users.remove(user));
                            _showAnimatedDialog(
                              icon: Icons.check_circle_outline_rounded,
                              iconColor: const Color(0xFF00B38A),
                              title: "Success",
                              message: "User deleted successfully!",
                              buttonText: "OK",
                              onPressed: () => Navigator.of(context).pop(),
                            );
                          } else {
                            _showAnimatedDialog(
                              icon: Icons.error_outline,
                              iconColor: Colors.red,
                              title: "Failed",
                              message: "Failed to delete the user. Try again.",
                              buttonText: "OK",
                              onPressed: () => Navigator.of(context).pop(),
                            );
                          }
                        },
                        child: const Text("Delete",
                            style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                )
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
      extendBody: false,
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          children: [
            _searchBar(),
            const SizedBox(height: 0),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) => _userCard(users[index]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
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

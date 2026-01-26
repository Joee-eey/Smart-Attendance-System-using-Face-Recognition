import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.white, 
    systemNavigationBarDividerColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark, 
    systemNavigationBarContrastEnforced: true, 
    statusBarColor: Colors.white, 
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const SuperAdminUsersApp());
}

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
  String name;
  String email;
  String role;
  String provider;

  UserItem(this.name, this.email, this.role, this.provider);
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

  List<UserItem> users = [
    UserItem("Alex Rivera", "alex.rivera@company.com", "Admin", "Email"),
    UserItem("Jordan Smith", "j.smith@microsoft.org", "User", "Microsoft"),
    UserItem("Taylor Chen", "t.chen@google.com", "User", "Google"),
    UserItem("Sarah Wilson", "s.wilson@corp.com", "User", "Email"),
  ];

  final GlobalKey _filterKey = GlobalKey();

  void _showFilterPopup() {
    final RenderBox renderBox = _filterKey.currentContext!.findRenderObject() as RenderBox;
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
              const subFilters = ["Admin", "User", "Email", "Google", "Microsoft"];

              return IconTheme(
                data: const IconThemeData(
                  color: Color(0xFFFFFFFF),
                  size: 18,
                ),
                child: SizedBox(
                  width: 100,
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

                      ...["All", ...subFilters].map((item) {
                        bool checked = selectedFilters.contains(item);
                        return _buildSelectionRow(
                          label: item,
                          icon: checked
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          onTap: () {
                            setState(() {
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
                                    if (subFilters.every(
                                        (element) => selectedFilters.contains(element))) {
                                      selectedFilters.add("All");
                                    }
                                  }
                                }
                              });
                            });
                          },
                        );
                      }).toList(),

                      const Divider(color: Color(0xFFFFFFFF), thickness: 1),

                      _buildSelectionRow(
                        label: "A to Z",
                        icon: sortOrder == "A-Z"
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        onTap: () =>
                            setState(() => menuSetState(() => sortOrder = "A-Z")),
                      ),
                      _buildSelectionRow(
                        label: "Z to A",
                        icon: sortOrder == "Z-A"
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        onTap: () =>
                            setState(() => menuSetState(() => sortOrder = "Z-A")),
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
            suffixIcon: const Icon(Icons.search_rounded, color: Color(0x4D000000)),
            contentPadding: const EdgeInsets.only(left: 10, top: 12, bottom: 12),
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
                    _rolePill(user.role),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 14, color: Color(0xB3000000)),
                ),
                const SizedBox(height: 5),
                _providerPill(user.provider),
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

  void _showEditDialog(UserItem user) {
    final TextEditingController nameController = TextEditingController(text: user.name);
    final TextEditingController emailController = TextEditingController(text: user.email);

    showDialog(
      context: context,
      builder: (context) {
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
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: Colors.black54, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFF6F6F6)),
                const SizedBox(height: 15),

                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Name",
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: "Email",
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.transparent, width: 1),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        user.name = nameController.text;
                        user.email = emailController.text;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Confirm Changes",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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

  void _showDeleteDialog(UserItem user) {
    showDialog(
      context: context,
      builder: (context) {
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
                        onPressed: () => Navigator.pop(context),
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
                        onPressed: () {
                          setState(() => users.remove(user));
                          Navigator.pop(context);
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
            Navigator.pushNamed(context, '/dashboard');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/users');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/logs');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/settings');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

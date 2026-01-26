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

  runApp(const SuperAdminLogsApp());
}

class SuperAdminLogsApp extends StatelessWidget {
  const SuperAdminLogsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SA - Logs',
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
        child: SuperAdminLogsPage(),
      ),
    );
  }
}

class UserItem {
  String title;
  String description;
  IconData icon;
  String timestamp;

  UserItem(this.title, this.description, this.icon, this.timestamp);
}

class SuperAdminLogsPage extends StatefulWidget {
  const SuperAdminLogsPage({super.key});

  @override
  State<SuperAdminLogsPage> createState() => _SuperAdminLogsPageState();
}

class _SuperAdminLogsPageState extends State<SuperAdminLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _filterKey = GlobalKey();

  String sortOrder = "Default";

  List<UserItem> logs = [
    UserItem("New User", "Taylor Chen joined Cheese!", Icons.person_add_rounded, "11 Jan 2026, 10:30:52 AM"),
    UserItem("Edit", "Jordan Smith updated their folder contents.", Icons.edit_rounded, "11 Jan 2026, 12:03:21 PM"),
    UserItem("Delete", "Jordan Smith deletes an enrollment record.", Icons.delete_rounded, "11 Jan 2026, 12:08:57 PM"),
    UserItem("Created/Updated", "Jordan Smith created a new file.", Icons.add_rounded, "11 Jan 2026, 12:12:40 PM"),
    UserItem("Log in/Sign Out", "Alex Rivera logged in to Cheese!", Icons.person_rounded, "13 Jan 2026, 16:42:36 PM"),
  ];

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
              const sortOptions = ["Default", "Date: Latest", "Date: Earliest"];

              return IconTheme(
                data: const IconThemeData(
                  color: Color(0xFFFFFFFF),
                  size: 18,
                ),
                child: SizedBox(
                  width: 110,
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

                      ...sortOptions.map((option) {
                        return _buildRadioRow(
                          label: option,
                          selected: sortOrder == option,
                          onTap: () => setState(() => menuSetState(() => sortOrder = option)),
                        );
                      }).toList(),
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

  Widget _buildRadioRow({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: Colors.white,
              size: 18,
            ),
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

  Widget _userCard(UserItem log) {
    Color iconColor;
    Color containerColor;

    switch (log.title) {
      case "Edit":
        iconColor = const Color(0xFF1565C0);
        containerColor = const Color(0x1A1565C0);
        break;
      case "Delete":
        iconColor = const Color(0xFFEA324C);
        containerColor = const Color(0x1AEA324C);
        break;
      case "Created/Updated":
        iconColor = const Color(0xFF00B38A);
        containerColor = const Color(0x1A00B38A);
        break;
      case "Log in/Sign Out":
        iconColor = const Color(0xFFF2AC42);
        containerColor = const Color(0x1AF2AC42);
        break;
      default:
        iconColor = const Color(0xCC000000);
        containerColor = const Color(0x1A000000);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(log.icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF000000),
                      fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  log.description,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xB3000000),
                      fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 5),
                Text(
                  log.timestamp,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w300),
                ),
              ],
            ),
          ),
        ],
      ),
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
                itemCount: logs.length,
                itemBuilder: (context, index) => _userCard(logs[index]),
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
        currentIndex: 2,
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

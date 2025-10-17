import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 

void main() {
  runApp(const CheeseApp());
}

class CheeseApp extends StatelessWidget {
  const CheeseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cheese!',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      ),
      home: const DashboardPage(),
    );
  }
}

class Folder {
  String name;
  DateTime date;

  Folder(this.name, this.date);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<Folder> folders = [
    Folder('Class 1', DateTime(2025, 9, 1)),
    Folder('Class 2', DateTime(2025, 8, 6)),
    Folder('Class 3', DateTime(2025, 7, 20)),
  ];

  void _showFolderDialog({Folder? folder, bool isEdit = false}) {
    final TextEditingController nameController =
        TextEditingController(text: folder?.name ?? '');

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
                // Title
                Text(
                  isEdit ? "Edit Folder" : "New Folder",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0x80000000),
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  height: 1,
                  color: const Color(0xFFF6F6F6),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image,
                          size: 40, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? "Change Picture" : "Upload Picture",
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          "JPG or PNG, max 5MB",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                SizedBox(
                  height: 45,
                  child: TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "Folder Name",
                      hintStyle: const TextStyle(color: Colors.grey,  fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isEdit && folder != null) {
                          folder.name = nameController.text;
                          folder.date = DateTime.now();
                        } else {
                          folders.add(
                              Folder(nameController.text, DateTime.now()));
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      isEdit ? "Confirm Changes" : "Create Folder",
                      style: const TextStyle(
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

  void _showDeleteDialog(Folder folder) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white, 
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFF84F31), size: 48),
                const SizedBox(height: 12),
                const Text(
                  "Are you sure?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Do you really want to delete this folder?\nThis process cannot be undone.",
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
                            backgroundColor: Color(0xFFF6F6F6),
                            side: const BorderSide(color: Color(0xFFF6F6F6)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                         ),
                        child: const Text("Cancel",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
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
                          setState(() => folders.remove(folder));
                          Navigator.pop(context);
                        },
                        child: const Text("Delete",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white, 
      systemNavigationBarIconBrightness: Brightness.dark, 
      statusBarColor: Colors.white, 
      statusBarIconBrightness: Brightness.dark, 
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'cheese!',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFFFFFFF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
               style: const TextStyle(
                color: Color(0xFFF6F6F6),
               ),
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: const TextStyle(
                  color: Color(0xFF9E9E9E),
                ),
                suffixIcon: const Icon(Icons.search, color: Color(0x4D000000)),
                contentPadding:
                    const EdgeInsets.only(left: 10, top: 12, bottom: 12),
                filled: false,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFF6F6F6),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFF6F6F6),
                    width: 1,
                  ),
                ),
              ),
              cursorColor: Colors.black,
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Groups",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: folders.length + 1, // Added +1 for the button
                itemBuilder: (context, index) {
                  if (index == folders.length) {
                    // Add button shown after last folder
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Material(
                          color: const Color(0xFF1565C0),
                          elevation: 4,
                          shape: const CircleBorder(),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () => _showFolderDialog(),
                            child: const SizedBox(
                              width: 30, 
                              height: 30,
                              child: Icon(Icons.add,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final folder = folders[index];
                  return Dismissible(
                    key: Key(folder.name),
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      height: 60,
                      child: const Icon(Icons.edit_rounded,
                          color: Color(0xFFFFFFFF), size: 24),
                    ),
                    secondaryBackground: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF84F31),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      height: 60,
                      child: const Icon(Icons.delete,
                          color: Color(0xFFFFFFFF), size: 24),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        _showFolderDialog(folder: folder, isEdit: true);
                        return false;
                      } else {
                        _showDeleteDialog(folder);
                        return false;
                      }
                    },
                    child: Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0x1A000000),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  "Last updated on ${folder.date.day.toString().padLeft(2, '0')}/${folder.date.month.toString().padLeft(2, '0')}/${folder.date.year}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
        currentIndex: 0,
        selectedFontSize: 12, 
        unselectedFontSize: 12,
        selectedIconTheme: const IconThemeData(size: 24), 
        unselectedIconTheme: const IconThemeData(size: 24),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded), label: 'Scan'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

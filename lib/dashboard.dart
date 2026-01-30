import 'dart:convert';
import 'dart:developer';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:userinterface/attendance.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:userinterface/providers/auth_provider.dart';

class FileItem {
  int id;
  String name;
  DateTime date;

  FileItem(this.id, this.name, this.date);
}

class Folder {
  int? id;
  String name;
  DateTime date;
  String? imageUrl;
  List<FileItem> files;
  bool isExpanded;

  Folder(this.name, this.date,
      {this.id, this.imageUrl, this.files = const [], this.isExpanded = false});
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Folder> folders = [];
  List<Folder> filteredFolders = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  List<Map<String, dynamic>> students = [];
  Set<int> selectedStudentIds = {};
  bool isLoadingStudents = false;

  final TextEditingController groupSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFolders();
  }

  void _filterGroups(String query) {
  setState(() {
    if (query.isEmpty) {
      filteredFolders = folders;
    } else {
      filteredFolders = folders
          .where((folder) =>
              folder.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  });
}

  Future<void> _confirmEnrollStudents({
    required List<int> studentIds,
    required int folderId,
  }) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    await http.post(
      Uri.parse('$baseUrl/enrollment/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_ids': studentIds,
        'folder_id': folderId,
      }),
    );
  }

  void _showEnrollStudentDialog(int subjectId) {
    List<int> selectedStudentIds = [];
    bool isLoadingStudents = false;
    List<Map<String, dynamic>> students = [];
    final TextEditingController searchController = TextEditingController();
    Timer? debounce; // For debounce

    // Fetch students from backend
    Future<void> fetchStudents(
        String keyword, StateSetter setDialogState) async {
      setDialogState(() => isLoadingStudents = true);

      try {
        final baseUrl = dotenv.env['BASE_URL']!;

        final response = await http.get(
          Uri.parse('$baseUrl/students?search=$keyword&subject_id=$subjectId'),
        );

        if (response.statusCode == 200) {
          final data =
              List<Map<String, dynamic>>.from(jsonDecode(response.body));

          setDialogState(() {
            students = data;

            // Pre-select already enrolled students
            selectedStudentIds = data
                .where((s) => s['enrolled'] == true)
                .map<int>((s) => s['id'] as int)
                .toList();

            isLoadingStudents = false;
          });
        } else {
          setDialogState(() => isLoadingStudents = false);
        }
      } catch (e) {
        setDialogState(() => isLoadingStudents = false);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Initial fetch
            if (students.isEmpty && !isLoadingStudents) {
              Future.microtask(() => fetchStudents("", setDialogState));
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Enroll Students",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0x80000000)),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (debounce?.isActive ?? false)
                                debounce!.cancel();
                              Navigator.pop(context);
                            },
                            child: const Icon(Icons.close_rounded,
                                color: Colors.black54, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(height: 1, color: Color(0xFFF6F6F6)),
                      const SizedBox(height: 15),

                      // Search field
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: "Search by name or student ID",
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search,
                                color: Color(0xFF1565C0)),
                            onPressed: () {
                              fetchStudents(
                                  searchController.text, setDialogState);
                            },
                          ),
                        ),
                        onChanged: (value) {
                          // Debounce API calls
                          if (debounce?.isActive ?? false) debounce!.cancel();
                          debounce =
                              Timer(const Duration(milliseconds: 500), () {
                            fetchStudents(value, setDialogState);
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Student list
                      Expanded(
                        child: isLoadingStudents
                            ? const Center(child: CircularProgressIndicator())
                            : students.isEmpty
                                ? const Center(child: Text("No students found"))
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 60),
                                    itemCount: students.length,
                                    itemBuilder: (context, index) {
                                      final student = students[index];
                                      final studentId = student['id'] as int;
                                      final isSelected = selectedStudentIds
                                          .contains(studentId);

                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        height: 78,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF7F8FA),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            // Avatar
                                            CircleAvatar(
                                              radius: 25,
                                              backgroundColor:
                                                  const Color(0xFF9E9E9E),
                                              backgroundImage: student[
                                                              'face_image_url'] !=
                                                          null &&
                                                      student['face_image_url']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? NetworkImage(
                                                      student['face_image_url']
                                                          .toString())
                                                  : null,
                                              child: (student['face_image_url'] ==
                                                          null ||
                                                      student['face_image_url']
                                                          .toString()
                                                          .isEmpty)
                                                  ? const Icon(Icons.person,
                                                      color: Colors.white)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),

                                            // Name, ID, course
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student['name'] ?? '--',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15),
                                                  ),
                                                  Text(
                                                    student['student_card_id']
                                                            ?.toString() ??
                                                        '--',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w300,
                                                        fontSize: 12,
                                                        color: Colors.grey),
                                                  ),
                                                  Text(
                                                    student['course']
                                                            ?.toString() ??
                                                        '--',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w300,
                                                        fontSize: 12,
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Checkbox
                                            Checkbox(
                                              value: isSelected,
                                              onChanged: (val) async {
                                                setDialogState(() {
                                                  if (val == true) {
                                                    selectedStudentIds
                                                        .add(studentId);
                                                  } else {
                                                    selectedStudentIds
                                                        .remove(studentId);
                                                  }
                                                });

                                                // If unticked, remove from backend
                                                if (val == false) {
                                                  final baseUrl =
                                                      dotenv.env['BASE_URL']!;
                                                  try {
                                                    final response =
                                                        await http.post(
                                                      Uri.parse(
                                                          '$baseUrl/remove_student'),
                                                      headers: {
                                                        'Content-Type':
                                                            'application/json'
                                                      },
                                                      body: jsonEncode({
                                                        'student_id': studentId,
                                                        'subject_id': subjectId,
                                                      }),
                                                    );
                                                    if (response.statusCode !=
                                                        200) {
                                                      print(
                                                          "Failed to remove student: ${response.body}");
                                                    }
                                                  } catch (e) {
                                                    print(
                                                        "Error removing student: $e");
                                                  }
                                                }
                                              },
                                              checkColor: Colors.white,
                                              fillColor: WidgetStateProperty
                                                  .resolveWith<Color?>(
                                                      (states) {
                                                if (states.contains(
                                                    WidgetState.selected)) {
                                                  return const Color(
                                                      0xFF1565C0);
                                                }
                                                return null;
                                              }),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),

                      const SizedBox(height: 15),

                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: selectedStudentIds.isEmpty
                              ? null
                              : () async {
                                  await _confirmEnrollStudents(
                                    studentIds: selectedStudentIds,
                                    folderId: subjectId,
                                  );
                                  if (mounted) {
                                    if (debounce?.isActive ?? false)
                                      debounce!.cancel();
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(context);
                                    // ignore: use_build_context_synchronously
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Students enrolled successfully")),
                                    );
                                  }
                                },
                          child: const Text(
                            "Confirm",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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

  Future<void> fetchFolders() async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/subjects');
    final dateFormat = DateFormat('dd/MM/yyyy');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          folders = data
              .map((item) => Folder(
                    item['name'],
                    item['created_at'] != null
                        ? dateFormat.parse(item['created_at'])
                        : DateTime.now(),
                    id: item['id'],
                    imageUrl: item['image_url'] != null 
                        ? "${dotenv.env['BASE_URL']}/${item['image_url']}".replaceAll('//', '/')
                        : null,
                  ))
              .toList();
              filteredFolders = folders;
          isLoading = false;
        });
        log('Successfully fetched subjects: ${folders.length} items');
      } else {
        log('Error fetching subjects: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e, stackTrace) {
      log('Error fetching subjects', error: e, stackTrace: stackTrace);
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchFiles(Folder folder) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/subjects/${folder.id}/files');
    final dateFormat = DateFormat('dd/MM/yyyy');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          folder.files = data
              .map((item) => FileItem(
                    item['id'],
                    item['schedule'] ?? 'No Name',
                    item['created_at'] != null
                        ? dateFormat.parse(item['created_at'])
                        : DateTime.now(),
                  ))
              .toList();
        });
        log('Fetched ${folder.files.length} files for ${folder.name}');
      } else {
        log('Error fetching files: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      log('Error fetching files', error: e, stackTrace: stackTrace);
    }
  }

  // Future<void> createFolder(String name) async {
  //   final baseUrl = dotenv.env['BASE_URL']!;
  //   final url = Uri.parse('$baseUrl/subjects');

  //   try {
  //     log("Attempting to create folder: $name at $url");
  //     final response = await http.post(
  //       url,
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"name": name}),
  //     );
  //     log("Response status: ${response.statusCode}");
  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       log('Folder created successfully');
  //       fetchFolders();
  //     } else {
  //       log('Failed to create folder: ${response.body}');
  //     }
  //   } catch (e) {
  //     log('Error creating folder', error: e);
  //   }
  // }

  Future<void> _pickImage(StateSetter setDialogState) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setDialogState(() {
        _pickedFile = image;
      });
    }
  }

  Future<void> createFolder(String name, XFile? imageFile) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/subjects');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId; // <-- get userId from provider

    if (userId == null) {
      log("User not logged in, cannot create folder");
      return;
    }

    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['name'] = name;
      request.fields['user_id'] = userId.toString();

      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        log('Folder created successfully');
        fetchFolders();
      } else {
        log('Failed to create folder: ${response.body}');
      }
    } catch (e) {
      log('Error creating folder', error: e);
    }
  }

  Future<void> updateFolder(int id, String name, XFile? imageFile) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final url = Uri.parse('$baseUrl/subjects/$id');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        log('Folder updated successfully');
        fetchFolders();
      } else {
        log('Failed to update folder: ${response.body}');
      }
    } catch (e) {
      log('Error updating folder', error: e);
    }
  }

  Future<void> deleteFolder(int id) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    // Pass userId as query parameter
    final url = Uri.parse('$baseUrl/subjects/$id?user_id=$userId');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        log('Folder deleted successfully');
        fetchFolders();
      } else {
        log('Failed to delete folder: ${response.body}');
      }
    } catch (e) {
      log('Error deleting folder', error: e);
    }
  }

  Future<void> createFile(int folderId, String name) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    // Pass userId as query parameter
    final url = Uri.parse('$baseUrl/subjects/$folderId/files?user_id=$userId');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('File created successfully');
        final folderIndex = folders.indexWhere((f) => f.id == folderId);
        if (folderIndex != -1) fetchFiles(folders[folderIndex]);
      } else {
        log('Failed to create file: ${response.body}');
      }
    } catch (e) {
      log('Error creating file', error: e);
    }
  }

  Future<void> updateFile(Folder folder, int fileId, String name) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    // Pass userId as query parameter
    final url = Uri.parse('$baseUrl/classes/$fileId?user_id=$userId');

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name}),
      );

      if (response.statusCode == 200) {
        log('File updated successfully');
        fetchFiles(folder);
      } else {
        log('Failed to update file: ${response.body}');
      }
    } catch (e) {
      log('Error updating file', error: e);
    }
  }

  Future<void> deleteFile(Folder folder, int fileId) async {
    final baseUrl = dotenv.env['BASE_URL']!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    // Pass userId as query parameter
    final url = Uri.parse('$baseUrl/classes/$fileId?user_id=$userId');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        log('File deleted successfully');
        fetchFiles(folder);
      } else {
        log('Failed to delete file: ${response.body}');
      }
    } catch (e) {
      log('Error deleting file', error: e);
    }
  }

  void _showFolderDialog({Folder? folder, bool isEdit = false}) {
    final TextEditingController nameController =
        TextEditingController(text: folder?.name ?? '');
    _pickedFile = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder( // Added StatefulBuilder to update image preview inside dialog
          builder: (context, setDialogState) {
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
                    Text(
                      isEdit ? "Edit Group" : "New Group",
                      style: const TextStyle(
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
                GestureDetector(
                  onTap: () => _pickImage(setDialogState), // Trigger picker
                  child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),

                        image: _pickedFile != null 
                                ? DecorationImage(image: FileImage(File(_pickedFile!.path)), fit: BoxFit.cover)
                                : null,
                      ),
                      child: _pickedFile == null
                          ? const Icon(Icons.image, size: 40, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pickedFile != null ? "Change Picture" : "Upload Picture",
                          style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          "JPG or PNG, max 5MB",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: "Enter Group Name",
                    hintStyle:
                        const TextStyle(color: Colors.grey, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                      if (nameController.text.isNotEmpty) {
                        if (isEdit && folder != null) {
                          if (folder.id != null) {
                            await updateFolder(folder.id!, nameController.text, _pickedFile);
                          }
                        } else {
                          await createFolder(nameController.text, _pickedFile);
                        }
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(
                      isEdit ? "Confirm Changes" : "Create",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFileDialog(Folder folder, {FileItem? file, bool isEdit = false}) {
    // Controllers for the time fields
    final TextEditingController startTimeController = TextEditingController();
    final TextEditingController endTimeController = TextEditingController();

    // Helper function to pick time
    Future<void> _selectTime(TextEditingController controller) async {
      TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: Theme(
              data: Theme.of(context).copyWith(
                useMaterial3: true,
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1565C0),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black,
                ),
                timePickerTheme: TimePickerThemeData(
                  // Header Style
                  helpTextStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),

                  // Keyboard Icon
                  entryModeIconColor: Colors.black,

                  // AM/PM Styles
                  dayPeriodBorderSide:
                      const BorderSide(color: Color(0xFFE0E0E0)),
                  dayPeriodColor: WidgetStateColor.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFFE3F2FD) // Light Blue background
                          : Colors.white),
                  dayPeriodTextColor: WidgetStateColor.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFF1565C0) // Selected text color
                          : Colors.black),

                  // Hour/Minute Styles
                  hourMinuteColor: WidgetStateColor.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? const Color(0xFFE3F2FD)
                          : const Color(0xFFEEEEEE)),
                  hourMinuteTextColor: WidgetStateColor.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFF1565C0) // Selected text color
                          : Colors.black), // Unselected text color (Black)
                  hourMinuteTextStyle: const TextStyle(
                      fontSize: 50, fontWeight: FontWeight.w500),
                  hourMinuteShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  // Dial Styles (The Clock)
                  dialBackgroundColor: const Color(0xFFF0F0F0),
                  dialHandColor: const Color(0xFF1565C0),
                  dialTextStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w500),

                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                // FIXED: Only one textButtonTheme allowed
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.only(bottom: 5, top: 20),
                  ),
                ),
              ),

              // Using Transform.scale is the safest way to make the dial background bigger
              // without triggering "undefined parameter" errors.
              child: Center(
                child: Transform.scale(
                  scale: 1.0,
                  child: child!,
                ),
              ),
            ),
          );
        },
      );

      if (picked != null) {
        final now = DateTime.now();
        final dt =
            DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        setState(() {
          controller.text =
              DateFormat('hh:mm a').format(dt); // Forces "08:30 AM"
        });
      }
    }

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
                    Text(
                      isEdit ? "Edit Schedule Time" : "New Schedule Time",
                      style: const TextStyle(
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
                Container(
                  height: 1,
                  color: const Color(0xFFF6F6F6),
                ),
                const SizedBox(height: 15),

                // Start Time Field
                _buildTimeField("Select Start Time", startTimeController,
                    () => _selectTime(startTimeController)),

                const SizedBox(height: 12),

                // End Time Field
                _buildTimeField("Select End Time", endTimeController,
                    () => _selectTime(endTimeController)),

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
                      if (startTimeController.text.isNotEmpty &&
                          endTimeController.text.isNotEmpty) {
                        String combinedName =
                            "${startTimeController.text} - ${endTimeController.text}";
                        if (isEdit && file != null) {
                          await updateFile(folder, file.id, combinedName);
                        } else if (folder.id != null) {
                          await createFile(folder.id!, combinedName);
                        }
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(
                      isEdit ? "Save Changes" : "Create",
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

  // Helper widget to maintain the UI style in your image
  Widget _buildTimeField(
      String hint, TextEditingController controller, VoidCallback onTap) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
        suffixIcon:
            const Icon(Icons.access_time_rounded, color: Color(0xFF1565C0)),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showDeleteDialog(dynamic item, {bool isFile = false, Folder? folder}) {
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
                Text(
                  "Do you really want to delete this ${isFile ? 'schedule time' : 'group'}?\nThis process cannot be undone.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
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
                        onPressed: () async {
                          if (isFile && folder != null) {
                            FileItem file = item as FileItem;
                            await deleteFile(folder, file.id);
                          } else {
                            Folder fold = item as Folder;
                            if (fold.id != null) {
                              await deleteFolder(fold.id!);
                            }
                          }
                          if (mounted) Navigator.pop(context);
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // Makes entire body tappable
        onTap: () {
          FocusScope.of(context).unfocus(); // Close keyboard
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    TextField(
                      controller: groupSearchController,
                      onChanged: _filterGroups,
                      decoration: InputDecoration(
                        hintText: "Search",
                        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                        suffixIcon: groupSearchController.text.isEmpty
                            ? const Icon(Icons.search, color: Color(0x4D000000))
                            : IconButton( // REMARK: Added a clear button for better UX
                                icon: const Icon(Icons.clear, color: Color(0xFF1565C0)),
                                onPressed: () {
                                  groupSearchController.clear();
                                  _filterGroups("");
                                },
                              ),
                        contentPadding: const EdgeInsets.only(
                            left: 10, top: 12, bottom: 12),
                        filled: true,
                        fillColor: const Color(0xFFF6F6F6),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0x1A000000), width: 1)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFFF6F6F6), width: 1)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Groups",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: filteredFolders.isEmpty ? (groupSearchController.text.isEmpty ? 2 : 1) : filteredFolders.length + 1,
                        itemBuilder: (context, index) {

                          if (filteredFolders.isEmpty && groupSearchController.text.isNotEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: Text("No matching groups found", style: TextStyle(color: Colors.grey))),
                            );
                          }

                          if (folders.isEmpty && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  "No groups created yet.\nTap the add button below to start.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          }

                          if ((filteredFolders.isEmpty && index == 1) || (filteredFolders.isNotEmpty && index == filteredFolders.length)) {
                            return Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Material(
                                  color: const Color(0xFF1565C0),
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

                          final folder = filteredFolders[index];

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
                              child: const Icon(Icons.edit_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            secondaryBackground: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF84F31),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete_rounded,
                                  color: Colors.white, size: 24),
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
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (!folder.isExpanded &&
                                        folder.files.isEmpty) {
                                      await fetchFiles(folder);
                                    }
                                    setState(() =>
                                        folder.isExpanded = !folder.isExpanded);
                                  },
                                  child: Container(
                                    height: 105,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F8FA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 5),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0x1A000000),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                    image: folder.imageUrl != null && folder.imageUrl!.isNotEmpty
                                                      ? DecorationImage(
                                                          image: NetworkImage(folder.imageUrl!),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null,
                                              ),
                                              child: folder.imageUrl == null || folder.imageUrl!.isEmpty
                                                  ? const Icon(Icons.folder, color: Colors.grey, size: 20)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    folder.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  Text(
                                                    "Last updated on ${folder.date.day.toString().padLeft(2, '0')}/"
                                                    "${folder.date.month.toString().padLeft(2, '0')}/"
                                                    "${folder.date.year}",
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              folder.isExpanded
                                                  ? Icons
                                                      .keyboard_arrow_up_rounded
                                                  : Icons
                                                      .keyboard_arrow_down_rounded,
                                              color: const Color(0xE6000000),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                _showEnrollStudentDialog(
                                                    folder.id!);
                                              },
                                              icon: const Icon(
                                                Icons.person,
                                                color: Color(0xB3000000),
                                                size: 20,
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              color: const Color(0x1A000000),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _showFolderDialog(
                                                      folder: folder,
                                                      isEdit: true),
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                                color: Color(0xFF1565C0),
                                                size: 20,
                                              ),
                                            ),
                                            Container(
                                              width: 1,
                                              height: 20,
                                              color: const Color(0x1A000000),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _showDeleteDialog(folder),
                                              icon: const Icon(
                                                Icons.delete_rounded,
                                                color: Color(0xFFF84F31),
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (folder.isExpanded)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 0),
                                    child: Column(
                                      children: [
                                        for (var file in folder.files)
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      Attendance(
                                                    classId: file.id,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              height: 60,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF7F8FA),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 15),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          file.name,
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                        Text(
                                                          "Last Updated on ${file.date.day.toString().padLeft(2, '0')}/${file.date.month.toString().padLeft(2, '0')}/${file.date.year}",
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(
                                                        Icons.more_vert_rounded,
                                                        size: 20),
                                                    color: Color(0xE61565C0),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    onSelected: (value) {
                                                      if (value == 'edit') {
                                                        _showFileDialog(folder,
                                                            file: file,
                                                            isEdit: true);
                                                      } else if (value ==
                                                          'delete') {
                                                        _showDeleteDialog(file,
                                                            isFile: true,
                                                            folder: folder);
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
                                                      PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: const [
                                                            Icon(
                                                                Icons
                                                                    .edit_rounded,
                                                                color: Colors
                                                                    .white,
                                                                size: 20),
                                                            SizedBox(width: 5),
                                                            Text('Edit',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white)),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: const [
                                                            Icon(
                                                                Icons
                                                                    .delete_rounded,
                                                                color: Colors
                                                                    .white,
                                                                size: 20),
                                                            SizedBox(width: 5),
                                                            Text('Delete',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color:
                                                      const Color(0x1A000000),
                                                  width: 1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: TextButton.icon(
                                              onPressed: () =>
                                                  _showFileDialog(folder),
                                              icon: const Icon(
                                                  Icons.add_rounded,
                                                  color: Color(0xFF1565C0),
                                                  size: 18),
                                              label: const Text(
                                                "Add New Schedule Time",
                                                style: TextStyle(
                                                  color: Color(0xFF1565C0),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
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
            Navigator.pushNamed(context, '/dashboard');
          } else if (index == 1) {
            Navigator.pushNamed(context, '/enroll');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/reports');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/settings');
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
    );
  }
}

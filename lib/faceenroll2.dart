import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import 'package:userinterface/faceenroll.dart';
import 'package:userinterface/providers/auth_provider.dart';

class EnrollmentPage extends StatefulWidget {
  // final String imagePath;
  final List<String> imagePaths;

  const EnrollmentPage({super.key, required this.imagePaths});

  @override
  State<EnrollmentPage> createState() => _EnrollmentPageState();
}

class _EnrollmentPageState extends State<EnrollmentPage> {
  String? selectedSubjectId;
  List<Map<String, dynamic>> subjects = [];
  int _currentImageIndex = 0;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController idController = TextEditingController();
  final TextEditingController courseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // fetchSubjects();
  }

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    courseController.dispose();
    super.dispose();
  }

  // ---------- FETCH SUBJECTS FROM BACKEND ----------
  // Future<void> fetchSubjects() async {
  //   try {
  //     final baseUrl = dotenv.env['BASE_URL'] ?? '';
  //     if (baseUrl.isEmpty) return;

  //     var uri = Uri.parse('$baseUrl/subjects');
  //     var response = await http.get(uri);

  //     log("Subjects API Response (${response.statusCode}): ${response.body}");

  //     if (response.statusCode == 200) {
  //       final List<dynamic> data = jsonDecode(response.body);
  //       setState(() {
  //         subjects = data.cast<Map<String, dynamic>>();
  //       });
  //     } else {
  //       log("Failed to fetch subjects: ${response.statusCode}");
  //     }
  //   } catch (e, stackTrace) {
  //     log("Error fetching subjects", error: e, stackTrace: stackTrace);
  //   }
  // }

  // ----------- ENROLL STUDENT FUNCTION -------------
  Future<void> enrollStudent() async {
    if (nameController.text.isEmpty ||
        idController.text.isEmpty ||
        courseController.text.isEmpty) {
      _showAnimatedDialog(
        context: context,
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red,
        title: "Validation Error",
        message: "Please fill in all required fields.",
        buttonText: "Close",
        onPressed: () => Navigator.of(context).pop(),
      );
      return;
    }

    try {
      _showLoadingDialog(context);

      final baseUrl = dotenv.env['BASE_URL'] ?? '';
      if (baseUrl.isEmpty) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      var uri = Uri.parse('$baseUrl/enroll');
      var request = http.MultipartRequest("POST", uri);

      request.fields["name"] = nameController.text;
      request.fields["student_card_id"] = idController.text;
      request.fields["course"] = courseController.text;
      request.fields["primary_index"] = _currentImageIndex.toString();
      request.fields["user_id"] = userId.toString();

      if (widget.imagePaths.isNotEmpty) {
        for (var imagePath in widget.imagePaths) {
          final file = File(imagePath);
          log("Sending file: $imagePath, exists: ${file.existsSync()}, size: ${file.existsSync() ? file.lengthSync() : 0} bytes");

          if (file.existsSync()) {
            request.files.add(await http.MultipartFile.fromPath(
              "images", // must match backend getlist("images")
              imagePath,
              filename: path.basename(imagePath),
            ));
          }
        }
      }

      var response = await request.send();
      var responseBody = await http.Response.fromStream(response);

      if (mounted) _hideLoadingDialog(context);

      if (responseBody.statusCode == 201 || responseBody.statusCode == 200) {
        if (mounted) {
          _showAnimatedDialog(
            context: context,
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF00B38A),
            title: "Enrollment Successful",
            message: "Student has been enrolled successfully.",
            buttonText: "Continue",
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Enrollment()),
              );
            },
          );
        }
      } else {
        if (mounted) {
          _showAnimatedDialog(
            context: context,
            icon: Icons.error_outline_rounded,
            iconColor: Colors.red,
            title: "Enrollment Failed",
            message:
                "Error: ${responseBody.body.isNotEmpty ? responseBody.body : responseBody.statusCode}",
            buttonText: "Close",
            onPressed: () => Navigator.of(context).pop(),
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) _hideLoadingDialog(context);
      log("Error enrolling student", error: e, stackTrace: stackTrace);
      if (mounted) {
        _showAnimatedDialog(
          context: context,
          icon: Icons.error_outline_rounded,
          iconColor: Colors.red,
          title: "Enrollment Failed",
          message: "An unexpected error occurred.",
          buttonText: "Close",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
    }
  }

  void _showAnimatedDialog({
    required BuildContext context,
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

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          // <-- Wrap Column to prevent overflow
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const Enrollment()),
                    );
                  },
                ),
                const SizedBox(height: 0),
                // Profile Image Preview
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1565C0),
                    ),
                    child: widget.imagePaths.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 100)
                        : ClipOval(
                            child: PageView.builder(
                              itemCount: widget.imagePaths.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return Image.file(
                                  File(widget.imagePaths[index]),
                                  fit: BoxFit.cover,
                                );
                              },
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                // 🔵 Swipe indicator dots
                if (widget.imagePaths.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.imagePaths.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentImageIndex == index ? 12 : 8,
                        height: _currentImageIndex == index ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == index
                              ? const Color(0xFF1565C0)
                              : Colors.grey,
                        ),
                      );
                    }),
                  ),

                const SizedBox(height: 20),
                // Student Details
                SizedBox(
                    height: 50,
                    child:
                        _buildTextField("Enter student name", nameController)),
                const SizedBox(height: 10),
                SizedBox(
                    height: 50,
                    child: _buildTextField("Enter student ID", idController)),
                const SizedBox(height: 10),
                SizedBox(
                    height: 50,
                    child: _buildTextField(
                        "Enter student course", courseController)),
                const SizedBox(height: 15),
                // Dropdown (Subjects) HIDDEN!
                Visibility(
                  visible: false,
                  child: SizedBox(
                    height: 50,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          hint: const Text("Select subject..",
                              style: TextStyle(color: Colors.grey)),
                          value: selectedSubjectId,
                          items: subjects.map((subject) {
                            return DropdownMenuItem<String>(
                              value: subject['id'].toString(),
                              child: Text(subject['name']),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedSubjectId = value),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey),
                          isExpanded: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                    height: 20), // optional spacing before bottom nav
              ],
            ),
          ),
        ),
      ),
      // ----------- BottomNavigationBar with Enroll button -----------
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Enroll button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: enrollStudent,
                child: const Text(
                  "Enroll",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // BottomNavigationBar
          BottomNavigationBar(
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
                Navigator.pushReplacementNamed(context, '/dashboard');
              } else if (index == 1) {
                // Stay on Enrollment
              } else if (index == 2) {
                Navigator.pushReplacementNamed(context, '/reports');
              } else if (index == 3) {
                Navigator.pushReplacementNamed(context, '/settings');
              }
            },
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.space_dashboard_rounded),
                  label: 'Dashboard'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.camera_alt_rounded), label: 'Enrollment'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

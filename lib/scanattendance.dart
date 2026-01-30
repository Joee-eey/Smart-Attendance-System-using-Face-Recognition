import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:userinterface/attendance.dart';

class ScanAttendance extends StatefulWidget {
  final int classId;
  const ScanAttendance({super.key, required this.classId});

  @override
  State<ScanAttendance> createState() => _ScanAttendanceState();
}

class _ScanAttendanceState extends State<ScanAttendance> {
  bool showSettings = false;
  bool showGrid = false;
  bool soundOn = false;
  bool flashOn = false;
  bool _isCameraReady = false;
  bool _isInitializing = false;

  int currentCameraIndex = 0;
  CameraController? _controller;
  List<CameraDescription>? cameras;

  final ImagePicker _picker = ImagePicker();

  XFile? _capturedImage; // Store captured or picked image for preview

  @override
  void initState() {
    super.initState();
    _initializeCameraList();
  }

  Future<void> _initializeCameraList() async {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        await _initializeCamera(cameras![currentCameraIndex]);
      }
    } catch (e) {
      debugPrint("Error fetching cameras: $e");
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    if (_isInitializing) return;
    setState(() => _isInitializing = true);

    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
    }
    _controller = CameraController(camera, ResolutionPreset.medium, enableAudio: false,);

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => flashOn = !flashOn);
    await _controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
  }

  void _switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    final currentLens = cameras![currentCameraIndex].lensDirection;
    final newIndex = cameras!.indexWhere((camera) =>
        camera.lensDirection == (currentLens == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front));
    if (newIndex == -1) return;

    setState(() {
      currentCameraIndex = newIndex;
      _isCameraReady = false;
    });

    await _initializeCamera(cameras![currentCameraIndex]);
  }

  void _capturePhoto() async {
    if (!_isCameraReady || _controller == null || _controller!.value.isTakingPicture) return;

    try {
      final XFile image = await _controller!.takePicture();
      await _controller!.pausePreview();
      setState(() => _capturedImage = image);
    } catch (e) {
      debugPrint("Error capturing photo: $e");
    }
  }

  void _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        if (_controller != null) await _controller!.pausePreview();
        setState(() => _capturedImage = pickedFile);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _retakeImage() async {
    setState(() {
      _capturedImage = null;
      _isCameraReady = false;
    });

    if (_controller != null) {
      await _controller!.resumePreview();
      setState(() => _isCameraReady = true);
    } else {
      _initializeCamera(cameras![currentCameraIndex]);
    }
  }

  Future<void> _confirmImage() async {
    if (_capturedImage == null) return;

    setState(() => _isCameraReady = false);
    
    if (_controller != null) {
      await _controller!.pausePreview();
    }
    await _processImage(_capturedImage!.path);
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final uri = Uri.parse('$baseUrl/recognize');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      request.fields['class_id'] = widget.classId.toString();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF1565C0)),
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;
      Navigator.of(context).pop(); 

      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody) as List;
        final recognizedCount = result.where((r) => r["name"] != null).length;

        _showAnimatedDialog(
          context: context,
          icon: Icons.check_circle_outline_rounded,
          iconColor: Colors.green,
          title: "Success",
          message: "$recognizedCount students recognized successfully.",
          buttonText: "OK",
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => Attendance(classId: widget.classId)),
            );
          },
        );
      } else {
        _showAnimatedDialog(
          context: context,
          icon: Icons.error_outline,
          iconColor: Colors.red,
          title: "Error",
          message: "Recognition failed: $responseBody",
          buttonText: "OK",
          onPressed: () => Navigator.of(context).pop(),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (!mounted) return;
      _showAnimatedDialog(
        context: context,
        icon: Icons.error_outline,
        iconColor: Colors.red,
        title: "Error",
        message: "Something went wrong: $e",
        buttonText: "OK",
        onPressed: () => Navigator.of(context).pop(),
      );
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
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSwitch(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Container(
            width: 32,
            height: 16,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF1565C0) : Colors.grey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 150),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      bottomNavigationBar: _buildBottomNavigationBar(),
      body: _capturedImage != null ? _buildPreview() : Column(
        children: [
          _buildTopBar(),
          Expanded(child: _buildCameraView()),
          _buildCaptureControls(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(16, 35, 16, 10),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () async {
                if (_controller != null) {
                  await _controller!.dispose();
                  _controller = null;
                }
                Navigator.pop(context);
              },
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 28)),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleFlash,
                  child: Icon(flashOn ? Icons.flash_on : Icons.flash_off,
                      color: flashOn ? Colors.yellow : Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => showSettings = !showSettings),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 26),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return GestureDetector(
      onTap: () { if (showSettings) setState(() => showSettings = false); },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isCameraReady && _controller != null && _controller!.value.isInitialized)
          SizedBox.expand( // Fills the available space
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            )
          )
          else
            Container(color: Colors.grey[200]),
          if (showGrid)
            IgnorePointer(child: CustomPaint(size: Size.infinite, painter: GridPainter())),
          if (showSettings) _buildSettingsPanel(),
        ],
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Positioned(
      top: 0,
      right: 12,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBC04A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 18)),
            const SizedBox(height: 6),
            Container(height: 1, color: Colors.white, margin: const EdgeInsets.only(bottom: 5)),
            const SizedBox(height: 5),
            _buildCustomSwitch("Grid", showGrid, (v) => setState(() => showGrid = v)),
            _buildCustomSwitch("Sound", soundOn, (v) => setState(() => soundOn = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Container(
      color: const Color(0xFF1565C0),
      height: 85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 12,
            child: GestureDetector(onTap: _capturePhoto,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4))),
                  Container(width: 50, height: 50, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 40,
            bottom: 18,
            child: GestureDetector(onTap: _pickImageFromGallery,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle)),
                  const Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
                ],
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: 18,
            child: GestureDetector(onTap: _switchCamera,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle)),
                  const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.white, width: 1))),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
        onTap: (index) async {
          if (_controller != null) {
            await _controller!.pausePreview();
            await _controller!.dispose();
            _controller = null;
          }

          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/enroll');
          if (index == 2) Navigator.pushNamed(context, '/reports');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: 'Enrollment'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      children: [
        SizedBox.expand(child: Image.file(File(_capturedImage!.path), fit: BoxFit.contain)),
        Positioned(top: 35, left: 16, child: GestureDetector(onTap: _retakeImage, child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28))),
        Positioned(
          bottom: 40,
          left: 50,
          child: GestureDetector(
            onTap: _retakeImage,
            child: Column(children: const [Icon(Icons.refresh_rounded, color: Colors.white, size: 40), SizedBox(height: 5), Text("Retake", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
          ),
        ),
        Positioned(
          bottom: 40,
          right: 50,
          child: GestureDetector(
            onTap: _confirmImage,
            child: Column(children: const [Icon(Icons.check_circle_rounded, color: Colors.white, size: 40), SizedBox(height: 5), Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]),
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = 1;
    double stepX = size.width / 3;
    double stepY = size.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(stepX * i, 0), Offset(stepX * i, size.height), linePaint);
      canvas.drawLine(Offset(0, stepY * i), Offset(size.width, stepY * i), linePaint);
    }
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

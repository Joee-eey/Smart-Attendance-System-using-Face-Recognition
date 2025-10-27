import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final cameras = await availableCameras();
  runApp(Enrollment(cameras: cameras));
}

class Enrollment extends StatelessWidget {
  final List<CameraDescription> cameras;

  const Enrollment({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enrollment',
      theme: ThemeData(primaryColor: const Color(0xFF1565C0)),
      home: ScannerScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScannerScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ScannerScreen({super.key, required this.cameras});

  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool showSettings = false;
  bool showGrid = false;
  bool soundOn = false;
  bool flashOn = false;
  bool _isCameraReady = false;

  int currentCameraIndex = 0;
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _initializeCamera(widget.cameras[currentCameraIndex]);
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(
        flashOn ? FlashMode.torch : FlashMode.off,
      );

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => flashOn = !flashOn);
    await _controller!.setFlashMode(
      flashOn ? FlashMode.torch : FlashMode.off,
    );
  }


  void _switchCamera() async {
    if (widget.cameras.length < 2) return;

    final currentLensDirection =
        widget.cameras[currentCameraIndex].lensDirection;

    final newIndex = widget.cameras.indexWhere((camera) =>
        camera.lensDirection ==
        (currentLensDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front));

    if (newIndex == -1) return;

    setState(() {
      currentCameraIndex = newIndex;
      _isCameraReady = false;
    });

    await _initializeCamera(widget.cameras[currentCameraIndex]);
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
      backgroundColor: Colors.white,

    
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.white, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF1565C0),
          unselectedItemColor: Colors.grey,
          currentIndex: 1,
          onTap: (index) {},
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'Dashboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart), label: 'Reports'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),

      body: Column(
        children: [
          Container(
            color: const Color(0xFF1565C0),
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 10),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.close, color: Colors.white, size: 28),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleFlash,
                        child: Icon(
                          flashOn ? Icons.flash_on : Icons.flash_off,
                          color: flashOn ? Colors.yellow : Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),

                      GestureDetector(
                        onTap: () {
                          setState(() {
                            showSettings = !showSettings;
                          });
                        },
                        child: const Icon(Icons.more_vert,
                            color: Colors.white, size: 26),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: () {
                if (showSettings) setState(() => showSettings = false);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isCameraReady && _controller != null)
                    ClipRect(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.previewSize!.height,
                          height: _controller!.value.previewSize!.width,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    )
                  else
                    Container(color: Colors.grey[200]),

                  if (showGrid)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: GridPainter(),
                      ),
                    ),

                  if (showSettings)
                    Positioned(
                      top: 0,
                      right: 12,
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBC04A).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Settings",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 1,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 5),
                            ),
                            const SizedBox(height: 5),
                            _buildCustomSwitch("Grid", showGrid, (v) {
                              setState(() => showGrid = v);
                            }),
                            _buildCustomSwitch("Sound", soundOn, (v) {
                              setState(() => soundOn = v);
                            }),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Container(
            color: const Color(0xFF1565C0),
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                      ),
                      Container(
                        width: 55,
                        height: 55,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: 35,
                  child: GestureDetector(
                    onTap: _switchCamera,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Icon(Icons.cameraswitch_rounded,
                            color: Colors.white, size: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    double stepX = size.width / 3;
    double stepY = size.height / 3;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
          Offset(stepX * i, 0), Offset(stepX * i, size.height), linePaint);
      canvas.drawLine(
          Offset(0, stepY * i), Offset(size.width, stepY * i), linePaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

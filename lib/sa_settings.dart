import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:userinterface/providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

/*void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SuperAdminSettingsApp());
}*/

class SuperAdminSettingsApp extends StatelessWidget {
  const SuperAdminSettingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SA - Settings',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: false,
      ),
      home: const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: SuperAdminSettingsPage(),
      ),
    );
  }
}

class SuperAdminSettingsPage extends StatefulWidget {
  const SuperAdminSettingsPage({super.key});

  @override
  State<SuperAdminSettingsPage> createState() => _SuperAdminSettingsPageState();
}

class _SuperAdminSettingsPageState extends State<SuperAdminSettingsPage> {
  // bool googleSSO = true;
  // bool microsoftSSO = false;

  bool enableAutoPurge = true;
  // double retentionDays = 30;

  // Define the specific allowed values
  final List<int> _retentionOptions = [7, 96, 180, 275, 365];
  
  // Track the current index (0 to 4) instead of the raw day count
  int _currentStep = 0; 

  // Helper to get actual days from the current step
  int get retentionDays => _retentionOptions[_currentStep];

  Future<void> _handlePurge({required bool isManual}) async {
    try {
      final baseUrl = dotenv.env['BASE_URL']!;
      final url = Uri.parse('$baseUrl/sa/logs/purge'); 
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'manual': isManual,
          'enable_auto': enableAutoPurge,
          'retention_days': retentionDays,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isManual ? "Logs purged successfully!" : "Settings saved.")),
        );
      }
    } catch (e) {
      debugPrint("Purge error: $e");
    }
  }

  // Manual Purge Confirmation Dialog
  void _showManualPurgeDialog() {
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
                const Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFEB3349),
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Purge All Logs Data",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Do you really want to delete all logs?\nThis process cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
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
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEB3349),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          // Perform manual purge logic here
                          Navigator.pop(context);
                          _handlePurge(isManual: true);
                        },
                        child: const Text(
                          "Purge Now",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
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
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 50),

            // ================= Authentication =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x1A000000)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Authentication Management",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0x50000000),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: const Color(0x1A000000)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Google SSO", style: TextStyle(fontSize: 14)),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          /*value: googleSSO,
                          activeThumbColor: const Color(0xFF1565C0),
                          activeTrackColor: const Color(0x331565C0),
                          inactiveThumbColor: Colors.grey.shade400,
                          inactiveTrackColor: Colors.grey.shade300,
                          splashRadius: 0,
                          trackOutlineColor:
                              WidgetStateProperty.all(Colors.transparent),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setState(() => googleSSO = v),*/
                          value: authProvider.googleSSOEnabled,
                          activeThumbColor: const Color(0xFF1565C0),
                          onChanged: (v) => authProvider.setGoogleSSO(v),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Microsoft SSO",
                          style: TextStyle(fontSize: 14)),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          /* value: microsoftSSO,
                          activeThumbColor: const Color(0xFF1565C0),
                          activeTrackColor: const Color(0x331565C0),
                          inactiveThumbColor: Colors.grey.shade400,
                          inactiveTrackColor: Colors.grey.shade300,
                          splashRadius: 0,
                          trackOutlineColor:
                              WidgetStateProperty.all(Colors.transparent),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) => setState(() => microsoftSSO = v),*/
                          value: authProvider.microsoftSSOEnabled,
                          activeThumbColor: const Color(0xFF1565C0),
                          onChanged: (v) => authProvider.setMicrosoftSSO(v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ================= Security & Privacy =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x1A000000)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Security & Privacy",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0x50000000),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: const Color(0x1A000000)),
                  const SizedBox(height: 12),
                  const Text(
                    "Logs Retention",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Configure log data retention settings to ensure secure deletion after a specified period.",
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Enable Auto-Purge",
                          style: TextStyle(fontSize: 14)),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: enableAutoPurge,
                          activeThumbColor: const Color(0xFF1565C0),
                          activeTrackColor: const Color(0x331565C0),
                          inactiveThumbColor: Colors.grey.shade400,
                          inactiveTrackColor: Colors.grey.shade300,
                          splashRadius: 0,
                          trackOutlineColor:
                              WidgetStateProperty.all(Colors.transparent),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: (v) {
                            setState(() => enableAutoPurge = v);
                            _handlePurge(isManual: false); 
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Retention Period",
                                style: TextStyle(fontSize: 13)),
                            Text(
                              "Purge After ${retentionDays.toInt()} days",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Slider(
                          value: _currentStep.toDouble(),
                          min: 0,
                          max: 4,
                          divisions: 4,
                          activeColor: const Color(0xFF1565C0),
                          inactiveColor: Colors.grey.shade300,
                          onChanged: enableAutoPurge ? (v) {
                            /* double snappedValue;
                            if (v < 90) snappedValue = 7;
                            else if (v < 270) snappedValue = 180;
                            else snappedValue = 365;

                            setState(() => retentionDays = snappedValue);
                            _handlePurge(isManual: false);
                          } : null,*/
                          setState(() {
                              _currentStep = v.toInt();
                            });
                          } : null,
                          onChangeEnd: (v) {
                            // Only trigger API call when user releases the slider
                            _handlePurge(isManual: false);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text("7 Days",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text("180 Days",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            Text("1 Year",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(height: 1, color: const Color(0x1A000000)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEB3349),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showManualPurgeDialog,
                      child: const Text(
                        "Manual Purge Now",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "MANUAL PURGE IMMEDIATELY DELETES ALL LOGS DATA OLDER THAN THE SET RETENTION PERIOD. THIS ACTION CANNOT BE UNDONE.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:userinterface/login.dart';
import 'package:userinterface/signup.dart';
import 'package:userinterface/faceenroll.dart';
import 'package:userinterface/faceenroll.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:userinterface/dashboard.dart';
import 'package:userinterface/reports.dart';
import 'package:userinterface/settings.dart';
import 'package:userinterface/dashboard.dart';
import 'package:userinterface/reports.dart';
import 'package:userinterface/settings.dart';


Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const SmartAttendanceApp());
}

class SmartAttendanceApp extends StatelessWidget {
  const SmartAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cheese!',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1565C0),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      ),
       routes: {
        '/dashboard': (context) => const DashboardPage(),  
        '/enroll': (context) => const Enrollment(),
        '/reports': (context) => const AttendanceReportPage(),      
        '/settings': (context) => const AccountSettingsPage(),  
      },
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/cheese_logo.png',
                width: 180,
                height: 180,
              ),
              Text(
                'Effortlessly track attendance with our advanced face recognition technology.',
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 🔹 Log in Button → Go to LoginPage
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 🔹 Sign Up Button → Go to SignUpPage
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.transparent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: const Color(0x1A1565C0),
                    elevation: 0,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignupPage()),
                    );
                  },
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

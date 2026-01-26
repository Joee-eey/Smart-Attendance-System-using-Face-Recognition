import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); 
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: Color(0xFF1565C0),
    systemNavigationBarIconBrightness: Brightness.light, 
    statusBarColor: Color(0xFF1565C0), 
    statusBarIconBrightness: Brightness.light, 
  ));

  runApp(SuperAdminLoginApp());
}

class SuperAdminLoginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF1565C0),
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Color(0xFF1565C0),
        statusBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Super Admin Login',
        theme: ThemeData(
          primaryColor: Color(0xFF1565C0),
          scaffoldBackgroundColor: Color(0xFF1565C0),
        ),
        home: SuperAdminLoginPage(),
      ),
    );
  }
}

class SuperAdminLoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Key icon
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(0xFFF4B942), width: 3),
                  ),
                  padding: EdgeInsets.all(20),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: Color(0xFFF4B942),
                    size: 50,
                  ),
                ),
                SizedBox(height: 20),

                // Title
                Text(
                  'Super Admin Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),

                // Subtitle
                Text(
                  'Enter your credentials to access the admin dashboard',
                  style: TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),

                // Email 
                SizedBox(
                  height: 48, 
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Color(0xB3FFFFFF), fontSize: 15), 
                      filled: true,
                      fillColor: Color(0x1A000000),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    style: TextStyle(color: Color(0xB3FFFFFF)), 
                  ),
                ),
                SizedBox(height: 15),

                // Password
                SizedBox(
                  height: 48, 
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Color(0xB3FFFFFF), fontSize: 15), 
                      filled: true,
                      fillColor: Color(0x1A000000),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    style: TextStyle(color: Color(0xB3FFFFFF)), 
                  ),
                ),
                SizedBox(height: 5),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color:  Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                SizedBox(height: 5),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 48, 
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF4B942),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: Color(0xFFBA8E23), 
                          width: 1,       
                        ),
                      ),
                    ),
                    child: Text(
                      'Log in',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 15),

                // Secure area note
                Container(
                  padding: EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Color(0x1A000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xB3FFFFFF), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is a secure, restricted area. Unauthorized access is prohibited.',
                          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 14, fontWeight: FontWeight.normal),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // Non-super admins
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Not a Super Admin?', style: TextStyle(color:Color(0xFFFFFFFF), fontWeight: FontWeight.normal)),
                    TextButton(
                      onPressed: () {},
                      child: Text('Log in here', style: TextStyle(color:Color(0xFFBA8E23), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

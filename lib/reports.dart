import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AttendanceReportPage(),
    );
  }
}

class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({super.key});

  @override
  State<AttendanceReportPage> createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  String selectedRange = "Select Date";
  DateTime? selectedDate = DateTime.now();


  List<dynamic> backendGroups = []; 
  List<dynamic> backendSchedules = []; 
  
  int? selectedGroupId;
  int? selectedScheduleId;

  String totalPresent = "----";
  String avgRate = "--.--%";
  String dailyRate = "--%";
  List<FlSpot> chartSpots = const [
    FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), 
    FlSpot(3, 0), FlSpot(4, 0), FlSpot(5, 0), FlSpot(6, 0)
  ];
  List<Map<String, dynamic>> studentDetails = [];

  @override
  void initState() {
    super.initState();
    selectedRange = DateFormat('dd MMM yyyy').format(selectedDate!);
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    try {
      final response = await http.get(Uri.parse('${dotenv.env['BASE_URL']}/api/subjects'));
      if (response.statusCode == 200) {
        setState(() {
          backendGroups = jsonDecode(response.body);
        });
      }
    } catch (e) {
      log("Error fetching groups: $e");
    }
  }

  Future<void> _fetchSchedules(int subjectId) async {
    try {
      final response = await http.get(
        Uri.parse('${dotenv.env['BASE_URL']}/api/subjects/$subjectId/files'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          backendSchedules = data;
        });
      }
    } catch (e) {
      log("Error fetching schedules: $e");
    }
  }

  Future<void> _fetchReportData() async {
    if (selectedScheduleId == null || selectedDate == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final url = '${dotenv.env['BASE_URL']}/api/reports?class_id=$selectedScheduleId&date=$formattedDate';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalPresent = data['total_present'].toString();
          avgRate = "${data['avg_rate']}%";
          dailyRate = "${data['daily_rate']}%";
          studentDetails = List<Map<String, dynamic>>.from(data['student_details']);
          
          List<dynamic> trends = data['trends'];
          chartSpots = List.generate(trends.length, (i) {
            return FlSpot(i.toDouble(), (trends[i]['rate'] as num).toDouble());
          });
        });
      }
    } catch (e) {
      log("Error fetching report data: $e");
    }
  }

  Future<void> _pickSingleDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedRange = DateFormat('dd MMM yyyy').format(picked);
      });
      _fetchReportData();
    }
  }

  Future<void> _generatePdf() async {
    if (studentDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a Group to export.")),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Text("Attendance Report",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Filter Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Date: $selectedRange",
                      style: const pw.TextStyle(fontSize: 16)),
                  pw.Text("Group: $selectedGroupId",
                      style: const pw.TextStyle(fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 30),

              // Summary Boxes (Replicated layout for PDF)
              pw.Row(
                children: [
                  _buildPdfSummaryCard("Total Present", totalPresent),
                  pw.SizedBox(width: 20),
                  _buildPdfSummaryCard("Avg. Rate", avgRate),
                ],
              ),
              pw.SizedBox(height: 30),

              // Example Table Data
              pw.Text("Student Details",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Student Name', 'Status', 'Time In'],
                data: studentDetails.map((s) => [
                  s['name'], 
                  s['status'], 
                  s['time_in'] ?? '-'
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              
              pw.Spacer(),
              pw.Text("Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}", 
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
            ],
          );
        },
      ),
    );

    // Open the Print/Share Dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Helper widget for PDF layout
  pw.Widget _buildPdfSummaryCard(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(15),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue900)),
            pw.SizedBox(height: 5),
            pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFFFFFFF),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(20), 
          child: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.black),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Overall Attendance",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryCard("Total Present", totalPresent),
                  _buildSummaryCard("Avg. Rate", avgRate, isRate: true),
                ],
              ),

              const SizedBox(height: 25),
              const Text("Attendance Trends", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _buildTrendContainer(),
              const SizedBox(height: 25),
              const Text("Filter & Export", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 15),
              
              const Text("Date", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              _buildDatePickerTile(),

              const SizedBox(height: 15),
              const Text("Group", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              _buildGroupDropdown(),

              const SizedBox(height: 15),
              const Text("Schedule Time", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              _buildDropdown(
                value: selectedScheduleId,
                items: backendSchedules,
                hint: "Select Time",
                isSchedule: true, // REMARK: Displays 'schedule' instead of 'name'
                onChanged: (val) {
                  setState(() => selectedScheduleId = val);
                  _fetchReportData();
                },
              ),

              const SizedBox(height: 20),
              _buildExportButton(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, {bool isRate = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: isRate ? 22 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF000000),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Daily Rate", style: TextStyle(fontSize: 13, color: Color(0x80000000))),
                  const SizedBox(height: 2),
                  Text(dailyRate, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("Last 7 days", style: TextStyle(fontSize: 13, color: Color(0x80000000))),
                ],
              ),
              const Icon(Icons.trending_up, color: Color(0xFF00B38A)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        int index = value.toInt();
                        if (index < 0 || index >= days.length) return const SizedBox.shrink();
                    return Text(
                      days[index],
                      style: const TextStyle(fontSize: 12, color: Color(0x80000000)),
                    );
                  },
                ),
              ),
            ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: chartSpots,
                  isCurved: true,
                  color: const Color(0xFF1565C0),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF1565C0).withOpacity(0.1)),
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDatePickerTile() {
    return GestureDetector(
      onTap: _pickSingleDate,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x1A000000)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedRange, style: const TextStyle(fontSize: 14)),
            const Icon(Icons.calendar_month_rounded, color: Color(0x80000000)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    return _buildDropdown(
      value: selectedGroupId,
      items: backendGroups,
      hint: "Select Group",
      onChanged: (int? newValue) {
        setState(() {
          selectedGroupId = newValue;
          selectedScheduleId = null; 
          backendSchedules = [];    
          totalPresent = "----";
        });
        if (newValue != null) {
          _fetchSchedules(newValue);
        }
      },
    );
  }

  Widget _buildDropdown({
    int? value, 
    required List<dynamic> items, 
    required String hint, 
    required ValueChanged<int?> onChanged, 
    bool isSchedule = false
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          // REMARK: Value MUST be the ID (int), not a String or Object
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: Colors.black, fontSize: 14)),
          // REMARK: Map the items to DropdownMenuItems using 'id' as the value
          items: items.map<DropdownMenuItem<int>>((item) {
            return DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(
                // REMARK: Display 'name' for Groups, 'schedule' for Time
                isSchedule ? (item['schedule'] ?? 'No Schedule') : (item['name'] ?? 'No Name'),
                style: const TextStyle(color: Colors.black),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
        label: const Text("Export Report", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _generatePdf,
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF1565C0),
      unselectedItemColor: Colors.grey,
      currentIndex: 2,
      onTap: (index) {
        if (index == 0) Navigator.pushReplacementNamed(context, '/dashboard');
        if (index == 1) Navigator.pushReplacementNamed(context, '/enroll');
        if (index == 3) Navigator.pushReplacementNamed(context, '/settings');
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_rounded), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt_rounded), label: 'Enrollment'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
      ],
    );
  }
}

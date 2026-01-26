import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  String? selectedGroup;
  String? selectedSchedule;
  DateTime? selectedDate;

  final List<String> groups = [
    "Class 1",
    "Class 2",
    "Class 3",
  ];

  final Map<String, List<String>> scheduleTimes = {
    "Class 1": ["08:00 AM - 09:00 AM", "10:00 AM - 11:00 AM"],
    "Class 2": ["09:00 AM - 10:00 AM", "11:00 AM - 12:00 PM"],
    "Class 3": ["08:30 AM - 09:30 AM", "01:00 PM - 02:00 PM"],
  };

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
    }
  }

  Future<void> _generatePdf() async {
    if (selectedGroup == null) {
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
                  pw.Text("Group: $selectedGroup",
                      style: const pw.TextStyle(fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 30),

              // Summary Boxes (Replicated layout for PDF)
              pw.Row(
                children: [
                  _buildPdfSummaryCard("Total Present", "1250"),
                  pw.SizedBox(width: 20),
                  _buildPdfSummaryCard("Avg. Rate", "85%"),
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
                data: [
                  ['Ali bin Abu', 'Present', '07:45 AM'],
                  ['Sarah Lee', 'Present', '07:50 AM'],
                  ['Kenji Tan', 'Absent', '-'],
                  ['Mutu Sami', 'Present', '08:01 AM'],
                ],
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
                  _buildSummaryCard("Total Present", "----"),
                  _buildSummaryCard("Avg. Rate", "--.--%", isRate: true),
                ],
              ),

              const SizedBox(height: 25),

              const Text(
                "Attendance Trends",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
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
                      children: const [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Daily Rate",
                              style: TextStyle(
                                  fontSize: 13, color: Color(0x80000000)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "--%",
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Last - days",
                              style: TextStyle(
                                  fontSize: 13, color: Color(0x80000000)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              color: Color(0xFF00B38A),
                              size: 14,
                            ),
                            SizedBox(width: 2),
                            Text(
                              "-- %",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF00B38A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 160,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  const days = [
                                    'Mon',
                                    'Tue',
                                    'Wed',
                                    'Thu',
                                    'Fri',
                                    'Sat',
                                    'Sun'
                                  ];
                                  return Text(
                                    days[value.toInt() % 7],
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0x80000000)),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: const [
                                FlSpot(0, 0),
                                FlSpot(1, 0),
                                FlSpot(2, 0),
                                FlSpot(3, 0),
                                FlSpot(4, 0),
                                FlSpot(5, 0),
                                FlSpot(6, 0),
                              ],
                              isCurved: true,
                              color: const Color(0xFF1565C0),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1565C0)
                                        .withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              dotData: const FlDotData(show: false),
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                "Filter & Export",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),

              const Text("Date",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),

              GestureDetector(
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
                      Text(
                        selectedRange,
                        style: const TextStyle(
                            color: Color(0xFF000000), fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month_rounded,
                          color: Color(0x80000000)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              const Text("Group",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              _buildDropdown(selectedGroup, groups, (value) {
                setState(() {
                  selectedGroup = value;
                  selectedSchedule = null; 
                });
              }),
              const SizedBox(height: 15),

              const Text("Schedule Time",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              _buildDropdown(
                selectedSchedule,
                selectedGroup != null ? scheduleTimes[selectedGroup!]! : [],
                (value) {
                  setState(() => selectedSchedule = value);
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded,
                      color: Colors.white, size: 18),
                  label: const Text(
                    "Export Report",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _generatePdf,
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
              Navigator.pushReplacementNamed(context, '/dashboard');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, '/enroll');
            } else if (index == 2) {
              // Stay on Reports
            } else if (index == 3) {
              Navigator.pushReplacementNamed(context, '/settings');
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

  Widget _buildDropdown(
      String? value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          hint: const Text("Select Group",
              style: TextStyle(color: Color(0xFF000000), fontSize: 14)),
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.black54),
          style: const TextStyle(color: Color(0x80000000), fontSize: 14),
          onChanged: onChanged,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
        ),
      ),
    );
  }
}

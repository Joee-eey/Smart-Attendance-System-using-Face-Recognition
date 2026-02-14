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
import 'package:shared_preferences/shared_preferences.dart';

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
  String changeRate = "0%";
  String selectedRange = "Select Date";
  DateTime? selectedDate = DateTime.now();


  List<dynamic> backendGroups = []; 
  List<dynamic> backendSchedules = []; 
  
  int? selectedGroupId;
  int? selectedScheduleId;
  int? currentUserId;
  int? touchedIndex;

  String totalPresent = "----";
  String avgRate = "--.--%";
  String dailyRate = "--%";
  List<String> trendDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  List<FlSpot> chartSpots = const [
    FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0), 
    FlSpot(3, 0), FlSpot(4, 0), FlSpot(5, 0), FlSpot(6, 0)
  ];
  List<Map<String, dynamic>> studentDetails = [];
  Map<String, dynamic> backendReportData = {'trends': []};

  @override
  void initState() {
    super.initState();
    selectedRange = DateFormat('dd MMM yyyy').format(selectedDate!);
    _loadUserAndFetchGroups();
  }

  Future<void> saveUserSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', userId);
  }

  Future<void> _loadUserAndFetchGroups() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    // Get the ID saved during login.
    currentUserId = prefs.getInt('user_id'); 
  });

  if (currentUserId != null) {
    _fetchGroups();
  } else {
    log("No user session found.");
  }
}

  Future<void> _fetchGroups() async {
    if (currentUserId == null) return;
    try {
      final response = await http.get(Uri.parse('${dotenv.env['BASE_URL']}/api/subjects?user_id=$currentUserId'));
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
    if (selectedGroupId == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
    // final url = '${dotenv.env['BASE_URL']}/api/reports?class_id=$selectedScheduleId&date=$formattedDate';
    String url = '${dotenv.env['BASE_URL']}/api/reports?subject_id=$selectedGroupId&date=$formattedDate';

    if (selectedScheduleId != null) {
      url += '&class_id=$selectedScheduleId';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log("DEBUG: student_details first record: ${data['student_details'][0]}");
        setState(() {
          backendReportData = data;
          totalPresent = data['total_present'].toString();
          avgRate = "${data['avg_rate']}%";
          dailyRate = "${data['daily_rate']}%";
          changeRate = data['change_rate'] ?? "+0.0%";
          studentDetails = List<Map<String, dynamic>>.from(data['student_details']);
          
          List<dynamic> trends = data['trends'];
          trendDays = trends.map((t) => t['day_name'].toString()).toList();
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
    final Color primaryColor = const Color(0xFF1565C0);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: primaryColor, // Header background and selected day circle
            onPrimary: Colors.white, // Header text and selected day text
            onSurface: Colors.black, // Body text color (days of the week)
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: primaryColor, // "OK" and "Cancel" button color
            ),
          ),
        ),
        child: child!,
      );
    },
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

    // Load Logo
    final ByteData bytes = await rootBundle.load('assets/images/UOP Logo.png');
    final Uint8List logoData = bytes.buffer.asUint8List();
    final pw.MemoryImage logoImage = pw.MemoryImage(logoData);
    final PdfColor primaryBlue = PdfColor.fromInt(0xFFE3F2FD);

    // Advanced Sort Logic: 
    // - Primary: Status (Present first)
    // - Secondary: Course (A-Z)
    // - Tertiary: Name (A-Z)
    List<Map<String, dynamic>> sortedList = List.from(studentDetails);
    sortedList.sort((a, b) {
      String statusA = a['status']?.toString().toLowerCase() ?? 'absent';
      String statusB = b['status']?.toString().toLowerCase() ?? 'absent';

      // Status Check: Present (smaller index) comes before Absent
      if (statusA == 'present' && statusB != 'present') return -1;
      if (statusA != 'present' && statusB == 'present') return 1;

      // If statuses are the same, sort by Course (A-Z)
      String courseA = a['course']?.toString().toLowerCase() ?? '';
      String courseB = b['course']?.toString().toLowerCase() ?? '';
      int courseComp = courseA.compareTo(courseB);
      if (courseComp != 0) return courseComp;

      // If courses are also the same, sort by Name (A-Z)
      String nameA = a['name']?.toString().toLowerCase() ?? '';
      String nameB = b['name']?.toString().toLowerCase() ?? '';
      return nameA.compareTo(nameB);
    });

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // Header with Logo Placeholder
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Attendance Report", 
                      style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text("Date: $selectedRange"),
                  ]
                ),
                // LOGO AT TOP RIGHT
                pw.Container(
                  width: 120, 
                  height: 80,
                  child: pw.Image(logoImage),
                ),
              ],
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // Summary Cards Row
            pw.Row(
              children: [
                _buildPdfSummaryCard("Today's Rate", dailyRate),
                pw.SizedBox(width: 10),
                _buildPdfSummaryCard("Overall Avg", avgRate),
                pw.SizedBox(width: 10),
                _buildPdfSummaryCard("Weekly Rate", changeRate),
              ],
            ),
            pw.SizedBox(height: 30),

            pw.Text("Student Details", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // TABLE
            pw.TableHelper.fromTextArray(
              headers: ['Student Name', 'ID', 'Course', 'Status', 'Time In'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                color: PdfColors.black,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(color: primaryBlue),
              cellAlignment: pw.Alignment.centerLeft,
              data: sortedList.map((s) {
                bool isPresent = s['status'].toString().toLowerCase() == 'present';
                String rawStatus = s['status']?.toString().toLowerCase() ?? 'absent';
                String formattedStatus = rawStatus[0].toUpperCase() + rawStatus.substring(1);
                
                String timeVal = s['time_in']?.toString() ?? '-';
                String timeDisplay = (timeVal == 'null' || timeVal == 'None' || timeVal.isEmpty) 
                    ? '-' 
                    : timeVal;

                return [
                  s['name'] ?? '-',
                  s['student_formal_id'] ?? '-',
                  s['course'] ?? '-',
                  pw.Text(
                    formattedStatus,
                    style: pw.TextStyle(
                      color: isPresent ? PdfColors.black : PdfColors.red,
                      fontWeight: isPresent ? pw.FontWeight.normal : pw.FontWeight.bold,
                    ),
                  ),
                  timeDisplay,
                ];
              }).toList(),
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
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
                  _buildSummaryCard("Daily Rate", dailyRate, isRate: true),
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
                isSchedule: true,
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
    bool isPositive = !changeRate.contains('-');
    Color trendColor = isPositive ? const Color(0xFF00B38A) : const Color(0xFFEA324C);
    double chartWidth = chartSpots.length * 60.0;
    double minWidth = MediaQuery.of(context).size.width - 70; 
    double finalWidth = chartWidth < minWidth ? minWidth : chartWidth;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 5),
        )
      ],
    ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Average Rate", style: TextStyle(fontSize: 13, color: Color(0x80000000))),
                  Text(avgRate, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text("- / + ? % vs previous week", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  /* Text("$changeRate vs previous week", 
                     style: const TextStyle(fontSize: 12, color: Colors.grey)),*/
                  // const Text("Last 7 days", style: TextStyle(fontSize: 13, color: Color(0x80000000))),
                ],
              ),
              Row(
                children: [
                  Icon(isPositive ? Icons.trending_up : Icons.trending_down, color: trendColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    changeRate, // e.g. +2.0%
                    style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          reverse: true, // Scroll to the far right by default (displaying the most recent date)
          child: Container(
            width: finalWidth,
            height: 200,
            padding: const EdgeInsets.only(right: 20, top: 10),
            child: LineChart(
              LineChartData(
                showingTooltipIndicators: touchedIndex != null
                    ? [
                        ShowingTooltipIndicators([
                          LineBarSpot(
                            LineChartBarData(spots: chartSpots),
                            0,
                            chartSpots[touchedIndex!],
                          ),
                        ])
                      ]
                    : [],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: false,
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: const Color(0xFF1565C0).withOpacity(0.5), // Line color
                          strokeWidth: 2,
                          dashArray: [5, 5], // Makes the line dashed
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 8, // Slightly larger dot when selected
                            color: const Color(0xFF1565C0),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },

                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1565C0), // Bubble background (Data)
                    tooltipRoundedRadius: 8,
                    maxContentWidth: 180, // Bubble width

                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 10, // Increases space between the dot and the bubble
                    
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,

                    showOnTopOfTheChartBoxArea: false,

                   getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((barSpot) {
                      final index = barSpot.x.toInt();
                      final data = backendReportData['trends'][index];

                      String dateStr = data['date'] ?? "";
                      try {
                        DateTime parsedDate = DateTime.parse(dateStr);
                        dateStr = DateFormat('dd MMM yyyy').format(parsedDate);
                      } catch (e) {
                        dateStr = data['day_name'] ?? "";
                      }

                      // Multi Sessions Logic
                      final sessions = data['sessions'] as List?;
                      String sessionText = '';

                      if (sessions != null && sessions.isNotEmpty) {
                        for (var s in sessions) {
                          sessionText +=
                              '\nPresent (Session ${s['session_no']}): ${s['present']} / ${s['total']}';
                        }
                      } else {
                        // Fallback (old single session data)
                        sessionText =
                            '\nPresent: ${data['present_count']} / ${data['total_students']}';
                      }

                      return LineTooltipItem(
                        '$dateStr\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(text: 'Attendance: ${data['rate']}%$sessionText',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                          ),
                        ]
                      );
                        /*'Attendance: ${data['rate']}%$sessionText',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );*/
                    }).toList();
                  },

                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    // Respond only to taps or swipes
                    // To preserved when the finger is lifted (Up/Exit)
                    if (event is FlTapDownEvent || event is FlPanUpdateEvent || event is FlPointerHoverEvent) {
                      if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                        final index = touchResponse.lineBarSpots!.first.spotIndex;
                        if (index != touchedIndex) {
                          setState(() {
                            touchedIndex = index;
                          });
                        }
                      }
                    }
                  },
                ),

                // Display Y-axis scale
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20, // Every 20% per scale
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}%', 
                          style: const TextStyle(color: Colors.grey, fontSize: 12));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < 0 || index >= trendDays.length) return const SizedBox.shrink();
                        return Text(trendDays[index], 
                          style: const TextStyle(fontSize: 12, color: Colors.grey));
                      },
                    ),
                  ),
                ),

                // Set the Y-axis range
                minY: 0,
                maxY: 100,

                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),

                borderData: FlBorderData(show: false),

                lineBarsData: [
                  LineChartBarData(
                    spots: chartSpots,
                    isCurved: true,
                    color: const Color(0xFF1565C0),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: const Color(0xFF1565C0),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1565C0).withOpacity(0.2),
                          const Color(0xFF1565C0).withOpacity(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x1A000000)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(selectedRange, style: const TextStyle(fontSize: 14, color: Colors.black)),
            const Icon(Icons.calendar_month_rounded, color: Color(0x80000000), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDropdown() {
    if (backendGroups.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Text("Loading groups or no data found...", style: TextStyle(color: Colors.grey)),
    );
  }
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
          // avgRate = "--.--%";
          dailyRate = "--%";
          studentDetails = [];
        });
        if (newValue != null) {
          _fetchSchedules(newValue);
          _fetchReportData();
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
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: Colors.black, fontSize: 14)),
          items: items.map<DropdownMenuItem<int>>((item) {
            return DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(
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

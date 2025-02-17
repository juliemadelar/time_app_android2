// ignore_for_file: file_names, use_super_parameters

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class TimesheetPage extends StatefulWidget {
  const TimesheetPage({Key? key}) : super(key: key); // Add the Key parameter

  @override
  TimesheetPageState createState() => TimesheetPageState();
}

class TimesheetPageState extends State<TimesheetPage> {
  DateTime _currentDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _timeInRecords = [];
  double _hourlyRate = 65.00;
  double _nightDifferentialRate = 0.10; // Default value
  final double _overtimeRate = 1.25;
  double _totalHours = 0.0;
  double _totalPay = 0.0;
  bool _isLoading = true; // Add this line

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _calculateCutOffDates();
    _fetchTimeInRecords();
    _loadSettings();
  }

  void _calculateCutOffDates() {
    int day = _currentDate.day;
    if (day <= 15) {
      _startDate = DateTime(_currentDate.year, _currentDate.month, 1);
      _endDate = DateTime(_currentDate.year, _currentDate.month, 15);
    } else {
      _startDate = DateTime(_currentDate.year, _currentDate.month, 16);
      _endDate = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    }
  }

  void _previousCutOff() {
    setState(() {
      _currentDate = _startDate.subtract(Duration(days: 1));
      _calculateCutOffDates();
      _fetchTimeInRecords();
    });
  }

  void _nextCutOff() {
    setState(() {
      _currentDate = _endDate.add(Duration(days: 1));
      _calculateCutOffDates();
      _fetchTimeInRecords();
    });
  }

  Future<String> _getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return join(directory.path, 'time_in_database.db');
  }

  Future<void> _fetchTimeInRecords() async {
    setState(() {
      _isLoading = true; // Add this line
    });

    final databasePath = await _getDatabasePath();
    final database = openDatabase(
      databasePath,
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE time_in(id INTEGER PRIMARY KEY, date TEXT, time_in TEXT, time_out TEXT, work_type TEXT)",
        );
      },
      version: 1,
    );

    final db = await database;

    final List<Map<String, dynamic>> records = await db.query(
      'time_in',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [_startDate.toIso8601String(), _endDate.toIso8601String()],
    );

    double totalHours = 0.0;
    double totalPay = 0.0;

    for (var record in records) {
      final timeIn = record['time_in'];
      final timeOut = record['time_out'];
      if (timeIn != null && timeOut != null) {
        final hours = _computeTotalHours(timeIn, timeOut);
        totalHours += hours;
        totalPay += _computeTotalPay(hours, timeIn, timeOut, record['work_type']);
      }
    }

    setState(() {
      _timeInRecords = records;
      _totalHours = totalHours;
      _totalPay = totalPay;
      _isLoading = false; // Add this line
    });
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _hourlyRate = prefs.getDouble('hourlyRate') ?? 65.00;
      _nightDifferentialRate = (prefs.getDouble('nightDifferentialRate') ?? 0.10); // Load night differential rate as decimal
    });
  }

  double _computeTotalHours(String timeIn, String timeOut) {
    final format = DateFormat("hh:mm a");
    final timeInDate = format.parse(timeIn);
    var timeOutDate = format.parse(timeOut);

    // Check if time out is before time in, indicating it is on the next day
    if (timeOutDate.isBefore(timeInDate)) {
      timeOutDate = timeOutDate.add(Duration(hours: 24));
    }

    final difference = timeOutDate.difference(timeInDate);
    final totalHours = difference.inMinutes / 60.0 - 1; // Subtract 1 hour for lunch break
    return totalHours;
  }

  double _computeNightDifferentialHours(String timeIn, String timeOut) {
    final format = DateFormat("hh:mm a");
    final timeInDate = format.parse(timeIn);
    var timeOutDate = format.parse(timeOut);

    // Check if time out is before time in, indicating it is on the next day
    if (timeOutDate.isBefore(timeInDate)) {
      timeOutDate = timeOutDate.add(Duration(hours: 24));
    }

    double nightHours = 0.0;
    final nightStart = DateTime(timeInDate.year, timeInDate.month, timeInDate.day, 22);
    final nightEnd = DateTime(timeOutDate.year, timeOutDate.month, timeOutDate.day, 6);

    if (timeInDate.isBefore(nightEnd) && timeOutDate.isAfter(nightStart)) {
      final start = timeInDate.isBefore(nightStart) ? nightStart : timeInDate;
      final end = timeOutDate.isAfter(nightEnd) ? nightEnd : timeOutDate;
      nightHours = end.difference(start).inMinutes / 60.0;
    }

    // Deduct 1 hour for lunch break
    nightHours = nightHours > 1 ? nightHours - 1 : 0;

    return nightHours;
  }

  double _computeOvertimeHours(double totalHours) {
    return totalHours > 9 ? totalHours - 9 : 0;
  }

  double _computeTotalPay(double totalHours, String timeIn, String timeOut, String workType) {
    double dailyRate = _hourlyRate * 9;
    double nightDifferentialHours = _computeNightDifferentialHours(timeIn, timeOut);
    double nightDifferentialPay = nightDifferentialHours * (_hourlyRate * _nightDifferentialRate);
    double overtimeHours = _computeOvertimeHours(totalHours);
    double overtimePay = overtimeHours * (_hourlyRate * _overtimeRate);
    double totalPay = dailyRate + nightDifferentialPay + overtimePay;

    if (workType == 'Regular Holiday') {
      totalPay *= 2; // Multiply by 200%
    } else if (workType == 'Special Holiday') {
      totalPay *= 1.3; // Multiply by 130%
    }

    return totalPay;
  }

  Future<void> _deleteRecord(int id) async {
    final databasePath = await _getDatabasePath();
    final database = openDatabase(
      databasePath,
    );

    final db = await database;

    await db.delete(
      'time_in',
      where: 'id = ?',
      whereArgs: [id],
    );

    _fetchTimeInRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timesheet',
          style: GoogleFonts.grechenFuemen(
            textStyle: TextStyle(
              fontSize: 24.0, // Make the title bigger
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(2.0, 2.0),
                  blurRadius: 3.0,
                  color: Color.fromARGB(255, 0, 0, 0),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true, // Center the title
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(Icons.arrow_back),
                          onPressed: _previousCutOff,
                        ),
                        Flexible( // Change from Expanded to Flexible
                          child: Text(
                            '${DateFormat('MM/dd/yyyy').format(_startDate)} - ${DateFormat('MM/dd/yyyy').format(_endDate)}',
                            style: TextStyle(fontSize: 16.0),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward),
                          onPressed: _nextCutOff,
                        ),
                      ],
                    ),
                    ListView.builder( // Remove Expanded
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _timeInRecords.length,
                      itemBuilder: (context, index) {
                        final record = _timeInRecords[index];
                        final timeIn = record['time_in'];
                        final timeOut = record['time_out'];
                        if (timeIn == null || timeOut == null) {
                          return Container();
                        }
                        final totalHours = _computeTotalHours(timeIn, timeOut);
                        final totalPay = _computeTotalPay(totalHours, timeIn, timeOut, record['work_type']);
                        final nightDifferentialHours = _computeNightDifferentialHours(timeIn, timeOut);
                        final nightDifferentialPay = nightDifferentialHours * (_hourlyRate * _nightDifferentialRate);
                        return GestureDetector(
                          onTap: () {
                            // Expand details
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 8.0),
                            padding: EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Flexible( // Change from Expanded to Flexible
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('Date: ${DateFormat('MM-dd-yyyy').format(DateTime.parse(record['date']))}'),
                                      Text('Total Hours: $totalHours'),
                                      Text('Night Differential Hours: $nightDifferentialHours'),
                                      Text('Night Differential Pay: P$nightDifferentialPay'),
                                    ],
                                  ),
                                ),
                                Flexible( // Change from Expanded to Flexible
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text('Work Type: ${record['work_type']}'),
                                      Text('Total Pay: P$totalPay'),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    IconButton(
                                      icon: Icon(Icons.delete),
                                      onPressed: () => _deleteRecord(record['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: <Widget>[
                          Text('Total Hours: $_totalHours', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                          Text('Total Pay: P$_totalPay', style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

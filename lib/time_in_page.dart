// ignore_for_file: file_names, library_private_types_in_public_api, unused_field, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class TimeInPage extends StatefulWidget {
  final Map<String, dynamic>? initialRecord;

  const TimeInPage({super.key, this.initialRecord});

  @override
  _TimeInPageState createState() => _TimeInPageState();
}

class _TimeInPageState extends State<TimeInPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  String? _selectedTimeIn;
  String? _selectedTimeOut;
  String? _selectedWorkType;
  List<Map<String, dynamic>> _timeInRecords = [];
  int? _selectedRecordId;
  List<String> _timeOutOptions = [];

  @override
  void initState() {
    super.initState();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (widget.initialRecord != null) {
      _selectedDate = DateTime.parse(widget.initialRecord!['date']);
      _selectedTimeIn = widget.initialRecord!['time_in'];
      _selectedTimeOut = widget.initialRecord!['time_out'];
      _selectedWorkType = widget.initialRecord!['work_type'];
    } else {
      _selectedDate = DateTime.now();
    }
    _fetchTimeInRecords();
    _updateTimeOutOptions();
  }

  Future<String> _getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return join(directory.path, 'time_in_database.db');
  }

  Future<void> _fetchTimeInRecords() async {
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
      orderBy: 'date DESC', // Order by date in descending order
      limit: 5, // Limit the number of records to 5
    );
    setState(() {
      _timeInRecords = records;
    });
  }

  Future<void> _saveTimeIn() async {
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

    if (widget.initialRecord == null) {
      await db.insert(
        'time_in',
        {
          'date': _selectedDate.toIso8601String(),
          'time_in': _selectedTimeIn,
          'time_out': _selectedTimeOut,
          'work_type': _selectedWorkType,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.update(
        'time_in',
        {
          'date': _selectedDate.toIso8601String(),
          'time_in': _selectedTimeIn,
          'time_out': _selectedTimeOut,
          'work_type': _selectedWorkType,
        },
        where: 'id = ?',
        whereArgs: [widget.initialRecord!['id']],
      );
    }

    _fetchTimeInRecords();
  }

  Future<void> _deleteRecord(int id) async {
    final databasePath = await _getDatabasePath();
    final database = openDatabase(databasePath);

    final db = await database;

    await db.delete(
      'time_in',
      where: 'id = ?',
      whereArgs: [id],
    );

    _fetchTimeInRecords();
  }

  void _editRecord(Map<String, dynamic> record) {
    setState(() {
      _selectedRecordId = record['id'];
      _selectedDate = DateTime.parse(record['date']);
      _selectedTimeIn = record['time_in'];
      _selectedTimeOut = record['time_out'];
      _selectedWorkType = record['work_type'];
    });
  }

  void _updateTimeOutOptions() {
    if (_selectedTimeIn == '6:00 AM') {
      _timeOutOptions = ['4:00 PM', '5:30 PM'];
    } else if (_selectedTimeIn == '6:00 PM') {
      _timeOutOptions = ['4:00 AM', '5:30 AM'];
    } else {
      _timeOutOptions = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Time In',
          style: TextStyle(
            fontFamily: 'DarumadropOne-Regular',
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
        centerTitle: true, // Center the title
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (pickedDate != null && pickedDate != _selectedDate) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Text(_selectedDate.toLocal().toString().split(' ')[0]),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedTimeIn,
                    hint: Text('Select Time In'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTimeIn = newValue!;
                        _selectedTimeOut = null; // Reset TimeOut selection
                        _updateTimeOutOptions();
                      });
                    },
                    items: <String>['6:00 AM', '6:00 PM']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Field cannot be empty' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedTimeOut,
                    hint: Text('Select Time Out'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTimeOut = newValue!;
                      });
                    },
                    items: _timeOutOptions
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Field cannot be empty' : null,
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedWorkType,
                    hint: Text('Select Work Type'),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedWorkType = newValue!;
                      });
                    },
                    items: <String>[
                      'Regular Day',
                      'Regular Holiday',
                      'Special Holiday',
                      'Restday OT'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Field cannot be empty' : null,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        await _saveTimeIn();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Time in has been recorded')),
                        );
                        _fetchTimeInRecords();
                      }
                    },
                    child: Text('Submit'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _timeInRecords.length,
                itemBuilder: (context, index) {
                  final record = _timeInRecords[index];
                  return ListTile(
                    title: Text('Date: ${record['date']}'),
                    subtitle: Text('Time In: ${record['time_in']}, Time Out: ${record['time_out']}, Work Type: ${record['work_type']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editRecord(record),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _deleteRecord(record['id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

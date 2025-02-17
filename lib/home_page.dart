// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'time_in_page.dart';
import 'timesheet_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  final Function(bool) onThemeChanged;

  HomePage({required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Time Logger',
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TimeInPage()),
                );
              },
              child: Text('Time In'),
            ),
            SizedBox(height: 16.0), // Add space between buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TimesheetPage()),
                );
              },
              child: Text('Timesheet'),
            ),
            SizedBox(height: 16.0), // Add space between buttons
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage(onThemeChanged: onThemeChanged)),
                );
              },
              child: Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

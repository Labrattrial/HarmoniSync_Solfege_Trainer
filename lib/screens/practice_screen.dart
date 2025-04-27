import 'package:flutter/material.dart';

class PracticeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text('Practice Session', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Easy Section
            SectionHeader(title: 'Easy'),
            PracticeItem(title: 'Do Re Mi'),
            PracticeItem(title: 'Sol La Ti'),

            // Medium Section
            SectionHeader(title: 'Medium'),
            PracticeItem(title: 'Do Re Mi Fa'),
            PracticeItem(title: 'Sol La Ti Do'),

            // Hard Section
            SectionHeader(title: 'Hard'),
            PracticeItem(title: 'Chromatic Scale'),
            PracticeItem(title: 'Arpeggios'),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }
}

class PracticeItem extends StatelessWidget {
  final String title;
  const PracticeItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        onTap: () {
          // Handle the practice action
        },
      ),
    );
  }
}

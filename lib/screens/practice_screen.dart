import 'package:flutter/material.dart';
import '../services/music_service.dart';
import 'exercise_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

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
            PracticeItem(
              title: MusicService.getLevelTitle('lvl1'),
              level: 'lvl1',
            ),

            // Medium Section
            SectionHeader(title: 'Medium'),
            PracticeItem(
              title: MusicService.getLevelTitle('lvl2'),
              level: 'lvl2',
            ),

            // Hard Section
            SectionHeader(title: 'Hard'),
            PracticeItem(
              title: MusicService.getLevelTitle('lvl3'),
              level: 'lvl3',
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

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
  final String level;

  const PracticeItem({
    super.key, 
    required this.title,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.blueAccent),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExerciseScreen(level: level),
            ),
          );
        },
      ),
    );
  }
}

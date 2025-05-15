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
            ExerciseCard(
              title: MusicService.getLevelTitle('1'),
              level: '1',
              onTap: () => _navigateToExercise(context, '1'),
            ),

            // Medium Section
            SectionHeader(title: 'Medium'),
            ExerciseCard(
              title: MusicService.getLevelTitle('2'),
              level: '2',
              onTap: () => _navigateToExercise(context, '2'),
            ),

            // Hard Section
            SectionHeader(title: 'Hard'),
            ExerciseCard(
              title: MusicService.getLevelTitle('3'),
              level: '3',
              onTap: () => _navigateToExercise(context, '3'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToExercise(BuildContext context, String level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseScreen(level: level),
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

class ExerciseCard extends StatelessWidget {
  final String title;
  final String level;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key, 
    required this.title,
    required this.level,
    required this.onTap,
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
        onTap: onTap,
      ),
    );
  }
}

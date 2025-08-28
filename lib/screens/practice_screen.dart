import 'package:flutter/material.dart';
import '../services/music_service.dart';
import 'exercise_screen.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF070372), // Top bar background (gold). Change this to alter the AppBar background.
        foregroundColor: Colors.white, // Top bar text/icons color. Change this for AppBar title and icons.
        title: const Text('Practice Session'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.9, -0.8),
            end: Alignment(1.0, 0.9),
            colors: [
              Color(0xFFFFF9C4),
              Color(0xFFFFECB3),
              Color(0xFFE3F2FD),
              Color(0xFFBBDEFB),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // Easy Section
              const SectionHeader(title: 'Easy'),

              // How to customize card colors:
              // - titleColor: changes the text color of the card title
              // - backgroundColor: changes the card's background color
              // - iconColor: changes the trailing arrow icon color
              // You can use:
              //   - Material swatches: Colors.green, Colors.green.shade700
              //   - Hex colors: const Color(0xFF1B5E20)
              //   - Theme values: Theme.of(context).colorScheme.primary
              ExerciseCard(
                title: MusicService.getLevelTitle('1'),
                level: '1',
                onTap: () => _navigateToExercise(context, '1'),
                titleColor: Colors.white, // CHANGE ME: Title text color for this card
                backgroundColor: const Color(0xFF070372), // CHANGE ME: Card background color for this card
                // iconColor: Colors.green, // OPTIONAL: Uncomment to set the trailing arrow color for this card
              ),

              // Medium Section
              const SectionHeader(title: 'Medium'),
              ExerciseCard(
                title: MusicService.getLevelTitle('2'),
                level: '2',
                onTap: () => _navigateToExercise(context, '2'),
                titleColor: Colors.white, // CHANGE ME: Title text color for this card
                backgroundColor: const Color(0xFF070372), // CHANGE ME: Card background color for this card
                // iconColor: Colors.green, // OPTIONAL: Uncomment to set the trailing arrow color for this card
              ),

              // Hard Section
              const SectionHeader(title: 'Hard'),
              ExerciseCard(
                title: MusicService.getLevelTitle('3'),
                level: '3',
                onTap: () => _navigateToExercise(context, '3'),
                titleColor: Colors.white, // CHANGE ME: Title text color for this card
                backgroundColor: const Color(0xFF070372), // CHANGE ME: Card background color for this card
                // iconColor: Colors.green, // OPTIONAL: Uncomment to set the trailing arrow color for this card
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// A simple, tappable card used as a "button" for practice levels.
///
/// Customize colors by passing:
/// - backgroundColor: card's background
/// - titleColor: title text color
/// - iconColor: trailing arrow icon color
class ExerciseCard extends StatelessWidget {
  final String title;
  final String level;
  final VoidCallback onTap;
  // Optional colors to customize this "button"
  final Color? backgroundColor; // Card background color (pass a Color to override)
  final Color? titleColor;      // Title text color (pass a Color to override)
  final Color? iconColor;       // Trailing arrow icon color (pass a Color to override)

  const ExerciseCard({
    super.key, 
    required this.title,
    required this.level,
    required this.onTap,
    this.backgroundColor, // Set to change card background
    this.titleColor,      // Set to change text color
    this.iconColor,       // Set to change trailing icon color
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: backgroundColor, // Background color for the card
      child: ListTile(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: titleColor, // Title text color
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: iconColor ?? theme.colorScheme.primary, // Trailing icon color (defaults to theme primary if null)
        ),
        onTap: onTap,
      ),
    );
  }
}


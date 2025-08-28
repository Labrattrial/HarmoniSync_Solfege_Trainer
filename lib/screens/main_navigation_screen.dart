import 'package:flutter/material.dart';
import 'practice_screen.dart';
import 'sheet_converter_screen.dart';
import 'progress_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    PracticeScreen(),
    SheetConverterScreen(),
    ProgressScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          // Deep blue background
          backgroundColor: const Color(0xFF070372),
          // Yellow highlight for selected "pill"
          indicatorColor: const Color(0xFFD6A83D).withOpacity(0.8),
          // Icon colors: yellow for selected, lighter yellow for unselected
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFFD6A83D), size: 28);
            }
            return IconThemeData(
              color: const Color(0xFFD6A83D).withOpacity(0.6),
              size: 24,
            );
          }),
          // Label (text) colors
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final base = theme.textTheme.labelMedium;
            final color = states.contains(WidgetState.selected)
                ? const Color(0xFFD6A83D) // strong yellow
                : const Color(0xFFD6A83D).withOpacity(0.5); // softer yellow
            return base?.copyWith(fontWeight: FontWeight.w600, color: color);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note),
              label: 'Practice',
            ),
            NavigationDestination(
              icon: Icon(Icons.picture_as_pdf_outlined),
              selectedIcon: Icon(Icons.picture_as_pdf),
              label: 'Sheet',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }
}

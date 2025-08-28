import 'package:flutter/material.dart';

class SheetConverterScreen extends StatelessWidget {
  const SheetConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF070372), // Top bar background (gold). Change this to alter the AppBar background.
        foregroundColor: Colors.white, // Top bar text/icons color. Change this for AppBar title and icons.
        title: const Text('Sheet Converter'),
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  size: 100,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    // Handle PDF upload or conversion
                  },
                  child: const Text('Upload PDF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

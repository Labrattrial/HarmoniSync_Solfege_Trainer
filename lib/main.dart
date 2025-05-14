import 'package:flutter/material.dart';
//import 'screens/pitch_detector_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  //runApp(const MaterialApp(home: PitchDetectorScreen()));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

 @override
 Widget build(BuildContext context) {
   return MaterialApp(
     title: 'My Music Trainer',
     debugShowCheckedModeBanner: false,
     home: WelcomeScreen(), // Start here
   );
 }
}
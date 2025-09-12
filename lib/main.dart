import 'package:flutter/material.dart';
//import 'screens/pitch_detector_screen.dart';
import 'screens/welcome_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  //runApp(const MaterialApp(home: PitchDetectorScreen()));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

 @override
 Widget build(BuildContext context) {
   final baseLight = ThemeData(
     useMaterial3: true,
     colorSchemeSeed: Colors.indigo,
     brightness: Brightness.light,
   );
   final baseDark = ThemeData(
     useMaterial3: true,
     colorSchemeSeed: Colors.indigo,
     brightness: Brightness.dark,
   );

   // Blue + Yellow palette
   const primaryBlue = Color(0xFF1E3A8A); // deep blue
   const secondaryYellow = Color(0xFFF59E0B); // amber/yellow
   const tertiaryBlue = Color(0xFF3B82F6); // accent blue

   ColorScheme lightScheme = baseLight.colorScheme.copyWith(
     primary: primaryBlue,
     secondary: secondaryYellow,
     tertiary: tertiaryBlue,
   );
   ColorScheme darkScheme = baseDark.colorScheme.copyWith(
     primary: tertiaryBlue,
     secondary: const Color(0xFFFBBF24),
     tertiary: const Color(0xFF60A5FA),
   );

   final textThemeLight = TextTheme(
     displayLarge: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     displayMedium: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     displaySmall: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     headlineLarge: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     headlineMedium: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     headlineSmall: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     titleLarge: GoogleFonts.raleway(fontWeight: FontWeight.w700),
     titleMedium: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     titleSmall: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     bodyLarge: GoogleFonts.rubik(),
     bodyMedium: GoogleFonts.rubik(),
     bodySmall: GoogleFonts.rubik(),
     labelLarge: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     labelMedium: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     labelSmall: GoogleFonts.raleway(fontWeight: FontWeight.w600),
   );

   final textThemeDark = TextTheme(
     displayLarge: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     displayMedium: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     displaySmall: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     headlineLarge: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     headlineMedium: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     headlineSmall: GoogleFonts.cinzelDecorative(fontWeight: FontWeight.w600),
     titleLarge: GoogleFonts.raleway(fontWeight: FontWeight.w700),
     titleMedium: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     titleSmall: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     bodyLarge: GoogleFonts.rubik(),
     bodyMedium: GoogleFonts.rubik(),
     bodySmall: GoogleFonts.rubik(),
     labelLarge: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     labelMedium: GoogleFonts.raleway(fontWeight: FontWeight.w600),
     labelSmall: GoogleFonts.raleway(fontWeight: FontWeight.w600),
   );

   return MaterialApp(
     title: 'HarmoniSync',
     debugShowCheckedModeBanner: false,
     themeMode: ThemeMode.system,
     theme: baseLight.copyWith(
       colorScheme: lightScheme,
       appBarTheme: AppBarTheme(
         centerTitle: true,
         backgroundColor: Colors.white.withOpacity(0.90),
         elevation: 0,
         surfaceTintColor: Colors.transparent,
         foregroundColor: lightScheme.primary,
       ),
       textTheme: textThemeLight,
       elevatedButtonTheme: ElevatedButtonThemeData(
         style: ElevatedButton.styleFrom(
           backgroundColor: lightScheme.primary,
           foregroundColor: Colors.white,
           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(12),
           ),
           textStyle: const TextStyle(fontWeight: FontWeight.w700),
         ),
       ),
       textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
           foregroundColor: lightScheme.primary,
           textStyle: const TextStyle(fontWeight: FontWeight.w700),
         ),
       ),
       outlinedButtonTheme: OutlinedButtonThemeData(
         style: OutlinedButton.styleFrom(
           foregroundColor: lightScheme.primary,
           side: BorderSide(color: lightScheme.primary),
           textStyle: const TextStyle(fontWeight: FontWeight.w700),
         ),
       ),
       iconButtonTheme: IconButtonThemeData(
         style: IconButton.styleFrom(
           foregroundColor: lightScheme.primary,
         ),
       ),
       cardTheme: CardThemeData(
         elevation: 1,
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(16),
         ),
         surfaceTintColor: lightScheme.surfaceTint,
       ),
             navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: lightScheme.secondary.withValues(alpha: 0.20),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.raleway(
            fontWeight: FontWeight.w600,
            color: lightScheme.primary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(color: lightScheme.primary);
        }),
      ),
     ),
     darkTheme: baseDark.copyWith(
       colorScheme: darkScheme,
       appBarTheme: AppBarTheme(
         centerTitle: true,
         backgroundColor: Colors.black.withOpacity(0.10),
         elevation: 0,
         surfaceTintColor: Colors.transparent,
         foregroundColor: Colors.white,
       ),
       textTheme: textThemeDark,
       elevatedButtonTheme: ElevatedButtonThemeData(
         style: ElevatedButton.styleFrom(
           backgroundColor: darkScheme.primary,
           foregroundColor: Colors.white,
           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(12),
           ),
           textStyle: const TextStyle(fontWeight: FontWeight.w700),
         ),
       ),
       textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
           foregroundColor: darkScheme.primary,
           textStyle: const TextStyle(fontWeight: FontWeight.w700),
         ),
       ),
       outlinedButtonTheme: OutlinedButtonThemeData(
         style: OutlinedButton.styleFrom(
           foregroundColor: darkScheme.primary,
           side: BorderSide(color: darkScheme.primary),
           textStyle: const TextStyle(fontWeight: FontWeight.w700),
         ),
       ),
       iconButtonTheme: IconButtonThemeData(
         style: IconButton.styleFrom(
           foregroundColor: darkScheme.primary,
         ),
       ),
       cardTheme: CardThemeData(
         elevation: 1,
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(16),
         ),
         surfaceTintColor: darkScheme.surfaceTint,
       ),
             navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkScheme.surface,
        indicatorColor: darkScheme.secondary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.raleway(
            fontWeight: FontWeight.w600,
            color: darkScheme.primary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(color: darkScheme.primary);
        }),
      ),
     ),
     home: const WelcomeScreen(), // Start here
   );
 }
}
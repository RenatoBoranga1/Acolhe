import 'package:flutter/material.dart';

class AcolheTheme {
  static const Color trustBlue = Color(0xFF6E93B8);
  static const Color calmGreen = Color(0xFF7FAE9B);
  static const Color lavender = Color(0xFFB6A6D9);
  static const Color warmShell = Color(0xFFF5F1EB);
  static const Color graphite = Color(0xFF2F3A45);
  static const Color sand = warmShell;
  static const Color ink = graphite;
  static const Color teal = trustBlue;
  static const Color mutedTeal = Color(0xFF87A6C2);
  static const Color clay = Color(0xFF9C7761);
  static const Color rose = Color(0xFFA45E60);
  static const Color forest = calmGreen;
  static const Color night = Color(0xFF121A21);
  static const Color slate = Color(0xFF21313D);
  static const Color mist = Color(0xFFE6EBF0);

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: teal,
      onPrimary: Colors.white,
      secondary: clay,
      onSecondary: Colors.white,
      error: rose,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      background: sand,
      onBackground: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: sand,
      dividerColor: const Color(0xFFE6DDD5),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: mist),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE7DED5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: teal, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.white.withOpacity(0.72),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: slate,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF7EA4B1),
      onPrimary: night,
      secondary: Color(0xFFC7A58F),
      onSecondary: night,
      error: Color(0xFFD88D90),
      onError: night,
      surface: Color(0xFF18212A),
      onSurface: Colors.white,
      background: night,
      onBackground: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: night,
      dividerColor: const Color(0xFF273645),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: slate,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF33495A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF33495A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF7EA4B1), width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF18212A),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      listTileTheme: const ListTileThemeData(
        dense: false,
        contentPadding: EdgeInsets.symmetric(horizontal: 8),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF17212A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A2530),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

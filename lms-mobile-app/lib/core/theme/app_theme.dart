import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette LMS-Frontend (Tailwind Dark Theme) ──────────────────────────────
  static const Color eptBlue       = Color(0xFF3B82F6); // --accent (blue-500)
  static const Color eptBlueDark   = Color(0xFF2563EB); // --accent-hover (blue-600)
  static const Color eptBlueLight  = Color(0xFF60A5FA); // blue-400
  // eptGold removed — was identical to eptBlue. Use eptBlue directly.
  static const Color tealDark      = Color(0xFF065F46); // emerald-900 (meeting banners bg)
  static const Color teal          = Color(0xFF0D9488); // teal-600
  static const Color emerald       = Color(0xFF10B981); // emerald-500 (live indicators)
  static const Color tealText      = Color(0xFF022C22); // dark text on teal/emerald bg
  static const Color surface       = Color(0xFF0F172A); // --bg-base (slate-900)
  static const Color surfaceCard   = Color(0xFF1E293B); // --bg-card (slate-800)
  static const Color surfaceLift   = Color(0xFF334155); // --bg-hover (slate-700)
  static const Color onSurface     = Color(0xFFF1F5F9); // --text-primary (slate-100)
  static const Color onSurfaceSub  = Color(0xFF94A3B8); // --text-secondary (slate-400)
  static const Color divider       = Color(0xFF334155); // --border (slate-700)
  static const Color success       = Color(0xFF16A34A); // --success
  static const Color warning       = Color(0xFFD97706); // --warning
  static const Color amber         = Color(0xFFF59E0B); // amber-500 (notifications)
  static const Color danger        = Color(0xFFDC2626); // --danger
  static const Color info          = Color(0xFF0284C7); // --info

  // ── Border Radius Tokens ──────────────────────────────────────────────────
  static const double radiusSm  = 8.0;
  static const double radiusMd  = 12.0;
  static const double radiusLg  = 16.0;
  static const double radiusXl  = 20.0;
  static const double radiusXxl = 24.0;

  // ── Spacing Tokens ────────────────────────────────────────────────────────
  static const double spacingXs  = 4.0;
  static const double spacingSm  = 8.0;
  static const double spacingMd  = 12.0;
  static const double spacingLg  = 16.0;
  static const double spacingXl  = 20.0;
  static const double spacingXxl = 24.0;
  static const double spacing3xl = 32.0;
  static const double spacing4xl = 40.0;

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [eptBlueDark, eptBlue, eptBlueLight],
  );

  static const LinearGradient meetingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealDark, Color(0xFF134E4A)], // emerald-900 → teal-900
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceCard, surfaceLift],
  );

  // ── Design Tokens (Glassmorphism & Elevation) ─────────────────────────────
  static const double glassBlur = 12.0;
  static const double glassOpacity = 0.7;

  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: (isDark ? surfaceCard : Colors.white).withOpacity(glassOpacity),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
        width: 0.5,
      ),
    );
  }

  static List<BoxShadow> get modernShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  // ── Text Style Helpers ────────────────────────────────────────────────────
  // Usage: Text('Title', style: AppTheme.heading(context))
  static TextStyle heading(BuildContext context) => 
    Theme.of(context).textTheme.headlineMedium!;
  
  static TextStyle title(BuildContext context) => 
    Theme.of(context).textTheme.titleLarge!;
  
  static TextStyle subtitle(BuildContext context) => 
    Theme.of(context).textTheme.titleMedium!;
  
  static TextStyle body(BuildContext context) => 
    Theme.of(context).textTheme.bodyLarge!;
  
  static TextStyle caption(BuildContext context) => 
    Theme.of(context).textTheme.bodySmall!;
  
  static TextStyle label(BuildContext context) => 
    Theme.of(context).textTheme.labelLarge!;

  // ── Common Text Styles (shortcuts) ────────────────────────────────────────
  // White text variants (for colored backgrounds)
  static const TextStyle whiteTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle whiteBody = TextStyle(
    color: Colors.white,
    fontSize: 14,
  );

  static const TextStyle whiteCaption = TextStyle(
    color: Colors.white,
    fontSize: 12,
  );

  // Small labels/badges
  static const TextStyle smallBold = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle tinyBold = TextStyle(
    fontSize: 7,
    fontWeight: FontWeight.bold,
  );

  // ── Thème Sombre ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: surface, // #0F172A
      colorScheme: const ColorScheme.dark(
        primary: eptBlue,
        secondary: eptBlue,
        surface: surfaceCard, // #1E293B
        onSurface: onSurface, // #F1F5F9
        outline: divider,
      ),
      dividerColor: divider,
      cardColor: surfaceCard,
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: onSurfaceSub, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: onSurface),
          bodyMedium: TextStyle(color: onSurfaceSub),
          bodySmall: TextStyle(color: onSurfaceSub, fontSize: 12),
          labelLarge: TextStyle(color: eptBlue, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: eptBlueDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceCard,
        selectedItemColor: eptBlue,
        unselectedItemColor: onSurfaceSub,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLift,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: eptBlue),
        ),
        hintStyle: const TextStyle(color: onSurfaceSub),
        labelStyle: const TextStyle(color: onSurfaceSub),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: eptBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLift,
        contentTextStyle: const TextStyle(color: onSurface, fontFamily: 'Inter'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Thème Clair ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // --bg-elevated
      colorScheme: const ColorScheme.light(
        primary: eptBlue,
        secondary: eptBlueDark,
        surface: Colors.white, // --bg-base / --bg-card
        onSurface: Color(0xFF0F172A), // --text-primary
        outline: Color(0xFFE2E8F0), // --border
      ),
      dividerColor: const Color(0xFFE2E8F0),
      cardColor: Colors.white,
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
          displayMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: Color(0xFF0F172A)),
          bodyMedium: TextStyle(color: Color(0xFF64748B)),
          bodySmall: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          labelLarge: TextStyle(color: eptBlueDark, fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: eptBlueDark,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: eptBlue),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and theme for swipedel.
///
/// The app is a dark, quiet stage so the media is the hero. The one place with
/// personality is the monospace "spec strip" — file size and date rendered as
/// precise mono pills. Everything else stays understated.
class AppColors {
  AppColors._();

  /// App canvas.
  static const ink = Color(0xFF0E0F13);

  /// Cards, sheets, tiles.
  static const surface = Color(0xFF16181F);

  /// A slightly lifted surface for pills/overlays.
  static const surfaceHigh = Color(0xFF20232C);

  /// Primary text / icons (warm off-white).
  static const mist = Color(0xFFF4F1EA);

  /// Captions, secondary text.
  static const muted = Color(0xFF8A8F9C);

  /// Left-swipe directional glow.
  static const rose = Color(0xFFFF4D6D);

  /// Right-swipe directional glow.
  static const teal = Color(0xFF2DD4BF);

  /// Hairline dividers / borders.
  static const line = Color(0x1AF4F1EA);
}

class AppRadii {
  AppRadii._();
  static const card = 24.0;
  static const tile = 18.0;
  static const pill = 999.0;
}

class AppTheme {
  AppTheme._();

  /// Display face — album names, headers.
  static TextStyle display(
    BuildContext context, {
    double? size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.mist,
      letterSpacing: letterSpacing,
      height: 1.1,
    );
  }

  /// Body face — general UI text.
  static TextStyle body(
    BuildContext context, {
    double? size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.mist,
      height: 1.4,
    );
  }

  /// Mono face — the spec strip (size, date, counter, timecodes).
  static TextStyle mono(
    BuildContext context, {
    double? size,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.2,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.mist,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.teal,
        secondary: AppColors.rose,
        onSurface: AppColors.mist,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.mist,
        displayColor: AppColors.mist,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.mist,
      ),
      splashColor: AppColors.teal.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
    );
  }
}

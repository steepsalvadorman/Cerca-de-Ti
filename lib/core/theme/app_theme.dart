import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// App-wide Material theme built from the Cerca palette (Sora body copy,
/// Lora headings) so that default-styled widgets — dialogs, snackbars,
/// bare TextFields, progress indicators, fallback buttons — match the
/// bespoke screens instead of falling back to Material's stock blue/Roboto.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.cercaPrimary,
      brightness: Brightness.light,
      primary: AppColors.cercaPrimary,
      surface: AppColors.cercaBackground,
      error: AppColors.cercaDangerText,
    );

    final buttonTextStyle = GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600);
    final roundedShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cercaBackground,
      // A calmer cross-fade instead of Android's default slide/zoom — reads
      // closer to the editorial, unhurried feel of the rest of the design.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      textTheme: GoogleFonts.soraTextTheme().copyWith(
        displayLarge: GoogleFonts.lora(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.cercaTextPrimary),
        displayMedium: GoogleFonts.lora(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.cercaTextPrimary),
        headlineLarge: GoogleFonts.lora(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.cercaTextPrimary),
        headlineMedium: GoogleFonts.lora(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.cercaTextPrimary),
        bodyLarge: GoogleFonts.sora(fontSize: 15, color: AppColors.cercaTextPrimary),
        bodyMedium: GoogleFonts.sora(fontSize: 13.5, color: AppColors.cercaTextPrimary),
        bodySmall: GoogleFonts.sora(fontSize: 12, color: AppColors.cercaTextSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cercaPrimary,
        linearTrackColor: AppColors.cercaChipTrack,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cercaPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFC9B8B4),
          textStyle: buttonTextStyle,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: roundedShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cercaPrimary,
          side: const BorderSide(color: AppColors.cercaPrimary),
          textStyle: buttonTextStyle,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: roundedShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cercaPrimary,
          textStyle: buttonTextStyle,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.sora(fontSize: 14, color: AppColors.cercaTextMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cercaBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cercaBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cercaPrimary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cercaDangerText),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cercaBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.lora(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.cercaTextPrimary),
        contentTextStyle: GoogleFonts.sora(fontSize: 13.5, color: AppColors.cercaTextSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cercaTextPrimary,
        contentTextStyle: GoogleFonts.sora(fontSize: 13, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cercaBorder, thickness: 1, space: 1),
    );
  }
}

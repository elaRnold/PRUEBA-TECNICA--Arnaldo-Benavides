import 'package:flutter/material.dart';

/// Paleta de Consware (tomada de consware.com.co) y colores semánticos de estado.
abstract final class AppColors {
  static const navy = Color(0xFF03045E);
  static const cyan = Color(0xFF00BEFB);
  static const ink = Color(0xFF343638);
  static const muted = Color(0xFF6B7079); // #848991 oscurecido para cumplir 4.5:1 sobre blanco
  static const line = Color(0xFFDCDEE6);
  static const page = Color(0xFFEEF0F5); // más oscuro que #F8F8F8 para separar las tarjetas blancas
  static const navyTint = Color(0xFFEDEDF7);

  static const pendingBg = Color(0xFFFFF3D6);
  static const pendingFg = Color(0xFF7A4D00);
  static const approvedBg = Color(0xFFE2F4E8);
  static const approvedFg = Color(0xFF17633A);
  static const rejectedBg = Color(0xFFFCE6E6);
  static const rejectedFg = Color(0xFF9F2424);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    onPrimary: Colors.white,
    secondary: AppColors.cyan,
    onSecondary: AppColors.navy,
    surface: Colors.white,
    onSurface: AppColors.ink,
    outline: AppColors.muted,
    outlineVariant: AppColors.line,
    error: AppColors.rejectedFg,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Poppins');
  final text = base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.page,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.navy, 2),
      errorBorder: border(AppColors.rejectedFg),
      focusedErrorBorder: border(AppColors.rejectedFg, 2),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w500),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.cyan,
      foregroundColor: AppColors.navy,
      elevation: 2,
      extendedTextStyle: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: AppColors.navy,
      side: const BorderSide(color: AppColors.line),
      labelStyle: const TextStyle(fontFamily: 'Poppins', color: AppColors.ink, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(
        fontFamily: 'Poppins',
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      contentTextStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.navy),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.navy,
      selectionColor: AppColors.cyan.withValues(alpha: 0.35),
      selectionHandleColor: AppColors.cyan,
    ),
  );
}

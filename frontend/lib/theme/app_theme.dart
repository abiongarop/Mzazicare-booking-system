
import 'package:flutter/material.dart';

/// Shared visual system for MzaziCare.
class MzaziCareColors {
  MzaziCareColors._();

  // Light theme
  static const Color primary = Color(0xFFC8758D);
  static const Color primaryDark = Color(0xFFA95570);
  static const Color background = Color(0xFFFFF6F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFFF0F3);
  static const Color accent = Color(0xFFF6DDE4);
  static const Color border = Color(0xFFF1DCE3);
  static const Color text = Color(0xFF593847);
  static const Color textMuted = Color(0xFF745C67);

  // Dark theme
  static const Color darkPrimary = Color(0xFFE49AAF);
  static const Color darkPrimaryDark = Color(0xFFC8758D);
  static const Color darkBackground = Color(0xFF211820);
  static const Color darkSurface = Color(0xFF30232D);
  static const Color darkSurfaceSoft = Color(0xFF3B2935);
  static const Color darkAccent = Color(0xFF593847);
  static const Color darkBorder = Color(0xFF59404D);
  static const Color darkText = Color(0xFFFFF7FA);
  static const Color darkTextMuted = Color(0xFFE6D5DD);

  // Shared status colours
  static const Color success = Color(0xFF39836B);
  static const Color warning = Color(0xFFD28A42);
  static const Color error = Color(0xFFB94B5B);
}

class MzaziCareTheme {
  MzaziCareTheme._();

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        primary: MzaziCareColors.primary,
        primaryDark: MzaziCareColors.primaryDark,
        background: MzaziCareColors.background,
        surface: MzaziCareColors.surface,
        surfaceSoft: MzaziCareColors.surfaceSoft,
        accent: MzaziCareColors.accent,
        border: MzaziCareColors.border,
        text: MzaziCareColors.text,
        textMuted: MzaziCareColors.textMuted,
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        primary: MzaziCareColors.darkPrimary,
        primaryDark: MzaziCareColors.darkPrimaryDark,
        background: MzaziCareColors.darkBackground,
        surface: MzaziCareColors.darkSurface,
        surfaceSoft: MzaziCareColors.darkSurfaceSoft,
        accent: MzaziCareColors.darkAccent,
        border: MzaziCareColors.darkBorder,
        text: MzaziCareColors.darkText,
        textMuted: MzaziCareColors.darkTextMuted,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color primaryDark,
    required Color background,
    required Color surface,
    required Color surfaceSoft,
    required Color accent,
    required Color border,
    required Color text,
    required Color textMuted,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark
          ? const Color(0xFF30202A)
          : Colors.white,
      primaryContainer: accent,
      onPrimaryContainer: text,
      secondary: primaryDark,
      onSecondary: Colors.white,
      secondaryContainer: surfaceSoft,
      onSecondaryContainer: text,
      error: MzaziCareColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: border,
    );

    final textTheme = TextTheme(
      displayLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: text,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        color: text,
        fontWeight: FontWeight.bold,
      ),
      headlineLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: text,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: text,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: text),
      bodyMedium: TextStyle(color: text),
      bodySmall: TextStyle(color: textMuted),
      labelLarge: TextStyle(
        color: text,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(color: textMuted),
      labelSmall: TextStyle(color: textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: 'Roboto',
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: text),
      ),

      iconTheme: IconThemeData(color: text),

      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 1 : 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark
              ? const Color(0xFF30202A)
              : Colors.white,
          disabledBackgroundColor: border,
          disabledForegroundColor: textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSoft,
        hintStyle: TextStyle(color: textMuted),
        labelStyle: TextStyle(color: textMuted),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: MzaziCareColors.error,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: accent,
        labelStyle: TextStyle(color: text),
        secondaryLabelStyle: TextStyle(color: text),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: text,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        textStyle: TextStyle(color: text),
        surfaceTintColor: Colors.transparent,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: text),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor:
              const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: text),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: textMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF493541)
            : MzaziCareColors.text,
        contentTextStyle: const TextStyle(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }
          return surfaceSoft;
        }),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.25),
        selectionHandleColor: primary,
      ),
    );
  }
}

/// Standard full-width page wrapper.
class MzaziPage extends StatelessWidget {
  const MzaziPage({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 28),
    this.scrollable = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: double.infinity,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (!scrollable) {
      return SafeArea(child: content);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: content,
      ),
    );
  }
}

/// Consistent section heading for dashboards and forms.
class MzaziSectionHeader extends StatelessWidget {
  const MzaziSectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

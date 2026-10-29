import 'package:flutter/material.dart';

// ============================================
// FLUENT 2 — DESIGN TOKENS (EMERALD GREEN)
// ============================================
class FluentColors {
  static const Color accent = Color(0xFF10B981);
  static const Color accentDark = Color(0xFF059669);
  static const Color accentDarker = Color(0xFF047857);
  static const Color accentLight = Color(0xFF34D399);
  static const Color accentLighter = Color(0xFF6EE7B7);
  static const Color accentSoft = Color(0xFFD1FAE5);

  static const Color gradStart = Color(0xFFCDE89A);
  static const Color gradMid = Color(0xFF4CB963);
  static const Color gradEnd = Color(0xFF059669);

  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentYellow = Color(0xFFFBBF24);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color likeRed = Color(0xFFEF4444);

  // ============================================
  // ⭐ LIGHT MODE — CHỮ ĐEN ĐẬM
  // ============================================
  static const Color lightBg = Color(0xFFF7F9F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFFAFCFB);
  static const Color lightMica = Color(0xF2F7F9F8);
  static const Color lightMicaDark = Color(0xF2EDF2F0);

  static const Color lightText = Color(0xFF0F172A);
  static const Color lightSubText = Color(0xFF1A1A1A);
  static const Color lightMuted = Color(0xFF4A4A4A);

  static const Color lightBorder = Color(0xFFE2E8E5);
  static const Color lightBorderStrong = Color(0xFFCBD5D0);
  static const Color lightDivider = Color(0xFFEDF2F0);
  static const Color lightInputBg = Color(0xFFF8FAF9);
  static const Color lightHover = Color(0xFFF1F5F3);
  static const Color lightPressed = Color(0xFFE8EDEB);

  // ============================================
  // ⭐ DARK MODE — CHỮ TRẮNG SÁNG
  // ============================================
  static const Color darkBg = Color(0xFF0D1411);
  static const Color darkSurface = Color(0xFF151D19);
  static const Color darkCard = Color(0xFF1A2620);
  static const Color darkCardAlt = Color(0xFF212E27);
  static const Color darkMica = Color(0xF2151D19);
  static const Color darkMicaDark = Color(0xF20D1411);

  static const Color darkText = Color(0xFFF0F5F2);
  static const Color darkSubText = Color(0xFFE5E5E5);
  static const Color darkMuted = Color(0xFFB8C2BC);

  static const Color darkBorder = Color(0xFF2D3D34);
  static const Color darkBorderStrong = Color(0xFF3D4D44);
  static const Color darkDivider = Color(0xFF283831);
  static const Color darkInputBg = Color(0xFF1E2A24);
  static const Color darkHover = Color(0xFF26332C);
  static const Color darkPressed = Color(0xFF2E3D35);

  static const Color primary = Color(0xFF10B981);
  static const Color primaryDark = Color(0xFF059669);
  static const Color accentGreen = Color(0xFF10B981);
}

class FluentRadius {
  static const double xsmall = 2;
  static const double small = 4;
  static const double medium = 8;
  static const double large = 12;
  static const double xlarge = 16;
  static const double xxlarge = 24;
  static const double circle = 9999;
}

class FluentSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

class FluentDuration {
  static const Duration fastest = Duration(milliseconds: 100);
  static const Duration faster = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
}

class AppGradients {
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCDE89A), Color(0xFF4CB963), Color(0xFF059669)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient fluentAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient softGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6EE7B7), Color(0xFF10B981)],
  );

  static const LinearGradient deepGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF047857), Color(0xFF065F46)],
  );

  static const LinearGradient meshGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6EE7B7), Color(0xFF10B981), Color(0xFF047857)],
  );

  static const LinearGradient storyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [FluentColors.accentPink, FluentColors.accentYellow],
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  );
}

class FluentShadows {
  static List<BoxShadow> card({bool isDark = false}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> raised({bool isDark = false}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> floating({bool isDark = false, Color? color}) => [
        BoxShadow(
          color: (color ?? FluentColors.accent)
              .withValues(alpha: isDark ? 0.35 : 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: (color ?? FluentColors.accent)
              .withValues(alpha: isDark ? 0.25 : 0.15),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.4),
          blurRadius: 16,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ];
}

class AppColors {
  static const Color gradStart = FluentColors.gradStart;
  static const Color gradMid = FluentColors.gradMid;
  static const Color gradEnd = FluentColors.gradEnd;
  static const Color accentPink = FluentColors.accentPink;
  static const Color accentCyan = FluentColors.accentCyan;
  static const Color accentYellow = FluentColors.accentYellow;
  static const Color likeRed = FluentColors.likeRed;
  static const Color lightBg = FluentColors.lightBg;
  static const Color lightCard = FluentColors.lightCard;
  static const Color lightText = FluentColors.lightText;
  static const Color lightSubText = FluentColors.lightSubText;
  static const Color lightBorder = FluentColors.lightBorder;
  static const Color lightDivider = FluentColors.lightDivider;
  static const Color lightInputBg = FluentColors.lightInputBg;
  static const Color darkBg = FluentColors.darkBg;
  static const Color darkCard = FluentColors.darkCard;
  static const Color darkText = FluentColors.darkText;
  static const Color darkSubText = FluentColors.darkSubText;
  static const Color darkBorder = FluentColors.darkBorder;
  static const Color darkDivider = FluentColors.darkDivider;
  static const Color darkInputBg = FluentColors.darkInputBg;
  static const Color primary = FluentColors.primary;
  static const Color primaryDark = FluentColors.primaryDark;
  static const Color accent = FluentColors.accentGreen;
}

// ============================================
// ⭐ TYPOGRAPHY — DÙNG FONT HỆ THỐNG
// Android = Roboto | iOS = SF Pro | Windows = Segoe UI
// ============================================
class FluentTypography {
  static TextTheme buildTextTheme({
    required Brightness brightness,
    required Color text,
    required Color subText,
  }) {
    // ⭐ KHÔNG khai báo fontFamily → dùng font hệ thống tự động
    TextStyle s({
      required double size,
      required FontWeight weight,
      double? height,
      double? letterSpacing,
      Color? color,
    }) =>
        TextStyle(
          fontSize: size,
          fontWeight: weight,
          height: height ?? 1.4,
          letterSpacing: letterSpacing ?? -0.1,
          color: color ?? text,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return TextTheme(
      // ⭐ DISPLAY
      displayLarge: s(
          size: 52, weight: FontWeight.w700, height: 1.1, letterSpacing: -2),
      displayMedium: s(
          size: 40, weight: FontWeight.w700, height: 1.15, letterSpacing: -1.5),
      displaySmall: s(
          size: 32, weight: FontWeight.w600, height: 1.2, letterSpacing: -1),

      // ⭐ HEADLINE
      headlineLarge: s(
          size: 28, weight: FontWeight.w600, height: 1.25, letterSpacing: -0.5),
      headlineMedium: s(
          size: 24, weight: FontWeight.w600, height: 1.3, letterSpacing: -0.4),
      headlineSmall: s(
          size: 20, weight: FontWeight.w600, height: 1.35, letterSpacing: -0.2),

      // ⭐ TITLE
      titleLarge: s(
          size: 18, weight: FontWeight.w600, height: 1.35, letterSpacing: -0.2),
      titleMedium: s(
          size: 16, weight: FontWeight.w600, height: 1.4, letterSpacing: -0.1),
      titleSmall: s(
          size: 14, weight: FontWeight.w600, height: 1.4, letterSpacing: 0),

      // ⭐ BODY — Đậm hơn để đọc rõ trên Android
      bodyLarge: s(
          size: 16, weight: FontWeight.w500, height: 1.55, letterSpacing: 0),
      bodyMedium: s(
          size: 14, weight: FontWeight.w500, height: 1.5, letterSpacing: 0.1),
      bodySmall: s(
          size: 13,
          weight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0.1,
          color: subText),

      // ⭐ LABEL — Đậm cho dễ đọc
      labelLarge: s(
          size: 14, weight: FontWeight.w600, height: 1.4, letterSpacing: 0.2),
      labelMedium: s(
          size: 12,
          weight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.3,
          color: subText),
      labelSmall: s(
          size: 11,
          weight: FontWeight.w600,
          height: 1.4,
          letterSpacing: 0.5,
          color: subText),
    );
  }
}

// ============================================
// THEME BUILDER — FLUENT 2 + FONT HỆ THỐNG
// ============================================
class AppTheme {
  static ThemeData lightTheme = _buildTheme(Brightness.light);
  static ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? FluentColors.darkBg : FluentColors.lightBg;
    final surface =
        isDark ? FluentColors.darkSurface : FluentColors.lightSurface;
    final text = isDark ? FluentColors.darkText : FluentColors.lightText;
    final subText =
        isDark ? FluentColors.darkSubText : FluentColors.lightSubText;
    final border =
        isDark ? FluentColors.darkBorder : FluentColors.lightBorder;
    final divider =
        isDark ? FluentColors.darkDivider : FluentColors.lightDivider;
    final inputBg =
        isDark ? FluentColors.darkInputBg : FluentColors.lightInputBg;
    final hover = isDark ? FluentColors.darkHover : FluentColors.lightHover;

    final textTheme = FluentTypography.buildTextTheme(
      brightness: brightness,
      text: text,
      subText: subText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: FluentColors.accent,
      // ⭐ KHÔNG khai báo fontFamily → dùng font hệ thống (Roboto/SF Pro)
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      colorScheme: isDark
          ? const ColorScheme.dark(
              primary: FluentColors.accent,
              onPrimary: Colors.white,
              primaryContainer: FluentColors.darkCardAlt,
              onPrimaryContainer: FluentColors.accentLight,
              secondary: FluentColors.accentLight,
              onSecondary: Colors.white,
              surface: FluentColors.darkCard,
              onSurface: FluentColors.darkText,
              surfaceContainerHighest: FluentColors.darkCardAlt,
              onSurfaceVariant: FluentColors.darkSubText,
              outline: FluentColors.darkBorder,
              error: FluentColors.likeRed,
            )
          : const ColorScheme.light(
              primary: FluentColors.accent,
              onPrimary: Colors.white,
              primaryContainer: FluentColors.accentSoft,
              onPrimaryContainer: FluentColors.accentDarker,
              secondary: FluentColors.accentDark,
              onSecondary: Colors.white,
              surface: FluentColors.lightSurface,
              onSurface: FluentColors.lightText,
              surfaceContainerHighest: FluentColors.lightCardAlt,
              onSurfaceVariant: FluentColors.lightSubText,
              outline: FluentColors.lightBorder,
              error: FluentColors.likeRed,
            ),

      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: text, size: 20),
        titleTextStyle: textTheme.titleLarge,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FluentSpacing.lg,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FluentRadius.medium),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FluentRadius.medium),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FluentRadius.medium),
          borderSide: const BorderSide(color: FluentColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FluentRadius.medium),
          borderSide: const BorderSide(color: FluentColors.likeRed, width: 1),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? FluentColors.darkMuted : FluentColors.lightMuted,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: subText),
        floatingLabelStyle: textTheme.labelLarge?.copyWith(
          color: FluentColors.accent,
        ),
      ),

      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),

      cardTheme: CardThemeData(
        color: isDark ? FluentColors.darkCard : FluentColors.lightCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluentRadius.large),
          side: BorderSide(color: border, width: 0.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FluentColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: FluentSpacing.xl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluentRadius.medium),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            letterSpacing: 0.2,
            fontSize: 15,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FluentColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: FluentSpacing.xl,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluentRadius.medium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FluentColors.accent,
          padding: const EdgeInsets.symmetric(
            horizontal: FluentSpacing.md,
            vertical: FluentSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluentRadius.small),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          padding: const EdgeInsets.symmetric(
            horizontal: FluentSpacing.xl,
            vertical: 14,
          ),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluentRadius.medium),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          highlightColor: hover,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FluentRadius.small),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? FluentColors.darkCardAlt : const Color(0xFF202020),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluentRadius.medium),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        modalBarrierColor: Colors.black.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FluentRadius.xxlarge),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluentRadius.xlarge),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: subText),
      ),

      chipTheme: ChipThemeData(
        backgroundColor:
            isDark ? FluentColors.darkCardAlt : FluentColors.lightCardAlt,
        selectedColor: FluentColors.accentSoft,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FluentRadius.small),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: FluentSpacing.md,
          vertical: 6,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FluentColors.accent,
        linearTrackColor: FluentColors.accentSoft,
        circularTrackColor: FluentColors.accentSoft,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return isDark ? const Color(0xFF9CA8A2) : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return FluentColors.accent;
          }
          return isDark ? FluentColors.darkBorder : FluentColors.lightBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: FluentColors.accent,
        inactiveTrackColor: FluentColors.accent.withValues(alpha: 0.2),
        thumbColor: Colors.white,
        overlayColor: FluentColors.accent.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? FluentColors.darkCardAlt : const Color(0xFF202020),
          borderRadius: BorderRadius.circular(FluentRadius.small),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:
            isDark ? FluentColors.darkMica : FluentColors.lightMica,
        surfaceTintColor: Colors.transparent,
        indicatorColor: FluentColors.accent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: FluentColors.accent,
              fontWeight: FontWeight.w700,
            );
          }
          return textTheme.labelSmall?.copyWith(color: subText);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FluentColors.accent, size: 22);
          }
          return IconThemeData(color: subText, size: 22);
        }),
        elevation: 0,
      ),
    );
  }
}

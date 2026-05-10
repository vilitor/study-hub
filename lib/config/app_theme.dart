import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF2ECC8B);
  static const Color coral = Color(0xFFFF7B54);
  static const Color purple = Color(0xFF7C6CF0);
  static const Color softBlue = Color(0xFF4E9AF1);
  static const Color amber = Color(0xFFFFB946);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color success = Color(0xFF2ECC8B);
  static const Color error = Color(0xFFFF6B6B);
  static const Color warning = amber;
  static const Color info = softBlue;
  static const Color textPrimaryLight = Color(0xFF141A24);
  static const Color textPrimaryDark = Color(0xFFF5F7FA);
  static const Color textHint = Color(0xFF8F93AD);
  static const Color textSecondary = Color(0xFF6E7191);
  static const Color cardGrey = Color(0xFFE3E6ED);

  static const List<Color> subjectColors = [
    Color(0xFF2ECC8B),
    Color(0xFF7C6CF0),
    Color(0xFFFF7B54),
    Color(0xFF4E9AF1),
    Color(0xFFFFB946),
    Color(0xFFFF6B9D),
  ];

  static Color getSubjectColor(int index) {
    return subjectColors[index % subjectColors.length];
  }
}

@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  final Color accent;
  final Color accentSecondary;
  final Color accentTertiary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color scaffoldBase;
  final Color surfaceBase;
  final Color surface1;
  final Color surface2;
  final Color surfaceElevated;
  final Color surfaceOverlay;
  final Color borderSubtle;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color textOnAccent;
  final Color navBackground;
  final Color navActive;
  final Color navInactive;
  final Color modalBarrier;
  final Color modalSurface;
  final Color inputFill;
  final Color inputBorder;
  final Color inputFocus;
  final Color inputError;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color chipIdleBg;
  final Color chipIdleFg;

  const AppColorTokens({
    required this.accent,
    required this.accentSecondary,
    required this.accentTertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.scaffoldBase,
    required this.surfaceBase,
    required this.surface1,
    required this.surface2,
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.textOnAccent,
    required this.navBackground,
    required this.navActive,
    required this.navInactive,
    required this.modalBarrier,
    required this.modalSurface,
    required this.inputFill,
    required this.inputBorder,
    required this.inputFocus,
    required this.inputError,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.chipIdleBg,
    required this.chipIdleFg,
  });

  @override
  ThemeExtension<AppColorTokens> copyWith({
    Color? accent,
    Color? accentSecondary,
    Color? accentTertiary,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? scaffoldBase,
    Color? surfaceBase,
    Color? surface1,
    Color? surface2,
    Color? surfaceElevated,
    Color? surfaceOverlay,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? textOnAccent,
    Color? navBackground,
    Color? navActive,
    Color? navInactive,
    Color? modalBarrier,
    Color? modalSurface,
    Color? inputFill,
    Color? inputBorder,
    Color? inputFocus,
    Color? inputError,
    Color? chipSelectedBg,
    Color? chipSelectedFg,
    Color? chipIdleBg,
    Color? chipIdleFg,
  }) {
    return AppColorTokens(
      accent: accent ?? this.accent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      accentTertiary: accentTertiary ?? this.accentTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      scaffoldBase: scaffoldBase ?? this.scaffoldBase,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      navBackground: navBackground ?? this.navBackground,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      modalBarrier: modalBarrier ?? this.modalBarrier,
      modalSurface: modalSurface ?? this.modalSurface,
      inputFill: inputFill ?? this.inputFill,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocus: inputFocus ?? this.inputFocus,
      inputError: inputError ?? this.inputError,
      chipSelectedBg: chipSelectedBg ?? this.chipSelectedBg,
      chipSelectedFg: chipSelectedFg ?? this.chipSelectedFg,
      chipIdleBg: chipIdleBg ?? this.chipIdleBg,
      chipIdleFg: chipIdleFg ?? this.chipIdleFg,
    );
  }

  @override
  ThemeExtension<AppColorTokens> lerp(
    covariant ThemeExtension<AppColorTokens>? other,
    double t,
  ) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      accentTertiary: Color.lerp(accentTertiary, other.accentTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      scaffoldBase: Color.lerp(scaffoldBase, other.scaffoldBase, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      modalBarrier: Color.lerp(modalBarrier, other.modalBarrier, t)!,
      modalSurface: Color.lerp(modalSurface, other.modalSurface, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputFocus: Color.lerp(inputFocus, other.inputFocus, t)!,
      inputError: Color.lerp(inputError, other.inputError, t)!,
      chipSelectedBg: Color.lerp(chipSelectedBg, other.chipSelectedBg, t)!,
      chipSelectedFg: Color.lerp(chipSelectedFg, other.chipSelectedFg, t)!,
      chipIdleBg: Color.lerp(chipIdleBg, other.chipIdleBg, t)!,
      chipIdleFg: Color.lerp(chipIdleFg, other.chipIdleFg, t)!,
    );
  }
}

@immutable
class AppSpacingTokens extends ThemeExtension<AppSpacingTokens> {
  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double screenPadding;
  final double sectionGap;
  final double cardRadius;
  final double fieldRadius;
  final double pillRadius;

  const AppSpacingTokens({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.screenPadding,
    required this.sectionGap,
    required this.cardRadius,
    required this.fieldRadius,
    required this.pillRadius,
  });

  @override
  ThemeExtension<AppSpacingTokens> copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? screenPadding,
    double? sectionGap,
    double? cardRadius,
    double? fieldRadius,
    double? pillRadius,
  }) {
    return AppSpacingTokens(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      screenPadding: screenPadding ?? this.screenPadding,
      sectionGap: sectionGap ?? this.sectionGap,
      cardRadius: cardRadius ?? this.cardRadius,
      fieldRadius: fieldRadius ?? this.fieldRadius,
      pillRadius: pillRadius ?? this.pillRadius,
    );
  }

  @override
  ThemeExtension<AppSpacingTokens> lerp(
    covariant ThemeExtension<AppSpacingTokens>? other,
    double t,
  ) {
    if (other is! AppSpacingTokens) return this;
    double mix(double a, double b) => a + (b - a) * t;
    return AppSpacingTokens(
      xxs: mix(xxs, other.xxs),
      xs: mix(xs, other.xs),
      sm: mix(sm, other.sm),
      md: mix(md, other.md),
      lg: mix(lg, other.lg),
      xl: mix(xl, other.xl),
      xxl: mix(xxl, other.xxl),
      screenPadding: mix(screenPadding, other.screenPadding),
      sectionGap: mix(sectionGap, other.sectionGap),
      cardRadius: mix(cardRadius, other.cardRadius),
      fieldRadius: mix(fieldRadius, other.fieldRadius),
      pillRadius: mix(pillRadius, other.pillRadius),
    );
  }
}

@immutable
class AppElevationTokens extends ThemeExtension<AppElevationTokens> {
  final List<BoxShadow> low;
  final List<BoxShadow> medium;
  final List<BoxShadow> high;

  const AppElevationTokens({
    required this.low,
    required this.medium,
    required this.high,
  });

  @override
  ThemeExtension<AppElevationTokens> copyWith({
    List<BoxShadow>? low,
    List<BoxShadow>? medium,
    List<BoxShadow>? high,
  }) {
    return AppElevationTokens(
      low: low ?? this.low,
      medium: medium ?? this.medium,
      high: high ?? this.high,
    );
  }

  @override
  ThemeExtension<AppElevationTokens> lerp(
    covariant ThemeExtension<AppElevationTokens>? other,
    double t,
  ) {
    return t < 0.5 ? this : other ?? this;
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  AppColorTokens get colors => theme.extension<AppColorTokens>()!;
  AppSpacingTokens get spacing => theme.extension<AppSpacingTokens>()!;
  AppElevationTokens get elevations => theme.extension<AppElevationTokens>()!;
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? _darkColors : _lightColors;
    final spacing = _spacing;
    final elevations = isDark ? _darkElevations : _lightElevations;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: colors.accent,
        primary: colors.accent,
        secondary: colors.accentSecondary,
        error: colors.error,
        surface: colors.surface1,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: colors.scaffoldBase,
      extensions: [colors, spacing, elevations],
      textTheme: _buildTextTheme(colors),
      cardTheme: CardThemeData(
        color: colors.surface1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spacing.cardRadius),
          side: BorderSide(color: colors.borderSubtle),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.scaffoldBase,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.borderSubtle, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.md,
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: colors.textDisabled),
        prefixIconColor: colors.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spacing.fieldRadius),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spacing.fieldRadius),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spacing.fieldRadius),
          borderSide: BorderSide(color: colors.inputFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spacing.fieldRadius),
          borderSide: BorderSide(color: colors.inputError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spacing.fieldRadius),
          borderSide: BorderSide(color: colors.inputError, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: colors.error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          backgroundColor: colors.accent,
          foregroundColor: colors.textOnAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(spacing.fieldRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(spacing.fieldRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.chipIdleBg,
        selectedColor: colors.chipSelectedBg,
        secondarySelectedColor: colors.chipSelectedBg,
        side: BorderSide(color: colors.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spacing.pillRadius),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.chipIdleFg,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.modalSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spacing.cardRadius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: GoogleFonts.inter(
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spacing.fieldRadius),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(AppColorTokens colors) {
    return GoogleFonts.interTextTheme().copyWith(
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: colors.textSecondary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: colors.textPrimary),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: colors.textSecondary),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }

  static const AppSpacingTokens _spacing = AppSpacingTokens(
    xxs: 4,
    xs: 8,
    sm: 12,
    md: 16,
    lg: 20,
    xl: 24,
    xxl: 32,
    screenPadding: 20,
    sectionGap: 24,
    cardRadius: 20,
    fieldRadius: 16,
    pillRadius: 999,
  );

  static const AppColorTokens _lightColors = AppColorTokens(
    accent: AppColors.primaryGreen,
    accentSecondary: AppColors.purple,
    accentTertiary: AppColors.coral,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    scaffoldBase: Color(0xFFF4F7FB),
    surfaceBase: AppColors.white,
    surface1: AppColors.white,
    surface2: Color(0xFFF8FAFC),
    surfaceElevated: AppColors.white,
    surfaceOverlay: Color(0xFFFDFEFF),
    borderSubtle: Color(0xFFE4E9F2),
    borderStrong: Color(0xFFCCD6E4),
    textPrimary: Color(0xFF141A24),
    textSecondary: Color(0xFF5E697A),
    textDisabled: Color(0xFF98A2B3),
    textOnAccent: AppColors.white,
    navBackground: Color(0xF2FFFFFF),
    navActive: Color(0xFF18222F),
    navInactive: Color(0xFF6B7483),
    modalBarrier: Color(0x66111827),
    modalSurface: AppColors.white,
    inputFill: Color(0xFFF8FAFD),
    inputBorder: Color(0xFFD8E0EC),
    inputFocus: AppColors.primaryGreen,
    inputError: AppColors.error,
    chipSelectedBg: Color(0xFF18222F),
    chipSelectedFg: AppColors.white,
    chipIdleBg: Color(0xFFF3F6FB),
    chipIdleFg: Color(0xFF344054),
  );

  static const AppColorTokens _darkColors = AppColorTokens(
    accent: AppColors.primaryGreen,
    accentSecondary: Color(0xFF9587FF),
    accentTertiary: AppColors.coral,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    scaffoldBase: Color(0xFF0B1018),
    surfaceBase: Color(0xFF101722),
    surface1: Color(0xFF141C28),
    surface2: Color(0xFF182232),
    surfaceElevated: Color(0xFF1C2737),
    surfaceOverlay: Color(0xFF162030),
    borderSubtle: Color(0xFF223044),
    borderStrong: Color(0xFF314156),
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFB4C0D0),
    textDisabled: Color(0xFF728096),
    textOnAccent: Color(0xFF04140D),
    navBackground: Color(0xF2182230),
    navActive: AppColors.primaryGreen,
    navInactive: Color(0xFF98A2B3),
    modalBarrier: Color(0x8C04080F),
    modalSurface: Color(0xFF141C28),
    inputFill: Color(0xFF111A26),
    inputBorder: Color(0xFF223044),
    inputFocus: AppColors.primaryGreen,
    inputError: AppColors.error,
    chipSelectedBg: AppColors.primaryGreen,
    chipSelectedFg: Color(0xFF03110B),
    chipIdleBg: Color(0xFF182232),
    chipIdleFg: Color(0xFFD5DDE8),
  );

  static final AppElevationTokens _lightElevations = AppElevationTokens(
    low: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
    medium: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
    high: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 30,
        offset: const Offset(0, 16),
      ),
    ],
  );

  static final AppElevationTokens _darkElevations = AppElevationTokens(
    low: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
    medium: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.24),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ],
    high: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.36),
        blurRadius: 36,
        offset: const Offset(0, 18),
      ),
    ],
  );
}

import 'package:flutter/material.dart';

class BankColors {
  const BankColors._();

  static const Color background = Color(0xFFF3F6FB);
  static const Color backgroundStrong = Color(0xFFE8EEF8);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF8FAFD);
  static const Color outline = Color(0xFFD8E1EE);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF5C6C86);
  static const Color textTertiary = Color(0xFF91A0B8);
  static const Color primary = Color(0xFF185BEF);
  static const Color primaryDark = Color(0xFF0E2149);
  static const Color primarySoft = Color(0xFFE8EEFF);
  static const Color success = Color(0xFF14A36B);
  static const Color successSoft = Color(0xFFE7F8F0);
  static const Color warning = Color(0xFFF0B64E);
  static const Color warningSoft = Color(0xFFFFF3DE);
  static const Color danger = Color(0xFFE45A5A);
  static const Color dangerSoft = Color(0xFFFCEBEC);
  static const Color shadow = Color(0x180B1F44);
  static const Color heroStart = Color(0xFF0F2F72);
  static const Color heroEnd = Color(0xFF1A6CFF);
}

ThemeData buildBankTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: BankColors.primary,
      brightness: Brightness.light,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: BankColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: BankColors.primary,
      secondary: BankColors.warning,
      surface: BankColors.surface,
      onSurface: BankColors.textPrimary,
      error: BankColors.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: BankColors.textPrimary,
      displayColor: BankColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: BankColors.textPrimary,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: BankColors.textPrimary,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: BankColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BankColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: BankColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: BankColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: BankColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: BankColors.danger, width: 1.6),
      ),
      labelStyle: const TextStyle(
        color: BankColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(
        color: BankColors.textTertiary,
        fontSize: 14,
      ),
      prefixIconColor: BankColors.textSecondary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BankColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFBFD0F7),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        elevation: 0,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BankColors.primary,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: BankColors.surface,
      selectedColor: BankColors.primarySoft,
      secondarySelectedColor: BankColors.primarySoft,
      side: const BorderSide(color: BankColors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      labelStyle: const TextStyle(
        color: BankColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: const TextStyle(
        color: BankColors.primary,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: BankColors.primaryDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: BankColors.outline,
      thickness: 1,
      space: 1,
    ),
  );
}

class BankBackdrop extends StatelessWidget {
  const BankBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8FAFE), BankColors.background],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -40,
          child: _DecorativeOrb(
            size: 260,
            colors: [Color(0x301A6CFF), Color(0x001A6CFF)],
          ),
        ),
        Positioned(
          top: 140,
          right: -80,
          child: _DecorativeOrb(
            size: 220,
            colors: [Color(0x22F0B64E), Color(0x00F0B64E)],
          ),
        ),
        Positioned(
          bottom: -140,
          left: -40,
          child: _DecorativeOrb(
            size: 240,
            colors: [Color(0x1A14A36B), Color(0x0014A36B)],
          ),
        ),
      ],
    );
  }
}

class BankSurfaceCard extends StatelessWidget {
  const BankSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.color = BankColors.surface,
    this.borderColor,
    this.radius = 28,
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? BankColors.outline.withValues(alpha: 0.75),
        ),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: BankColors.shadow.withValues(alpha: 0.55),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
      ),
      child: child,
    );
  }
}

class BankSectionHeader extends StatelessWidget {
  const BankSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: BankColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: BankColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class BankSoftIconButton extends StatelessWidget {
  const BankSoftIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: BankColors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: BankColors.outline.withValues(alpha: 0.8),
            ),
          ),
          child: Icon(icon, color: BankColors.textPrimary, size: 21),
        ),
      ),
    );
  }
}

class BankStatusPill extends StatelessWidget {
  const BankStatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.backgroundColor = BankColors.primarySoft,
    this.foregroundColor = BankColors.primary,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorativeOrb extends StatelessWidget {
  const _DecorativeOrb({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Farbpalette der App. Es gibt eine dunkle und eine helle Variante; die
/// aktive Palette wird beim Erzeugen des Themes gesetzt und über
/// [TaqwaColors] gelesen.
class TaqwaPalette {
  const TaqwaPalette({
    required this.background,
    required this.oledBackground,
    required this.oledCard,
    required this.card,
    required this.cardRaised,
    required this.panel,
    required this.panelDeep,
    required this.chip,
    required this.border,
    required this.goldBorder,
    required this.gold,
    required this.goldLight,
    required this.goldDeep,
    required this.text,
    required this.muted,
    required this.mutedStrong,
    required this.green,
    required this.greenSurface,
    required this.red,
    required this.blueGreen,
    required this.onGold,
    required this.navBackground,
    required this.navIndicator,
    required this.shadow,
    required this.star,
    required this.field,
    required this.isLight,
  });

  final Color background;
  final Color oledBackground;
  final Color oledCard;
  final Color card;
  final Color cardRaised;
  final Color panel;
  final Color panelDeep;
  final Color chip;
  final Color border;
  final Color goldBorder;
  final Color gold;
  final Color goldLight;
  final Color goldDeep;
  final Color text;
  final Color muted;
  final Color mutedStrong;
  final Color green;
  final Color greenSurface;
  final Color red;
  final Color blueGreen;
  final Color onGold;
  final Color navBackground;
  final Color navIndicator;
  final Color shadow;
  final Color star;
  final Color field;
  final bool isLight;
}

/// Edles Dunkel mit Gold – die ursprüngliche Optik.
const darkPalette = TaqwaPalette(
  background: Color(0xFF0B0B0B),
  oledBackground: Color(0xFF000000),
  oledCard: Color(0xFF060606),
  card: Color(0xFF151515),
  cardRaised: Color(0xFF1B1A17),
  panel: Color(0xFF171614),
  panelDeep: Color(0xFF12100B),
  chip: Color(0xFF211A0D),
  border: Color(0xFF302D27),
  goldBorder: Color(0xFF65491F),
  gold: Color(0xFFE5A93C),
  goldLight: Color(0xFFF4C766),
  goldDeep: Color(0xFFB8862C),
  text: Color(0xFFF4F1E9),
  muted: Color(0xFF9C9A91),
  mutedStrong: Color(0xFF5A5A54),
  green: Color(0xFF31B981),
  greenSurface: Color(0xFF173A32),
  red: Color(0xFFD36B5D),
  blueGreen: Color(0xFF173A32),
  onGold: Color(0xFF17120A),
  navBackground: Color(0xF5101010),
  navIndicator: Color(0xFF332510),
  shadow: Color(0x44000000),
  star: Color(0xFFFFD882),
  field: Color(0xFF101010),
  isLight: false,
);

/// Helles, warmes Weiß mit sanften Gold- und Grautönen.
const lightPalette = TaqwaPalette(
  background: Color(0xFFFBF8F1),
  oledBackground: Color(0xFFFBF8F1),
  oledCard: Color(0xFFFFFFFF),
  card: Color(0xFFFFFFFF),
  cardRaised: Color(0xFFF8F3E8),
  panel: Color(0xFFFDFBF6),
  panelDeep: Color(0xFFF6F0E3),
  chip: Color(0xFFF3ECDC),
  border: Color(0xFFE7DDC9),
  goldBorder: Color(0xFFD8BC85),
  gold: Color(0xFFB07E1F),
  goldLight: Color(0xFF8A6212),
  goldDeep: Color(0xFFC99B3F),
  text: Color(0xFF201C14),
  muted: Color(0xFF7A7466),
  mutedStrong: Color(0xFF9B9484),
  green: Color(0xFF1F8F63),
  greenSurface: Color(0xFFE3F3EB),
  red: Color(0xFFC05A46),
  blueGreen: Color(0xFFE3F3EB),
  onGold: Color(0xFF1A1408),
  navBackground: Color(0xFFFDFAF3),
  navIndicator: Color(0xFFF2E3C2),
  shadow: Color(0x14000000),
  star: Color(0xFFC79A3E),
  field: Color(0xFFFFFFFF),
  isLight: true,
);

/// Statischer Zugriff auf die aktive Palette. Die Werte werden beim Aufbau
/// des Themes gesetzt, damit bestehende Widgets unverändert bleiben können.
class TaqwaColors {
  static TaqwaPalette _palette = darkPalette;

  /// Setzt die Palette für alle folgenden Builds.
  static void use(TaqwaPalette palette) => _palette = palette;

  /// Setzt die Palette passend zur Helligkeit.
  static void useBrightness(Brightness brightness) =>
      _palette = brightness == Brightness.light ? lightPalette : darkPalette;

  static TaqwaPalette get palette => _palette;

  static Color get background => _palette.background;
  static Color get oledBackground => _palette.oledBackground;
  static Color get oledCard => _palette.oledCard;
  static Color get card => _palette.card;
  static Color get cardRaised => _palette.cardRaised;
  static Color get panel => _palette.panel;
  static Color get panelDeep => _palette.panelDeep;
  static Color get chip => _palette.chip;
  static Color get border => _palette.border;
  static Color get goldBorder => _palette.goldBorder;
  static Color get gold => _palette.gold;
  static Color get goldLight => _palette.goldLight;
  static Color get goldDeep => _palette.goldDeep;
  static Color get text => _palette.text;
  static Color get muted => _palette.muted;
  static Color get mutedStrong => _palette.mutedStrong;
  static Color get green => _palette.green;
  static Color get greenSurface => _palette.greenSurface;
  static Color get red => _palette.red;
  static Color get blueGreen => _palette.blueGreen;
  static Color get onGold => _palette.onGold;
  static Color get navBackground => _palette.navBackground;
  static Color get navIndicator => _palette.navIndicator;
  static Color get shadow => _palette.shadow;
  static Color get star => _palette.star;
  static Color get field => _palette.field;
  static bool get isLight => _palette.isLight;
}

ThemeData taqwaTheme({
  bool oled = false,
  Brightness brightness = Brightness.dark,
}) {
  final light = brightness == Brightness.light;
  TaqwaColors.use(light ? lightPalette : darkPalette);
  final p = TaqwaColors.palette;
  final scheme = light
      ? ColorScheme.light(
          primary: p.gold,
          onPrimary: p.onGold,
          secondary: p.green,
          onSecondary: Colors.white,
          surface: p.card,
          onSurface: p.text,
          error: p.red,
          onError: Colors.white,
          outline: p.border,
        )
      : ColorScheme.dark(
          primary: p.gold,
          onPrimary: p.onGold,
          secondary: p.green,
          surface: oled ? p.oledCard : p.card,
          onSurface: p.text,
          error: p.red,
          outline: p.border,
        );

  return ThemeData(
    brightness: light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: light
        ? p.background
        : (oled ? p.oledBackground : p.background),
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
    dividerColor: p.border,
    splashColor: p.gold.withValues(alpha: 0.09),
    highlightColor: p.gold.withValues(alpha: 0.05),
    appBarTheme: AppBarTheme(
      backgroundColor: light
          ? p.background
          : (oled ? p.oledBackground : p.background),
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: p.goldLight),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.navBackground,
      indicatorColor: p.navIndicator,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? p.goldLight : p.muted,
          size: 22,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 9.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? p.goldLight : p.muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.goldBorder),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: light ? p.text : p.cardRaised,
      contentTextStyle: TextStyle(color: light ? p.background : p.text),
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? p.field : (oled ? const Color(0xFF080808) : p.field),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: p.muted, fontSize: 13),
      labelStyle: TextStyle(color: p.muted, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.gold),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.gold,
      selectionColor: p.gold.withValues(alpha: 0.25),
      selectionHandleColor: p.gold,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.gold : p.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.gold.withValues(alpha: 0.35)
            : p.border,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.gold,
        foregroundColor: p.onGold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.goldLight),
    ),
    listTileTheme: ListTileThemeData(iconColor: p.goldLight, textColor: p.text),
  );
}

class StarField extends StatelessWidget {
  const StarField({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final oled =
        !light &&
        Theme.of(context).scaffoldBackgroundColor == TaqwaColors.oledBackground;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.75, -0.9),
                radius: 1.1,
                colors: light
                    ? [
                        const Color(0xFFFFF4DC),
                        TaqwaColors.background,
                        const Color(0xFFF7F2E7),
                      ]
                    : oled
                    ? [
                        const Color(0xFF0C0803),
                        TaqwaColors.oledBackground,
                        TaqwaColors.oledBackground,
                      ]
                    : [
                        const Color(0xFF211708),
                        TaqwaColors.background,
                        TaqwaColors.background,
                      ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _StarsPainter(light: light)),
          ),
        ),
        child,
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(light ? 912 : 2407);
    final count = light ? 26 : 54;
    for (var i = 0; i < count; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = i % 9 == 0 ? 1.15 : 0.55;
      final opacity = light
          ? (i % 4 == 0 ? 0.16 : 0.08)
          : (i % 4 == 0 ? 0.56 : 0.23);
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = TaqwaColors.star.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) =>
      oldDelegate.light != light;
}

class TaqwaCard extends StatelessWidget {
  const TaqwaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.goldBorder = false,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool goldBorder;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: goldBorder ? TaqwaColors.goldBorder : TaqwaColors.border,
      ),
      boxShadow: [
        BoxShadow(
          color: TaqwaColors.shadow,
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 9,
      color: color ?? TaqwaColors.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
    ),
  );
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.xp,
    required this.initial,
    required this.onProfile,
  });
  final int xp;
  final String initial;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TaqwaColors.gold),
          color: TaqwaColors.chip,
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/branding/logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(
              Icons.nightlight_round,
              color: TaqwaColors.goldLight,
              size: 16,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: TextStyle(color: TaqwaColors.goldLight, fontSize: 10),
            ),
            const SizedBox(height: 1),
            Text(
              'TAQWA TRACK',
              style: TextStyle(
                color: TaqwaColors.goldLight,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      Icon(Icons.circle, color: TaqwaColors.green, size: 7),
      const SizedBox(width: 5),
      Text('Bereit', style: TextStyle(color: TaqwaColors.muted, fontSize: 9)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: TaqwaColors.cardRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TaqwaColors.border),
        ),
        child: Text(
          '★ $xp',
          style: TextStyle(
            color: TaqwaColors.goldLight,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
      const SizedBox(width: 7),
      InkWell(
        onTap: onProfile,
        borderRadius: BorderRadius.circular(20),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: TaqwaColors.chip,
          foregroundColor: TaqwaColors.goldLight,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(fontSize: 9, color: TaqwaColors.muted),
          ),
      ],
    ),
  );
}

String initials(String name) =>
    name.trim().isEmpty ? 'H' : name.trim().characters.first.toUpperCase();

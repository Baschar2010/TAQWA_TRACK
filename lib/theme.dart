import 'dart:math' as math;

import 'package:flutter/material.dart';

class TaqwaColors {
  static const background = Color(0xFF0B0B0B);
  static const oledBackground = Color(0xFF000000);
  static const oledCard = Color(0xFF060606);
  static const card = Color(0xFF151515);
  static const cardRaised = Color(0xFF1B1A17);
  static const border = Color(0xFF302D27);
  static const gold = Color(0xFFE5A93C);
  static const goldLight = Color(0xFFF4C766);
  static const text = Color(0xFFF4F1E9);
  static const muted = Color(0xFF9C9A91);
  static const green = Color(0xFF31B981);
  static const red = Color(0xFFD36B5D);
  static const blueGreen = Color(0xFF173A32);
}

ThemeData taqwaTheme({bool oled = false}) => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: oled
      ? TaqwaColors.oledBackground
      : TaqwaColors.background,
  colorScheme: ColorScheme.dark(
    primary: TaqwaColors.gold,
    secondary: TaqwaColors.green,
    surface: oled ? TaqwaColors.oledCard : TaqwaColors.card,
    error: TaqwaColors.red,
  ),
  useMaterial3: true,
  fontFamily: 'Roboto',
  appBarTheme: AppBarTheme(
    backgroundColor: oled ? TaqwaColors.oledBackground : TaqwaColors.background,
    foregroundColor: TaqwaColors.text,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: oled ? const Color(0xFF080808) : const Color(0xFF101010),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: const TextStyle(color: TaqwaColors.muted, fontSize: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TaqwaColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TaqwaColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TaqwaColors.gold),
    ),
  ),
);

class StarField extends StatelessWidget {
  const StarField({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final oled =
        Theme.of(context).scaffoldBackgroundColor == TaqwaColors.oledBackground;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.75, -0.9),
                radius: 1.1,
                colors: oled
                    ? const [
                        Color(0xFF0C0803),
                        TaqwaColors.oledBackground,
                        TaqwaColors.oledBackground,
                      ]
                    : const [
                        Color(0xFF211708),
                        TaqwaColors.background,
                        TaqwaColors.background,
                      ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _StarsPainter())),
        ),
        child,
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(2407);
    for (var i = 0; i < 54; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = i % 9 == 0 ? 1.15 : 0.55;
      final opacity = i % 4 == 0 ? 0.56 : 0.23;
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = const Color(0xFFFFD882).withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        color: goldBorder ? const Color(0xFF65491F) : TaqwaColors.border,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x44000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = TaqwaColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 9,
      color: color,
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
          color: const Color(0xFF1B160D),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/branding/logo.png',
            width: 30,
            height: 30,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const Icon(
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
            const Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              style: TextStyle(color: TaqwaColors.goldLight, fontSize: 10),
            ),
            const SizedBox(height: 1),
            const Text(
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
      const Icon(Icons.circle, color: TaqwaColors.green, size: 7),
      const SizedBox(width: 5),
      const Text(
        'Bereit',
        style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF18150F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TaqwaColors.border),
        ),
        child: Text(
          '★ $xp',
          style: const TextStyle(
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
          backgroundColor: const Color(0xFF211A0E),
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
            style: const TextStyle(fontSize: 9, color: TaqwaColors.muted),
          ),
      ],
    ),
  );
}

String initials(String name) =>
    name.trim().isEmpty ? 'H' : name.trim().characters.first.toUpperCase();

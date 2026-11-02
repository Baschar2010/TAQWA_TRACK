import 'package:flutter/material.dart';

import 'theme.dart';

/// Fortschrittsstufe eines Tages.
///
/// - [none]: noch nichts erledigt – neutrale Optik.
/// - [partial]: mindestens ein Gebet/Habit erledigt – grüne Belohnung.
/// - [complete]: alle Gebete des Tages erledigt – prominentes Gold.
enum DayTier { none, partial, complete }

/// Bestimmt die Belohnungsstufe aus erledigten und gesamten Einheiten.
DayTier dayTier(int done, int total) {
  if (total <= 0 || done <= 0) return DayTier.none;
  if (done >= total) return DayTier.complete;
  return DayTier.partial;
}

/// Auffälliges Gold für den vollständigen Tag (#FFD700).
const Color rewardGold = Color(0xFFFFD700);

/// Weiches Gold für Verläufe und Leuchten.
const Color rewardGoldSoft = Color(0xFFFFE79A);

/// Akzentfarbe passend zur Stufe.
Color tierColor(DayTier tier) => switch (tier) {
  DayTier.none => TaqwaColors.muted,
  DayTier.partial => TaqwaColors.green,
  DayTier.complete => rewardGold,
};

/// Dezente Flächenfarbe passend zur Stufe.
Color tierSurface(DayTier tier) => switch (tier) {
  DayTier.none => TaqwaColors.panel,
  DayTier.partial => TaqwaColors.green.withValues(alpha: 0.16),
  DayTier.complete => rewardGold.withValues(alpha: 0.18),
};

/// Kleiner goldener Stern als Abschluss-Badge.
///
/// Er wächst beim Erscheinen kurz auf, damit der vollständige Tag gefeiert
/// wird – ohne dauerhafte Animation, die Akku oder Tests belastet.
class RewardStar extends StatelessWidget {
  const RewardStar({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.25, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Semantics(
        label: 'Alle Gebete erledigt',
        child: Container(
          padding: EdgeInsets.all(size * 0.22),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [rewardGoldSoft, rewardGold],
            ),
            boxShadow: [
              BoxShadow(
                color: rewardGold.withValues(alpha: 0.55),
                blurRadius: size * 0.75,
                spreadRadius: size * 0.08,
              ),
            ],
          ),
          child: Icon(
            Icons.star_rounded,
            size: size,
            color: TaqwaColors.onGold,
          ),
        ),
      ),
    );
  }
}

/// Kurzes goldenes Aufleuchten über einem Widget.
///
/// Der Effekt läuft genau einmal, wenn [active] von `false` auf `true`
/// wechselt (oder das Widget bereits aktiv aufgebaut wird). Danach bleibt
/// nur die statische Gold-Optik des Kindes übrig.
class GoldFlash extends StatefulWidget {
  const GoldFlash({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = 14,
  });

  final bool active;
  final Widget child;
  final double borderRadius;

  @override
  State<GoldFlash> createState() => _GoldFlashState();
}

class _GoldFlashState extends State<GoldFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(GoldFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.active)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final strength =
                      1 - Curves.easeOut.transform(_controller.value);
                  if (strength <= 0.01) return const SizedBox.shrink();
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      color: rewardGold.withValues(alpha: 0.20 * strength),
                      boxShadow: [
                        BoxShadow(
                          color: rewardGold.withValues(alpha: 0.55 * strength),
                          blurRadius: 26 * strength,
                          spreadRadius: 3 * strength,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

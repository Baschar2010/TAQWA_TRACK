import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';

import 'app_controller.dart';
import 'app_info.dart';
import 'domain.dart';
import 'hadith_screen.dart';
import 'info_screens.dart';
import 'language.dart';
import 'onboarding_screen.dart';
import 'pairing_screen.dart';
import 'prayer_qibla_screens.dart';
import 'quran_screen.dart';
import 'tasbih_screen.dart';
import 'theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller});
  final TaqwaController controller;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 1;
  bool _showMotivation = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (c.error case final error?) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error, textAlign: TextAlign.center),
            ),
          ),
        );
      }
      if (!c.ready || c.settings == null) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: TaqwaColors.gold),
          ),
        );
      }
      if (!c.settings!.onboarded) {
        return OnboardingScreen(controller: c);
      }
      final text = AppText.of(Localizations.localeOf(context).languageCode);
      final pages = <Widget>[
        CalendarScreen(controller: c),
        _showMotivation
            ? MotivationScreen(
                controller: c,
                onBack: () => setState(() => _showMotivation = false),
              )
            : HomeScreen(
                controller: c,
                onProfile: () => _push(ProfileScreen(controller: c)),
                onMotivation: () => setState(() => _showMotivation = true),
              ),
        FamilyScreen(controller: c),
        PrayerTimesScreen(controller: c),
        QiblaScreen(controller: c),
      ];
      return Stack(
        children: [
          Scaffold(
            extendBody: true,
            body: StarField(
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: IndexedStack(
                      index: _showMotivation ? 1 : _tab,
                      children: pages,
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() {
                _tab = i;
                _showMotivation = false;
              }),
              backgroundColor: const Color(0xF5101010),
              indicatorColor: const Color(0xFF332510),
              height: 60,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month),
                  label: text.navCalendar,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: text.navHome,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.family_restroom_outlined),
                  selectedIcon: const Icon(Icons.family_restroom),
                  label: text.navFamily,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.mosque_outlined),
                  selectedIcon: const Icon(Icons.mosque),
                  label: text.navPrayer,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore),
                  label: text.navQibla,
                ),
              ],
            ),
          ),
          if (c.goldCelebrationPending)
            Positioned.fill(
              child: GoldCelebration(onDone: c.clearGoldCelebration),
            ),
        ],
      );
    },
  );

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Kurze Erfolgs-Animation, wenn der Tag von Grün auf Gold springt
/// (alle fünf Gebete erledigt).
class GoldCelebration extends StatefulWidget {
  const GoldCelebration({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<GoldCelebration> createState() => _GoldCelebrationState();
}

class _GoldCelebrationState extends State<GoldCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final appear = Curves.easeOutCubic.transform(
          (t / 0.25).clamp(0.0, 1.0),
        );
        final fade = t < 0.78 ? 1.0 : 1 - ((t - 0.78) / 0.22);
        final rise = Curves.easeOutCubic.transform(
          ((t - 0.55) / 0.45).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xE6B8862C), Color(0xF00A0906)],
                radius: 0.9,
              ),
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(0, -30 * rise),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * appear,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [TaqwaColors.goldLight, TaqwaColors.gold],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x88E5A93C),
                              blurRadius: 42,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 58,
                          color: Color(0xFF241A08),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'GOLD',
                        style: TextStyle(
                          color: TaqwaColors.goldLight,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '5 / 5 Gebete – Tag vollständig',
                        style: TextStyle(
                          color: TaqwaColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Möge Allah deine Gebete annehmen.',
                        style: TextStyle(
                          color: Color(0xCCF4F1E9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Tagesgenauer Countdown bis zum Beginn des Ramadan.
class RamadanCountdownCard extends StatelessWidget {
  const RamadanCountdownCard({super.key, required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.fromDate(now);
    final running = hijri.hMonth == 9;
    final start = nextRamadanStart(now);
    final today = DateTime(now.year, now.month, now.day);
    final days = start.difference(today).inDays;
    final dateLabel = formatDate(context, 'd. MMMM yyyy', start);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2110), Color(0xFF141210)],
        ),
        border: Border.all(color: const Color(0xFF4A3A1B)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1D170D),
              border: Border.all(color: TaqwaColors.gold),
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: TaqwaColors.goldLight,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(
                  running ? 'RAMADAN · TAG ${hijri.hDay}' : 'RAMADAN-COUNTDOWN',
                  color: TaqwaColors.gold,
                ),
                const SizedBox(height: 3),
                Text(
                  running
                      ? 'Ramadan läuft'
                      : days == 0
                      ? 'Ramadan beginnt heute'
                      : days == 1
                      ? 'Noch 1 Tag'
                      : 'Noch $days Tage',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TaqwaColors.goldLight,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  running
                      ? 'Möge Allah dein Fasten annehmen.'
                      : 'Beginn: $dateLabel',
                  style: const TextStyle(color: TaqwaColors.muted, fontSize: 9),
                ),
              ],
            ),
          ),
          if (!running)
            Column(
              children: [
                Text(
                  '$days',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: TaqwaColors.text,
                    height: 1,
                  ),
                ),
                const Text(
                  'TAGE',
                  style: TextStyle(
                    color: TaqwaColors.muted,
                    fontSize: 7,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onProfile,
    required this.onMotivation,
  });
  final TaqwaController controller;
  final VoidCallback onProfile;
  final VoidCallback onMotivation;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _dayTimer;
  String _day = '';

  @override
  void initState() {
    super.initState();
    _day = dayKey(widget.controller.now);
    // Nur einmal pro Minute prüfen, ob ein neuer Tag begonnen hat. Die
    // Sekundenanzeige lebt in [NextPrayerPanel] und rebuildet nicht die
    // gesamte Startseite.
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final today = dayKey(widget.controller.now);
      if (today != _day) {
        _day = today;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final settings = c.settings!;
    final date = c.now;
    final hijri = HijriCalendar.fromDate(date).toFormat('dd MMMM yyyy');
    final lv = levelForXp(settings.xp);
    final text = AppText.of(Localizations.localeOf(context).languageCode);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      children: [
        AppHeader(
          xp: settings.xp,
          initial: initials(settings.name),
          onProfile: widget.onProfile,
        ),
        const SizedBox(height: 12),
        RamadanCountdownCard(now: date),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.greeting,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Schön, dass du heute da bist.',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onProfile,
              child: CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF241B0D),
                foregroundColor: TaqwaColors.goldLight,
                child: Text(
                  initials(settings.name),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department,
                label: 'TÄGLICHER STREAK',
                value: '${settings.streak} Tage',
                detail: settings.streak == 0 ? 'Starte heute' : 'Weiter so!',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.stars_rounded,
                label: 'LEVEL & XP',
                value: 'Lvl $lv',
                detail: '${settings.xp} XP',
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        TaqwaCard(
          goldBorder: true,
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: TaqwaColors.gold,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${settings.locationName} · ${formatDate(context, 'EEE, d. MMM', date)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    hijri,
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              NextPrayerPanel(controller: c),
              const SizedBox(height: 10),
              const SectionTitle('Gebete heute'),
              Row(
                children: [
                  for (var i = 0; i < Prayer.values.length; i++) ...[
                    if (i != 0) const SizedBox(width: 5),
                    Expanded(
                      child: _PrayerTile(
                        controller: c,
                        prayer: Prayer.values[i],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${c.completedPrayers}/5 erledigt  ·  ${settings.streak} Tage Streak',
                  style: const TextStyle(color: TaqwaColors.muted, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TaqwaCard(
          padding: const EdgeInsets.all(11),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TaqwaColors.gold),
                      color: const Color(0xFF211A0D),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: TaqwaColors.goldLight,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('Dein Weg'),
                        Text(
                          'Taqwa stärken',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onMotivation,
                    child: const Text(
                      'Ansehen ›',
                      style: TextStyle(
                        color: TaqwaColors.goldLight,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        HadithOfTheDayCard(
          onOpenAll: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HadithListScreen()),
          ),
        ),
        const SizedBox(height: 10),
        TaqwaCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => QuranScreen(controller: widget.controller),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TaqwaColors.gold),
                      color: const Color(0xFF211A0D),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      color: TaqwaColors.goldLight,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('QURAN'),
                        Text(
                          '114 Suren lesen',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: TaqwaColors.goldLight,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TaqwaCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TasbihScreen(controller: c),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TaqwaColors.gold),
                      color: const Color(0xFF211A0D),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      color: TaqwaColors.goldLight,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('TASBIH'),
                        Text(
                          'Dhikr zählen · ${settings.tasbihCount}/${settings.tasbihTarget}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: TaqwaColors.goldLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nächstes Gebet mit laufendem Countdown.
///
/// Der Sekundentakt lebt bewusst nur in diesem Widget, damit beim Ticken
/// nicht die komplette Startseite (inklusive Quran-Karten und Listen) neu
/// gebaut wird.
class NextPrayerPanel extends StatefulWidget {
  const NextPrayerPanel({super.key, required this.controller});
  final TaqwaController controller;

  @override
  State<NextPrayerPanel> createState() => _NextPrayerPanelState();
}

class _NextPrayerPanelState extends State<NextPrayerPanel> {
  Timer? _timer;
  PrayerSchedule? _schedule;
  String _scheduleKey = '';

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Gebetszeiten des aktuellen Tages – nur neu berechnet, wenn sich Tag
  /// oder Standort/Methode ändern.
  PrayerSchedule _todaySchedule(TaqwaController c, DateTime now) {
    final settings = c.settings!;
    final key =
        '${dayKey(now)}|${settings.latitude}|${settings.longitude}|'
        '${settings.calculationMethod}|${settings.hanafi}';
    if (_schedule == null || key != _scheduleKey) {
      _scheduleKey = key;
      _schedule = PrayerSchedule.calculate(
        date: now,
        latitude: settings.latitude,
        longitude: settings.longitude,
        method: settings.calculationMethod,
        hanafi: settings.hanafi,
      );
    }
    return _schedule!;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final now = c.now;
    final schedule = _todaySchedule(c, now);
    final prayer = schedule.nextPrayer(now);
    final next = prayer ?? Prayer.fajr;
    final target = prayer == null
        ? schedule.times[Prayer.fajr]!.add(const Duration(days: 1))
        : schedule.times[next]!;
    final remaining = target.difference(now);
    final dayLabel = prayer == null ? 'Morgen' : 'Heute';
    return Semantics(
      label:
          'Nächstes Gebet: ${prayerNames[next]}, $dayLabel um '
          '${formatClock(target)}, noch ${_duration(remaining)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF211A10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Nächstes Gebet', color: TaqwaColors.gold),
                  const SizedBox(height: 4),
                  Text(
                    prayerNames[next]!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TaqwaColors.goldLight,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$dayLabel · ${formatClock(target)}',
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _duration(remaining),
                  style: const TextStyle(
                    color: TaqwaColors.goldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Text(
                  'verbleibend',
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _duration(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  return '${safe.inHours.toString().padLeft(2, '0')}:${(safe.inMinutes % 60).toString().padLeft(2, '0')}:${(safe.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });
  final IconData icon;
  final String label, value, detail;
  @override
  Widget build(BuildContext context) => TaqwaCard(
    goldBorder: true,
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: TaqwaColors.gold, size: 12),
            const SizedBox(width: 4),
            Expanded(child: Eyebrow(label)),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: TaqwaColors.goldLight,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          detail,
          style: const TextStyle(color: TaqwaColors.muted, fontSize: 9),
        ),
      ],
    ),
  );
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.controller, required this.prayer});
  final TaqwaController controller;
  final Prayer prayer;

  @override
  Widget build(BuildContext context) {
    final done = controller.prayers[prayer] ?? false;
    final time = controller.schedule!.times[prayer]!;
    return Semantics(
      button: true,
      label: '${prayerNames[prayer]}, ${done ? 'erledigt' : 'offen'}',
      child: InkWell(
        key: ValueKey('prayer-${prayer.name}'),
        borderRadius: BorderRadius.circular(9),
        onTap: () async {
          HapticFeedback.selectionClick();
          final award = await controller.togglePrayer(prayer);
          if (context.mounted && award.xpAdded > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('+${award.xpAdded} XP gutgeschrieben'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          decoration: BoxDecoration(
            color: done ? const Color(0xFF35260F) : const Color(0xFF111111),
            border: Border.all(
              color: done ? TaqwaColors.gold : TaqwaColors.border,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(
                prayerNames[prayer]!,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatClock(time),
                style: const TextStyle(color: TaqwaColors.muted, fontSize: 8),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? TaqwaColors.gold : Colors.transparent,
                  border: Border.all(
                    color: done ? TaqwaColors.gold : const Color(0xFF5A5A54),
                  ),
                ),
                child: done
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Color(0xFF17120A),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _habitInput = TextEditingController();
  bool _editing = false;
  @override
  void dispose() {
    _habitInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final date = c.selectedDate;
    final first = date.subtract(const Duration(days: 7));
    final days = List.generate(
      8,
      (i) => DateTime(first.year, first.month, first.day + i),
    );
    final monthLabel = formatDate(context, 'MMMM yyyy', date);
    final monthProgress = c.habits.isEmpty
        ? 0.0
        : c.completedHabits / c.habits.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      children: [
        AppHeader(
          xp: c.settings!.xp,
          initial: initials(c.settings!.name),
          onProfile: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(controller: c),
            ),
          ),
        ),
        const SizedBox(height: 13),
        TaqwaCard(
          padding: const EdgeInsets.all(11),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('Disziplin'),
                        SizedBox(height: 3),
                        Text(
                          'Habit-Tracker',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _editing = !_editing),
                    icon: Icon(
                      _editing ? Icons.done : Icons.edit,
                      color: TaqwaColors.goldLight,
                      size: 17,
                    ),
                    tooltip: 'Habits bearbeiten',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => c.changeMonth(-1),
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        monthLabel,
                        style: const TextStyle(
                          color: TaqwaColors.goldLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => c.changeMonth(1),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
              Row(
                children: [
                  const SizedBox(
                    width: 75,
                    child: Text(
                      'WOCHE',
                      style: TextStyle(
                        color: TaqwaColors.muted,
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  for (var w = 0; w < 4; w++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            minimumSize: Size.zero,
                            side: BorderSide(
                              color: w == ((date.day - 1) ~/ 7)
                                  ? TaqwaColors.gold
                                  : TaqwaColors.border,
                            ),
                          ),
                          onPressed: () => c.selectDate(
                            DateTime(date.year, date.month, w * 7 + 1),
                          ),
                          child: Text(
                            'W${w + 1}',
                            style: TextStyle(
                              fontSize: 8,
                              color: w == ((date.day - 1) ~/ 7)
                                  ? TaqwaColors.goldLight
                                  : TaqwaColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const SizedBox(width: 75),
                  for (final d in days)
                    Expanded(
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              formatDate(context, 'E', d),
                              style: const TextStyle(
                                color: TaqwaColors.muted,
                                fontSize: 8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 19,
                              height: 19,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: dayKey(d) == dayKey(DateTime.now())
                                    ? TaqwaColors.gold
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${d.day}',
                                style: TextStyle(
                                  color: dayKey(d) == dayKey(DateTime.now())
                                      ? const Color(0xFF15120B)
                                      : TaqwaColors.text,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (final habit in c.habits)
                _HabitMatrixRow(
                  habit: habit,
                  dates: days,
                  selectedDay: date,
                  statuses: c.weekHabits,
                  editing: _editing,
                  onRemove: () async => c.removeHabit(habit.id),
                  onStatus: (day, status) async {
                    HapticFeedback.selectionClick();
                    final award = await c.setHabitStatus(habit.id, status);
                    if (context.mounted && award.xpAdded > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('+5 XP · Habit erledigt'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _habitInput,
                      onSubmitted: (_) => _addHabit(),
                      decoration: const InputDecoration(
                        hintText: '+ Neue Habit hinzufügen',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  FilledButton(
                    onPressed: _addHabit,
                    style: FilledButton.styleFrom(
                      backgroundColor: TaqwaColors.gold,
                      foregroundColor: const Color(0xFF17120A),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: const Eyebrow('Vorschläge'),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 2,
                children: [
                  for (final item in [
                    'Qur’an lesen',
                    'Dhikr',
                    'Dua',
                    'Istighfar',
                    'Dankbarkeit',
                  ])
                    ActionChip(
                      label: Text(item, style: const TextStyle(fontSize: 9)),
                      backgroundColor: const Color(0xFF1B1913),
                      side: const BorderSide(color: TaqwaColors.border),
                      onPressed: () => c.addHabit(item),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TaqwaCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: monthProgress,
                      strokeWidth: 3,
                      backgroundColor: TaqwaColors.border,
                      valueColor: const AlwaysStoppedAnimation(
                        TaqwaColors.gold,
                      ),
                    ),
                    Text(
                      '${(monthProgress * 100).round()}%',
                      style: const TextStyle(
                        color: TaqwaColors.goldLight,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deine Monatsstatistik',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${c.completedHabits} von ${c.habits.length} Habits heute erledigt',
                      style: const TextStyle(
                        color: TaqwaColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${c.settings!.streak}\nTage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TaqwaColors.goldLight,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addHabit() async {
    await widget.controller.addHabit(_habitInput.text);
    _habitInput.clear();
  }
}

class _HabitMatrixRow extends StatelessWidget {
  const _HabitMatrixRow({
    required this.habit,
    required this.dates,
    required this.selectedDay,
    required this.statuses,
    required this.editing,
    required this.onRemove,
    required this.onStatus,
  });
  final Habit habit;
  final List<DateTime> dates;
  final DateTime selectedDay;
  final Map<String, Map<int, HabitStatus>> statuses;
  final bool editing;
  final VoidCallback onRemove;
  final Future<void> Function(DateTime, HabitStatus) onStatus;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF101512),
      border: Border.all(color: const Color(0xFF28453B)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 66,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: TaqwaColors.text),
                ),
              ),
              if (editing)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close,
                    color: TaqwaColors.red,
                    size: 12,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        for (final date in dates) ...[
          Expanded(
            child: Center(
              child: _StatusCell(
                key: ValueKey('habit-${habit.id}-${dayKey(date)}'),
                status: statuses[dayKey(date)]?[habit.id] ?? HabitStatus.empty,
                isToday: dayKey(date) == dayKey(DateTime.now()),
                onTap: () {
                  final old =
                      statuses[dayKey(date)]?[habit.id] ?? HabitStatus.empty;
                  final next = HabitStatus
                      .values[(old.index + 1) % HabitStatus.values.length];
                  onStatus(date, next);
                },
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    super.key,
    required this.status,
    required this.isToday,
    required this.onTap,
  });
  final HabitStatus status;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      HabitStatus.done => (TaqwaColors.green, Icons.check),
      HabitStatus.partial => (TaqwaColors.gold, Icons.check),
      HabitStatus.missed => (TaqwaColors.red, Icons.close),
      HabitStatus.empty => (const Color(0xFF171A18), null),
    };
    return Semantics(
      button: true,
      label: 'Habitstatus: ${status.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 21,
          height: 21,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isToday
                  ? TaqwaColors.goldLight
                  : (status == HabitStatus.empty
                        ? const Color(0xFF34433C)
                        : color),
            ),
            boxShadow: status == HabitStatus.empty
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: .24),
                      blurRadius: 6,
                    ),
                  ],
          ),
          child: icon == null
              ? null
              : Icon(
                  icon,
                  size: 13,
                  color: status == HabitStatus.partial
                      ? const Color(0xFF332508)
                      : Colors.white,
                ),
        ),
      ),
    );
  }
}

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      children: [
        AppHeader(
          xp: c.settings!.xp,
          initial: initials(c.settings!.name),
          onProfile: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(controller: c),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const TaqwaCard(
          goldBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('GEMEINSAM STÄRKER'),
              SizedBox(height: 3),
              Text(
                'Family',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 5),
              Text(
                'Einmal scannen – danach seht ihr eure Gebete, Standard-Habits '
                'und euren Streak gegenseitig. Ohne Konto, ohne Server.',
                style: TextStyle(
                  color: TaqwaColors.muted,
                  fontSize: 9,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PartnerSection(controller: c),
      ],
    );
  }
}

class MotivationScreen extends StatelessWidget {
  const MotivationScreen({
    super.key,
    required this.controller,
    required this.onBack,
  });
  final TaqwaController controller;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings!;
    final level = levelForXp(settings.xp);
    final lower = levelFloor(level), upper = levelCeiling(level);
    final fraction = ((settings.xp - lower) / (upper - lower)).clamp(0.0, 1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 12, 15, 90),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
            ),
            const Expanded(child: Center(child: Eyebrow('TAQWA STÄRKEN'))),
            const SizedBox(width: 42),
          ],
        ),
        const SizedBox(height: 20),
        TaqwaCard(
          goldBorder: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Eyebrow('DEINE REISE'),
              const SizedBox(height: 15),
              Container(
                width: 178,
                height: 178,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TaqwaColors.gold, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x44E5A93C), blurRadius: 24),
                  ],
                  gradient: const RadialGradient(
                    colors: [Color(0xFF3B2A10), Color(0xFF14120E)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${settings.streak}',
                      style: const TextStyle(
                        color: TaqwaColors.goldLight,
                        fontSize: 53,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'TAGE IN FOLGE',
                      style: TextStyle(
                        color: TaqwaColors.gold,
                        fontSize: 9,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Mashallah, halt durch!',
                style: TextStyle(
                  color: TaqwaColors.goldLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Jeder beständige Schritt zählt.',
                style: TextStyle(color: TaqwaColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Eyebrow('FORTSCHRITT ZUM NÄCHSTEN LEVEL'),
                  ),
                  Text(
                    'Lvl ${level + 1}',
                    style: const TextStyle(
                      color: TaqwaColors.goldLight,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: fraction,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: TaqwaColors.border,
                color: TaqwaColors.gold,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${settings.xp} XP',
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 9,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${math.max(0, upper - settings.xp)} XP bis Level ${level + 1}',
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const TaqwaCard(
          child: Text(
            '„Die besten Taten sind die, die beständig sind.“',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: TaqwaColors.text,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Profil', style: TextStyle(fontSize: 15)),
      centerTitle: true,
    ),
    body: StarField(
      child: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          TaqwaCard(
            goldBorder: true,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF251C0E),
                  foregroundColor: TaqwaColors.goldLight,
                  child: Text(
                    initials(controller.settings!.name),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.settings!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileStat(
                        'Streak',
                        '${controller.settings!.streak} Tage',
                      ),
                    ),
                    Expanded(
                      child: _ProfileStat(
                        'Level',
                        '${levelForXp(controller.settings!.xp)}',
                      ),
                    ),
                    Expanded(
                      child: _ProfileStat('XP', '${controller.settings!.xp}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle('DEIN QR-CODE', trailing: 'Family-Kopplung'),
          TaqwaCard(
            child: Column(
              children: [
                ProfileQrCard(snapshot: controller.profileSnapshot, size: 150),
                const SizedBox(height: 4),
                const Text(
                  'Zeige diesen Code deinem Familienmitglied – ein Scan '
                  'genügt, um euren Fortschritt zu teilen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TaqwaColors.muted,
                    fontSize: 9,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionTitle('MEINE DATEN'),
          _SettingsTile(
            icon: Icons.flag_outlined,
            title: 'Gebetszeiten & Standort',
            subtitle: '${controller.settings!.locationName} · lokal berechnet',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.tune,
            title: 'Einstellungen',
            subtitle: 'Sprache, OLED, Adhan, Berechnung',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_none,
            title: 'Benachrichtigungen',
            subtitle: 'Gebetserinnerungen und Adhan',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Datenschutz & Privatsphäre',
            subtitle: 'Offizielle Datenschutzerklärung',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
            subtitle: 'FAQ und Kontakt zum Entwickler',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const FaqScreen())),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Über TAQWA TRACK',
            subtitle: 'Version $appVersion · Offline-First',
            onTap: () => _message(
              context,
              'TAQWA TRACK · Version $appVersion\nOffline-Gebets-, Habit- und '
              'Familien-Tracker.\nKontakt: $supportEmail',
            ),
          ),
        ],
      ),
    ),
  );

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  Widget build(BuildContext context) {
    final settings = controller.settings!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen', style: TextStyle(fontSize: 15)),
        centerTitle: true,
      ),
      body: StarField(
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            const Eyebrow('DARSTELLUNG & SPRACHE'),
            const SizedBox(height: 8),
            TaqwaCard(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: settings.language,
                    decoration: const InputDecoration(labelText: 'Sprache'),
                    items: [
                      for (final language in appLanguages)
                        DropdownMenuItem(
                          value: language.code,
                          child: Text(
                            '${language.nativeName} · ${language.englishName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.setLanguage(value);
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.oled,
                    activeThumbColor: TaqwaColors.gold,
                    title: const Text(
                      'OLED-Schwarzmodus',
                      style: TextStyle(fontSize: 11),
                    ),
                    subtitle: const Text(
                      'Echtes Schwarz statt Dunkelgrau',
                      style: TextStyle(fontSize: 9),
                    ),
                    onChanged: controller.setOled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Eyebrow('BENACHRICHTIGUNGEN'),
            const SizedBox(height: 8),
            TaqwaCard(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.adhanEnabled,
                    activeThumbColor: TaqwaColors.gold,
                    title: const Text(
                      'Gebets-Erinnerungen',
                      style: TextStyle(fontSize: 11),
                    ),
                    subtitle: const Text(
                      'Lokale Benachrichtigung mit Signalton',
                      style: TextStyle(fontSize: 9),
                    ),
                    onChanged: (value) => controller.setAdhan(
                      enabled: value,
                      minutesBefore: settings.adhanMinutesBefore,
                    ),
                  ),
                  if (settings.adhanEnabled)
                    DropdownButtonFormField<int>(
                      initialValue: settings.adhanMinutesBefore,
                      decoration: const InputDecoration(labelText: 'Erinnern'),
                      items: const [
                        DropdownMenuItem(
                          value: 0,
                          child: Text('Zur Gebetszeit'),
                        ),
                        DropdownMenuItem(
                          value: 5,
                          child: Text('5 Minuten vorher'),
                        ),
                        DropdownMenuItem(
                          value: 10,
                          child: Text('10 Minuten vorher'),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text('15 Minuten vorher'),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text('30 Minuten vorher'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.setAdhan(
                            enabled: true,
                            minutesBefore: value,
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hinweis: Android kann Benachrichtigungen bei aktivierter '
                    'Akku-Optimierung verzögern. Erlaube Benachrichtigungen in '
                    'den Systemeinstellungen.',
                    style: TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 8,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Eyebrow('GEBETSZEITEN'),
            const SizedBox(height: 8),
            TaqwaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Standort: ${settings.locationName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${settings.latitude.toStringAsFixed(4)}, ${settings.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await controller.useDeviceLocation();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Bad state: ',
                                      '',
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.my_location, size: 14),
                        label: const Text(
                          'GPS verwenden',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _editCoordinates(context),
                        icon: const Icon(Icons.edit_location_alt, size: 14),
                        label: const Text(
                          'Koordinaten',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Eyebrow('BERECHNUNG'),
            const SizedBox(height: 8),
            TaqwaCard(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: settings.calculationMethod,
                    decoration: const InputDecoration(labelText: 'Methode'),
                    items: const [
                      DropdownMenuItem(
                        value: 'muslim_world_league',
                        child: Text('Muslim World League'),
                      ),
                      DropdownMenuItem(
                        value: 'karachi',
                        child: Text('Karachi'),
                      ),
                      DropdownMenuItem(
                        value: 'egyptian',
                        child: Text('Ägyptische Behörde'),
                      ),
                      DropdownMenuItem(
                        value: 'umm_al_qura',
                        child: Text('Umm al-Qura'),
                      ),
                      DropdownMenuItem(
                        value: 'north_america',
                        child: Text('ISNA / Nordamerika'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.updateCalculation(method: value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: settings.hanafi,
                    activeThumbColor: TaqwaColors.gold,
                    title: const Text(
                      'Hanafi (spätere Asr-Zeit)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onChanged: (value) =>
                        controller.updateCalculation(hanafi: value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            const TaqwaCard(
              child: Text(
                'Gebetszeiten werden lokal mit der Adhan-Bibliothek aus Standort, Datum, Methode und Madhab berechnet.',
                style: TextStyle(
                  color: TaqwaColors.muted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCoordinates(BuildContext context) async {
    final label = TextEditingController(
      text: controller.settings!.locationName,
    );
    final lat = TextEditingController(
      text: controller.settings!.latitude.toString(),
    );
    final lon = TextEditingController(
      text: controller.settings!.longitude.toString(),
    );
    final values = await showDialog<(String, double, double)>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Standort festlegen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Ortsname'),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: lat,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Breitengrad'),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: lon,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Längengrad'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final a = double.tryParse(lat.text.replaceAll(',', '.'));
              final o = double.tryParse(lon.text.replaceAll(',', '.'));
              if (a != null &&
                  o != null &&
                  a >= -90 &&
                  a <= 90 &&
                  o >= -180 &&
                  o <= 180) {
                Navigator.pop(context, (label.text, a, o));
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    label.dispose();
    lat.dispose();
    lon.dispose();
    if (values != null) {
      await controller.updateCoordinates(
        label: values.$1,
        latitude: values.$2,
        longitude: values.$3,
      );
    }
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: TaqwaColors.goldLight,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: const TextStyle(color: TaqwaColors.muted, fontSize: 9),
      ),
    ],
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: TaqwaCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: TaqwaColors.gold, size: 17),
        title: Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 9, color: TaqwaColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: onTap,
      ),
    ),
  );
}

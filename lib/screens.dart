import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';

import 'admin_feedback.dart';
import 'app_controller.dart';
import 'app_info.dart';
import 'app_shortcuts.dart';
import 'domain.dart';
import 'feedback_screen.dart';
import 'hadith_screen.dart';
import 'info_screens.dart';
import 'language.dart';
import 'onboarding_screen.dart';
import 'pairing_screen.dart';
import 'prayer_qibla_screens.dart';
import 'quran_screen.dart';
import 'reward.dart';
import 'tasbih_screen.dart';
import 'theme.dart';
import 'update_dialog.dart';
import 'update_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.controller, this.shortcuts});

  final TaqwaController controller;

  /// Verbindung zu den Android-Schnellstartaktionen (Quran, Gebet, Familie).
  final AppShortcutService? shortcuts;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _tab = 1;
  bool _showMotivation = false;

  /// Sanftes Einblenden beim Tabwechsel – der Zustand der Seiten bleibt
  /// dabei vollständig erhalten (IndexedStack).
  late final AnimationController _tabAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    final shortcuts = widget.shortcuts;
    if (shortcuts != null) {
      shortcuts.listen(_applyShortcut);
      shortcuts.initialShortcut().then((shortcut) {
        if (mounted && shortcut != null) _applyShortcut(shortcut);
      });
    }
  }

  @override
  void dispose() {
    _tabAnimation.dispose();
    widget.shortcuts?.dispose();
    super.dispose();
  }

  void _applyShortcut(AppShortcut shortcut) {
    if (!mounted || !widget.controller.ready) return;
    HapticFeedback.lightImpact();
    switch (shortcut) {
      case AppShortcut.quran:
        _push(QuranScreen(controller: widget.controller));
      case AppShortcut.prayer:
        _selectTab(3);
      case AppShortcut.family:
        _selectTab(2);
    }
  }

  void _selectTab(int index) {
    if (_tab == index && !_showMotivation) return;
    setState(() {
      _tab = index;
      _showMotivation = false;
    });
    _tabAnimation.forward(from: 0);
  }

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
        return Scaffold(
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
                    child: AnimatedBuilder(
                      animation: _tabAnimation,
                      builder: (context, child) {
                        final t = Curves.easeOutCubic.transform(
                          _tabAnimation.value,
                        );
                        return Opacity(
                          opacity: 0.45 + 0.55 * t,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - t)),
                            child: child,
                          ),
                        );
                      },
                      child: IndexedStack(
                        index: _showMotivation ? 1 : _tab,
                        children: pages,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _selectTab,
              backgroundColor: TaqwaColors.navBackground,
              indicatorColor: TaqwaColors.navIndicator,
              elevation: 0,
              height: 62,
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
                          gradient: LinearGradient(
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
                        child: Icon(
                          Icons.star_rounded,
                          size: 58,
                          color: TaqwaColors.onGold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'GOLD',
                        style: TextStyle(
                          color: TaqwaColors.goldLight,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '5 / 5 Gebete – Tag vollständig',
                        style: TextStyle(
                          color: TaqwaColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Möge Allah deine Gebete annehmen.',
                        style: TextStyle(
                          color: TaqwaColors.border,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TaqwaColors.goldBorder, TaqwaColors.panel],
        ),
        border: Border.all(color: TaqwaColors.goldBorder),
        boxShadow: [
          BoxShadow(
            color: TaqwaColors.shadow,
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
              color: TaqwaColors.panelDeep,
              border: Border.all(color: TaqwaColors.gold),
            ),
            child: Icon(
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
                  style: TextStyle(
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
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                ),
              ],
            ),
          ),
          if (!running)
            Column(
              children: [
                Text(
                  '$days',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: TaqwaColors.text,
                    height: 1,
                  ),
                ),
                Text(
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
                  Text(
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
                backgroundColor: TaqwaColors.chip,
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
                iconColor: _streakFlameColor(settings.streak),
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
                  Icon(
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
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              NextPrayerPanel(controller: c),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: SectionTitle('Gebete heute')),
                  if (c.completedPrayers == Prayer.values.length)
                    const RewardStar(size: 13),
                ],
              ),
              Column(
                children: [
                  for (var i = 0; i < Prayer.values.length; i++) ...[
                    if (i != 0) const SizedBox(height: 8),
                    _PrayerTile(controller: c, prayer: Prayer.values[i]),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '${c.completedPrayers}/5 erledigt  ·  ${settings.streak} Tage Streak',
                  style: TextStyle(
                    color: switch (dayTier(
                      c.completedPrayers,
                      Prayer.values.length,
                    )) {
                      DayTier.complete => rewardGold,
                      DayTier.partial => TaqwaColors.green,
                      DayTier.none => TaqwaColors.muted,
                    },
                    fontSize: 9,
                    fontWeight: c.completedPrayers == Prayer.values.length
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
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
                      color: TaqwaColors.chip,
                    ),
                    child: Icon(
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
                    child: Text(
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
                      color: TaqwaColors.chip,
                    ),
                    child: Icon(
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
                  Icon(
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
                      color: TaqwaColors.chip,
                    ),
                    child: Icon(
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
                  Icon(
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
          color: TaqwaColors.chip,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('Nächstes Gebet', color: TaqwaColors.gold),
                  const SizedBox(height: 4),
                  Text(
                    prayerNames[next]!,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TaqwaColors.goldLight,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '$dayLabel · ${formatClock(target)}',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _duration(remaining),
                  style: TextStyle(
                    color: TaqwaColors.goldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
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
    this.iconColor,
  });
  final IconData icon;
  final String label, value, detail;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => TaqwaCard(
    goldBorder: true,
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor ?? TaqwaColors.gold, size: 12),
            const SizedBox(width: 4),
            Expanded(child: Eyebrow(label)),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: TaqwaColors.goldLight,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(detail, style: TextStyle(color: TaqwaColors.muted, fontSize: 9)),
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
    final allDone = controller.completedPrayers == Prayer.values.length;
    final tier = allDone
        ? DayTier.complete
        : (done ? DayTier.partial : DayTier.none);
    final accent = tierColor(tier);
    final time = controller.schedule!.times[prayer]!;
    return Semantics(
      button: true,
      label: '${prayerNames[prayer]}, ${done ? 'erledigt' : 'offen'}',
      child: GoldFlash(
        active: allDone,
        borderRadius: 12,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('prayer-${prayer.name}'),
            borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: tierSurface(tier),
              border: Border.all(
                color: tier == DayTier.none ? TaqwaColors.border : accent,
                width: allDone ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(9),
              // Vollständig: deutliches Gold-Leuchten. Teilweise: sanftes
              // grünes Signal, dass heute schon etwas geschafft ist.
              boxShadow: [
                 BoxShadow(
                   color: TaqwaColors.shadow,
                   blurRadius: 10,
                   offset: const Offset(0, 4),
                 ),
                 if (allDone)
                   BoxShadow(
                     color: rewardGold.withValues(alpha: 0.40),
                     blurRadius: 14,
                     spreadRadius: 1,
                   )
                 else if (tier == DayTier.partial)
                   BoxShadow(
                     color: TaqwaColors.green.withValues(alpha: 0.22),
                     blurRadius: 6,
                   ),
               ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    prayerNames[prayer]!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  formatClock(time),
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 11),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? accent : Colors.transparent,
                    border: Border.all(
                      color: done ? accent : TaqwaColors.mutedStrong,
                    ),
                    boxShadow: done
                        ? [
                            BoxShadow(
                              color: accent.withValues(
                                alpha: allDone ? 0.70 : 0.30,
                              ),
                              blurRadius: allDone ? 10 : 5,
                              spreadRadius: allDone ? 1 : 0,
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedScale(
                    scale: done ? 1 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: allDone ? TaqwaColors.onGold : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                        style: TextStyle(
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
                  SizedBox(
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
                              style: TextStyle(
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
                                      ? TaqwaColors.panelDeep
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
                      foregroundColor: TaqwaColors.onGold,
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
                      backgroundColor: TaqwaColors.panel,
                      side: BorderSide(color: TaqwaColors.border),
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
                      valueColor: AlwaysStoppedAnimation(TaqwaColors.gold),
                    ),
                    Text(
                      '${(monthProgress * 100).round()}%',
                      style: TextStyle(
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
                      style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Text(
                '${c.settings!.streak}\nTage',
                textAlign: TextAlign.center,
                style: TextStyle(
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
      color: TaqwaColors.greenSurface,
      border: Border.all(color: TaqwaColors.greenSurface),
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
                  style: TextStyle(fontSize: 9, color: TaqwaColors.text),
                ),
              ),
              if (editing)
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(Icons.close, color: TaqwaColors.red, size: 12),
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
      HabitStatus.empty => (TaqwaColors.panel, null),
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
                        ? TaqwaColors.greenSurface
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
                      ? TaqwaColors.onGold
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
        TaqwaCard(
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
                'Einmal scannen - danach seht ihr eure Gebete, Standard-Habits '
                'und euren Streak gegenseitig. Der Austausch läuft über einen '
                'kostenlosen Cloud-Kanal: WLAN, mobile Daten oder Ausland - '
                'ohne Konto und ohne Serverkosten.',
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
                  gradient: RadialGradient(
                    colors: [TaqwaColors.goldBorder, TaqwaColors.panel],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${settings.streak}',
                      style: TextStyle(
                        color: TaqwaColors.goldLight,
                        fontSize: 53,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
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
              Text(
                'Mashallah, halt durch!',
                style: TextStyle(
                  color: TaqwaColors.goldLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Text(
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
                    style: TextStyle(
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
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                  ),
                  const Spacer(),
                  Text(
                    '${math.max(0, upper - settings.xp)} XP bis Level ${level + 1}',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TaqwaCard(
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
                  backgroundColor: TaqwaColors.chip,
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
                Text(
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
            icon: Icons.rate_review_outlined,
            title: 'Feedback & Bewertung',
            subtitle: 'Sterne geben und direkt an den Entwickler schreiben',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    FeedbackScreen(initialName: controller.settings!.name),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.admin_panel_settings,
            title: 'Admin-Bereich',
            subtitle: 'Geschützter Bereich für Administratoren',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminFeedbackScreen(),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.system_update_outlined,
            title: 'Nach Updates suchen',
            subtitle: 'Version $appVersion · GitHub-Release',
            onTap: () => _checkForUpdates(context),
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

  /// Manueller Update-Check aus den Einstellungen.
  Future<void> _checkForUpdates(BuildContext context) async {
    final service = UpdateService();
    final release = await service.check();
    if (!context.mounted) return;
    if (release == null) {
      _message(context, 'Du bist auf dem neuesten Stand (v$appVersion).');
      return;
    }
    await showUpdateDialog(
      context,
      release: release,
      currentVersion: service.currentVersion,
    );
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Erscheinungsbild',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Automatisch nach System oder fest hell bzw. dunkel.',
                      style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                    ),
                    const SizedBox(height: 10),
                    _ThemeModeSelector(
                      value: settings.themeMode,
                      onChanged: controller.setThemeMode,
                    ),
                    const SizedBox(height: 10),
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
                    if (settings.themeMode != 'light')
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
                        decoration: const InputDecoration(
                          labelText: 'Erinnern',
                        ),
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
                    const SizedBox(height: 8),
                    Divider(height: 1, color: TaqwaColors.border),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: settings.familyAlerts,
                      activeThumbColor: TaqwaColors.gold,
                      title: const Text(
                        'Familien-Nachrichten',
                        style: TextStyle(fontSize: 11),
                      ),
                      subtitle: const Text(
                        'Nudges und Nachrichten aus dem Family-Tab',
                        style: TextStyle(fontSize: 9),
                      ),
                      onChanged: controller.setFamilyAlerts,
                    ),
                    const SizedBox(height: 4),
                    Divider(height: 1, color: TaqwaColors.border),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      key: const ValueKey('settings-cloud-sync'),
                      contentPadding: EdgeInsets.zero,
                      value: settings.cloudEnabled,
                      activeThumbColor: TaqwaColors.gold,
                      title: const Text(
                        'Cloud-Synchronisation',
                        style: TextStyle(fontSize: 11),
                      ),
                      subtitle: const Text(
                        'Nudges und Nachrichten von überall – kostenlos, '
                        'auch über mobile Daten',
                        style: TextStyle(fontSize: 9),
                      ),
                      onChanged: controller.setCloudEnabled,
                    ),
                    const SizedBox(height: 4),
                    Text(
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
                      style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
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
              TaqwaCard(
                child: Text(
                  'Gebetszeiten werden lokal mit der Adhan-Bibliothek aus Standort, Datum, Methode und Madhab berechnet.',
                  style: TextStyle(
                    color: TaqwaColors.muted,
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _DeveloperFooter(),
            ],
          ),
        ),
      );
    },
  );

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
        style: TextStyle(
          color: TaqwaColors.goldLight,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: TaqwaColors.muted, fontSize: 9)),
    ],
  );
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('system', 'System', Icons.brightness_auto_outlined),
    ('light', 'Hell', Icons.light_mode_outlined),
    ('dark', 'Dunkel', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (id, label, icon) in _options) ...[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              key: ValueKey('theme-mode-$id'),
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: value == id ? TaqwaColors.chip : TaqwaColors.panel,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: value == id ? TaqwaColors.gold : TaqwaColors.border,
                    width: value == id ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: value == id
                          ? TaqwaColors.goldLight
                          : TaqwaColors.muted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: value == id
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: value == id
                            ? TaqwaColors.goldLight
                            : TaqwaColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _DeveloperFooter extends StatelessWidget {
  const _DeveloperFooter();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TaqwaColors.goldBorder),
          color: TaqwaColors.chip,
          boxShadow: [
            BoxShadow(
              color: TaqwaColors.shadow,
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/branding/logo.png',
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => Icon(
              Icons.nightlight_round,
              color: TaqwaColors.goldLight,
              size: 24,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'TAQWA TRACK',
        style: TextStyle(
          color: TaqwaColors.goldLight,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.4,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Entwickelt von Alsafdi Baschar',
        key: const ValueKey('developer-credit'),
        style: TextStyle(
          color: TaqwaColors.text.withValues(alpha: 0.85),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      const SizedBox(height: 3),
      GestureDetector(
        onLongPress: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AdminFeedbackScreen(),
          ),
        ),
        child: Text(
          'Version $appVersion · Build $appBuild',
          style: TextStyle(color: TaqwaColors.muted, fontSize: 8.5),
        ),
      ),
      const SizedBox(height: 10),
      Container(width: 44, height: 1, color: TaqwaColors.border),
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
          style: TextStyle(fontSize: 9, color: TaqwaColors.muted),
        ),
        trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: onTap,
      ),
    ),
  );
}

Color _streakFlameColor(int streak) {
  if (streak <= 0) return TaqwaColors.muted;
  if (streak < 3) return Colors.orange.shade300;
  if (streak < 7) return Colors.orange;
  if (streak < 14) return TaqwaColors.gold;
  if (streak < 30) return Colors.deepOrange;
  return Colors.redAccent;
}


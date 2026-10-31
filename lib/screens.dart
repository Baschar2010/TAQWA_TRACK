import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import 'app_controller.dart';
import 'data/taqwa_repository.dart';
import 'domain.dart';
import 'hadith_screen.dart';
import 'onboarding_screen.dart';
import 'prayer_qibla_screens.dart';
import 'quran_screen.dart';
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
      return Scaffold(
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Kalender',
            ),
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.family_restroom_outlined),
              selectedIcon: Icon(Icons.family_restroom),
              label: 'Family',
            ),
            NavigationDestination(
              icon: Icon(Icons.mosque_outlined),
              selectedIcon: Icon(Icons.mosque),
              label: 'Gebete',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Qibla',
            ),
          ],
        ),
      );
    },
  );

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
  Timer? _timer;
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

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final settings = c.settings!;
    final date = c.now;
    final hijri = HijriCalendar.now().toFormat('dd MMMM yyyy');
    final prayer = c.nextPrayer;
    final upcomingTomorrow = prayer == null
        ? PrayerSchedule.calculate(
            date: date.add(const Duration(days: 1)),
            latitude: settings.latitude,
            longitude: settings.longitude,
            method: settings.calculationMethod,
            hanafi: settings.hanafi,
          )
        : null;
    final next = prayer ?? Prayer.fajr;
    final target = prayer == null
        ? upcomingTomorrow!.times[Prayer.fajr]!
        : c.schedule!.times[next]!;
    final remaining = target.difference(date);
    final lv = levelForXp(settings.xp);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      children: [
        AppHeader(
          xp: settings.xp,
          initial: initials(settings.name),
          onProfile: widget.onProfile,
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'As-salāmu ʿalaykum, ${settings.name}',
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
                      '${settings.locationName} · ${DateFormat('EEE, d. MMM', 'de_DE').format(date)}',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
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
                          const Eyebrow(
                            'Nächstes Gebet',
                            color: TaqwaColors.gold,
                          ),
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
                            'Heute · ${formatClock(target)}',
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
                          ),
                        ),
                        const Text(
                          'verbleibend',
                          style: TextStyle(
                            color: TaqwaColors.muted,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
              MaterialPageRoute<void>(builder: (_) => const QuranScreen()),
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
      ],
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
    final monthLabel = DateFormat('MMMM yyyy', 'de_DE').format(date);
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
                              DateFormat.E('de_DE').format(d),
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
    final combined = c.family.fold<int>(
      0,
      (sum, member) =>
          sum +
          (c.familyPrayers[member.id]?.values.where((v) => v).length ?? 0),
    );
    final max = c.family.length * Prayer.values.length;
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
              const Eyebrow('GEMEINSAM STÄRKER'),
              const SizedBox(height: 3),
              const Text(
                'Family',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1912),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TaqwaColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home, color: TaqwaColors.gold, size: 17),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Familie Hassini',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Deine Familie auf diesem Gerät',
                            style: TextStyle(
                              color: TaqwaColors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${c.family.length} Mitglieder',
                      style: const TextStyle(
                        color: TaqwaColors.goldLight,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  const Expanded(child: Eyebrow('HEUTE ZUSAMMEN')),
                  Text(
                    '$combined / $max Gebete',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              LinearProgressIndicator(
                value: max == 0 ? 0 : combined / max,
                minHeight: 5,
                borderRadius: BorderRadius.circular(6),
                backgroundColor: TaqwaColors.border,
                color: TaqwaColors.gold,
              ),
              const SizedBox(height: 6),
              Text(
                c.family.isEmpty
                    ? 'Füge Familienmitglieder hinzu, um euren gemeinsamen Fortschritt hier zu sehen.'
                    : 'Alle Einträge bleiben lokal auf diesem Gerät.',
                style: const TextStyle(color: TaqwaColors.muted, fontSize: 9),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionTitle('Wer hat heute gebetet?', trailing: 'F  D  A  M  I'),
        if (c.family.isEmpty)
          TaqwaCard(
            child: Column(
              children: [
                const Icon(
                  Icons.group_add_outlined,
                  color: TaqwaColors.gold,
                  size: 28,
                ),
                const SizedBox(height: 7),
                const Text(
                  'Noch keine Mitglieder',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Lege lokale Profile für deine Familie an.',
                  style: TextStyle(fontSize: 9, color: TaqwaColors.muted),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Mitglied hinzufügen'),
                  style: FilledButton.styleFrom(
                    backgroundColor: TaqwaColors.gold,
                    foregroundColor: const Color(0xFF17120A),
                  ),
                ),
              ],
            ),
          )
        else ...[
          for (final member in c.family)
            _FamilyRow(controller: c, member: member),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addMember,
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: const Text('Mitglied hinzufügen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TaqwaColors.goldLight,
              side: const BorderSide(color: TaqwaColors.border),
            ),
          ),
        ],
        const SizedBox(height: 12),
        PartnerSection(controller: c),
        const SizedBox(height: 12),
        const TaqwaCard(
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: TaqwaColors.muted, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Family-Fortschritt wird nur auf diesem Gerät gespeichert. Es gibt keine Cloud-Synchronisierung.',
                  style: TextStyle(fontSize: 9, color: TaqwaColors.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addMember() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Familienmitglied hinzufügen'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    input.dispose();
    if (name != null) await widget.controller.addFamilyMember(name);
  }
}

class _FamilyRow extends StatelessWidget {
  const _FamilyRow({required this.controller, required this.member});
  final TaqwaController controller;
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    final statuses =
        controller.familyPrayers[member.id] ?? const <String, bool>{};
    final done = statuses.values.where((v) => v).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: TaqwaCard(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: const Color(0xFF251C0E),
              foregroundColor: TaqwaColors.goldLight,
              child: Text(
                initials(member.name),
                style: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 50,
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final prayer in Prayer.values)
                    InkWell(
                      onTap: () => controller.toggleFamilyPrayer(
                        member.id,
                        prayer,
                        !(statuses[prayer.name] ?? false),
                      ),
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          color: statuses[prayer.name] == true
                              ? TaqwaColors.green
                              : const Color(0xFF242622),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: statuses[prayer.name] == true
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$done/5',
              style: const TextStyle(fontSize: 8, color: TaqwaColors.muted),
            ),
            IconButton(
              tooltip: 'Mitglied löschen',
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, size: 15),
              color: TaqwaColors.muted,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Mitglied löschen?', style: TextStyle(fontSize: 15)),
        content: Text(
          '${member.name} und alle gespeicherten Gebete dieses Profils werden entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.removeFamilyMember(member.id);
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
          const SectionTitle('MEINE DATEN'),
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Persönliche Daten',
            subtitle: 'Name und Profil bearbeiten',
            onTap: () => _editName(context),
          ),
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
            subtitle: 'Berechnungsmethode und Madhab',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_none,
            title: 'Benachrichtigungen',
            subtitle: 'Gebetserinnerungen',
            onTap: () => _message(
              context,
              'Benachrichtigungen lassen sich in den Geräteeinstellungen verwalten.',
            ),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Daten & Privatsphäre',
            subtitle: 'Alle Daten bleiben auf diesem Gerät',
            onTap: () => _message(
              context,
              'TAQWA TRACK verwendet keine Cloud und sendet keine persönlichen Daten.',
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
            subtitle: 'Informationen zur App',
            onTap: () => _message(
              context,
              'TAQWA TRACK · Offline-Gebets- und Habit-Tracker',
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editName(BuildContext context) async {
    final field = TextEditingController(text: controller.settings!.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TaqwaColors.card,
        title: const Text('Name bearbeiten'),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Dein Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    field.dispose();
    if (name != null) await controller.updateName(name);
  }

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

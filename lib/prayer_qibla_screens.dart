import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart' show HijriCalendar;

import 'app_controller.dart';
import 'widgets/compass_widget.dart';
import 'domain.dart';
import 'hadith_screen.dart';
import 'language.dart';
import 'reward.dart';
import 'screens.dart';
import 'theme.dart';

// ---------------------------------------------------------------------------
// Gebetszeiten – alle Zeiten des Tages auf einen Blick
// ---------------------------------------------------------------------------

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Timer? _timer;
  PrayerSchedule? _schedule;
  String _scheduleKey = '';

  @override
  void initState() {
    super.initState();
    // Einmal pro Minute reicht: Nächstes Gebet, Datum und Hervorhebung
    // wechseln nicht im Sekundentakt. Der sichtbare Countdown tickt in
    // [_NextPrayerBar] und rebuildet nicht die ganze Seite.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Gebetszeiten des Tages – nur neu berechnet, wenn Tag, Standort oder
  /// Berechnungsmethode sich ändern.
  PrayerSchedule _scheduleFor(AppSettings settings, DateTime day) {
    final key =
        '${dayKey(day)}|${settings.latitude}|${settings.longitude}|'
        '${settings.calculationMethod}|${settings.hanafi}';
    if (_schedule == null || key != _scheduleKey) {
      _scheduleKey = key;
      _schedule = PrayerSchedule.calculate(
        date: day,
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
    final settings = c.settings!;
    final now = c.now;
    final schedule = _scheduleFor(settings, now);
    final next = schedule.nextPrayer(now);

    final entries = <_TimeEntry>[
      _TimeEntry(
        label: 'Imsak',
        time: schedule.imsak,
        icon: Icons.bedtime_outlined,
        hint: '10 Min. vor Fajr',
      ),
      _TimeEntry(
        label: 'Fajr',
        time: schedule.times[Prayer.fajr]!,
        icon: Icons.nightlight_outlined,
        prayer: Prayer.fajr,
      ),
      _TimeEntry(
        label: 'Sunrise',
        time: schedule.sunrise,
        icon: Icons.wb_twilight,
        hint: 'Sonnenaufgang',
      ),
      _TimeEntry(
        label: 'Dhuhr',
        time: schedule.times[Prayer.dhuhr]!,
        icon: Icons.wb_sunny_outlined,
        prayer: Prayer.dhuhr,
      ),
      _TimeEntry(
        label: 'Asr',
        time: schedule.times[Prayer.asr]!,
        icon: Icons.sunny_snowing,
        prayer: Prayer.asr,
      ),
      _TimeEntry(
        label: 'Maghrib',
        time: schedule.times[Prayer.maghrib]!,
        icon: Icons.nights_stay_outlined,
        prayer: Prayer.maghrib,
      ),
      _TimeEntry(
        label: 'Isha',
        time: schedule.times[Prayer.isha]!,
        icon: Icons.dark_mode_outlined,
        prayer: Prayer.isha,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      children: [
        AppHeader(
          xp: settings.xp,
          initial: initials(settings.name),
          onProfile: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(controller: c),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const PrayerHadithCard(),
        const SizedBox(height: 10),
        TaqwaCard(
          goldBorder: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('ALLE GEBETE HEUTE', color: TaqwaColors.gold),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Text(
                      'Gebetszeiten',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    formatClock(now),
                    style: TextStyle(
                      color: TaqwaColors.goldLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: TaqwaColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${settings.locationName} · '
                      '${formatDate(context, 'EEE, d. MMM yyyy', now)}',
                      style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                    ),
                  ),
                  Text(
                    HijriCalendar.fromDate(now).toFormat('dd MMMM yyyy'),
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _NextPrayerBar(schedule: schedule, clock: () => c.now),
            ],
          ),
        ),
        const SizedBox(height: 11),
        _DailyHabitCard(controller: c, schedule: schedule),
        const SizedBox(height: 11),
        const SectionTitle('Tagesübersicht', trailing: 'alle Zeiten'),
        TaqwaCard(
          padding: const EdgeInsets.all(9),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                _PrayerTimeRow(
                  entry: entries[i],
                  highlighted: entries[i].prayer == next,
                  isNext:
                      entries[i].prayer != null && entries[i].prayer == next,
                  done: entries[i].prayer == null
                      ? null
                      : (c.todayPrayers[entries[i].prayer!] ?? false),
                ),
                if (i != entries.length - 1)
                  Divider(height: 1, thickness: 0.5, color: TaqwaColors.border),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9),
        Center(
          child: Text(
            'Offline berechnet nach deiner eingestellten Methode.',
            style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
          ),
        ),
      ],
    );
  }
}

class _DailyHabitCard extends StatelessWidget {
  const _DailyHabitCard({required this.controller, required this.schedule});
  final TaqwaController controller;
  final PrayerSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final done = controller.completedPrayersToday;
    final total = Prayer.values.length;
    final tier = dayTier(done, total);
    final allDone = tier == DayTier.complete;
    // Grün ab dem ersten erledigten Gebet, Gold erst bei 5/5.
    final accent = tierColor(tier);
    final today = controller.today;
    final weekday = formatDate(context, 'EEEE', today);
    final dateLabel = formatDate(context, 'd. MMMM', today);

    return GoldFlash(
      active: allDone,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TaqwaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: switch (tier) {
              DayTier.complete => rewardGold,
              DayTier.partial => TaqwaColors.green.withValues(alpha: 0.65),
              DayTier.none => TaqwaColors.border,
            },
            width: allDone ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: TaqwaColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
            if (allDone)
              BoxShadow(
                color: rewardGold.withValues(alpha: 0.35),
                blurRadius: 22,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    'HEUTE · $weekday'.toUpperCase(),
                    color: accent,
                  ),
                ),
                if (allDone) ...[
                  const RewardStar(size: 15),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent),
                  ),
                  child: Text(
                    '$done/$total',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'Tages-Habits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: allDone ? rewardGold : TaqwaColors.text,
                    ),
                  ),
                ),
                Text(
                  dateLabel,
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: done / total),
                duration: const Duration(milliseconds: 400),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 7,
                  backgroundColor: TaqwaColors.goldBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final prayer in Prayer.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _HabitPrayerRow(
                  prayer: prayer,
                  time: schedule.times[prayer]!,
                  done: controller.todayPrayers[prayer] ?? false,
                  accent: accent,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    final award = await controller.togglePrayerToday(prayer);
                    if (context.mounted && award.xpAdded > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('+${award.xpAdded} XP gutgeschrieben'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  allDone ? Icons.emoji_events : Icons.flag_outlined,
                  size: 13,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    allDone
                        ? 'Alle 5 Gebete erledigt – MashaAllah!'
                        : 'Noch ${total - done} ${total - done == 1 ? 'Gebet' : 'Gebete'} bis zum Tagesziel',
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: allDone ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitPrayerRow extends StatelessWidget {
  const _HabitPrayerRow({
    required this.prayer,
    required this.time,
    required this.done,
    required this.accent,
    required this.onTap,
  });
  final Prayer prayer;
  final DateTime time;
  final bool done;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    checked: done,
    label: '${prayerNames[prayer]}, ${done ? 'erledigt' : 'offen'}',
    child: InkWell(
      key: ValueKey('habit-${prayer.name}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: done ? accent.withValues(alpha: 0.14) : TaqwaColors.panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: done ? accent : TaqwaColors.border,
            width: accent == rewardGold ? 1.4 : 1,
          ),
          boxShadow: done
              ? [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: accent == rewardGold ? 0.38 : 0.20,
                    ),
                    blurRadius: accent == rewardGold ? 12 : 6,
                    spreadRadius: accent == rewardGold ? 1 : 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? accent : Colors.transparent,
                border: Border.all(
                  color: done ? accent : TaqwaColors.mutedStrong,
                  width: 1.4,
                ),
                boxShadow: done
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: done
                  ? Icon(
                      Icons.check,
                      size: 15,
                      color: accent == rewardGold
                          ? TaqwaColors.onGold
                          : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayerNames[prayer]!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                      color: done ? accent : TaqwaColors.text,
                    ),
                  ),
                  Text(
                    done ? 'Erledigt' : 'Antippen zum Abhaken',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            Text(
              formatClock(time),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: done ? accent : TaqwaColors.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimeEntry {
  _TimeEntry({
    required this.label,
    required this.time,
    required this.icon,
    this.prayer,
    this.hint,
  });
  final String label;
  final DateTime time;
  final IconData icon;
  final Prayer? prayer;
  final String? hint;
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.entry,
    required this.highlighted,
    required this.isNext,
    required this.done,
  });
  final _TimeEntry entry;
  final bool highlighted, isNext;
  final bool? done;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
    decoration: BoxDecoration(
      color: highlighted ? TaqwaColors.goldBorder : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: highlighted ? TaqwaColors.gold : Colors.transparent,
      ),
    ),
    child: Row(
      children: [
        Icon(
          entry.icon,
          size: 16,
          color: highlighted ? TaqwaColors.goldLight : TaqwaColors.gold,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                  color: highlighted ? TaqwaColors.goldLight : TaqwaColors.text,
                ),
              ),
              if (entry.hint != null)
                Text(
                  entry.hint!,
                  style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                ),
            ],
          ),
        ),
        if (isNext)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: TaqwaColors.goldBorder,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TaqwaColors.gold),
            ),
            child: Text(
              'als Nächstes',
              style: TextStyle(
                color: TaqwaColors.goldLight,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (done == true)
          Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.check_circle, size: 14, color: TaqwaColors.green),
          ),
        const SizedBox(width: 10),
        Text(
          formatClock(entry.time),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: highlighted ? TaqwaColors.goldLight : TaqwaColors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// Countdown bis zum nächsten Gebet – tickt sekündlich, aber nur innerhalb
/// dieser Leiste. Die übrige Seite wird dadurch nicht neu gebaut.
class _NextPrayerBar extends StatefulWidget {
  const _NextPrayerBar({required this.schedule, required this.clock});
  final PrayerSchedule schedule;
  final DateTime Function() clock;

  @override
  State<_NextPrayerBar> createState() => _NextPrayerBarState();
}

class _NextPrayerBarState extends State<_NextPrayerBar> {
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
    final now = widget.clock();
    final next = widget.schedule.nextPrayer(now);
    final target = next == null
        ? widget.schedule.times[Prayer.fajr]!.add(const Duration(days: 1))
        : widget.schedule.times[next]!;
    final remaining = target.difference(now);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: TaqwaColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: TaqwaColors.gold, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              next == null
                  ? 'Alle Gebete von heute sind vorbei'
                  : 'Nächstes Gebet: ${prayerNames[next]!}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          Text(
            _countdown(remaining),
            style: TextStyle(
              color: TaqwaColors.goldLight,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

String _countdown(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  return '${safe.inHours.toString().padLeft(2, '0')}:'
      '${(safe.inMinutes % 60).toString().padLeft(2, '0')}:'
      '${(safe.inSeconds % 60).toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Qibla – Kompass zur Kaaba
// ---------------------------------------------------------------------------

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, required this.controller});
  final TaqwaController controller;
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final settings = c.settings!;
    final qibla = qiblaBearing(settings.latitude, settings.longitude);
    final distance = distanceToKaaba(settings.latitude, settings.longitude);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 92),
      children: [
        AppHeader(
          xp: settings.xp,
          initial: initials(settings.name),
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
              Eyebrow('QIBLA-KOMPASS', color: TaqwaColors.gold),
              const SizedBox(height: 3),
              const Text(
                'Qibla',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${settings.locationName} · '
                '${settings.latitude.toStringAsFixed(3)}, '
                '${settings.longitude.toStringAsFixed(3)}',
                style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
              ),
              const SizedBox(height: 12),
              CompassWidget(
                latitude: settings.latitude,
                longitude: settings.longitude,
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _QiblaStat(
                icon: Icons.explore,
                label: 'QIBLA-WINKEL',
                value: '${qibla.round()}°',
                detail: 'von Norden',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QiblaStat(
                icon: Icons.straighten,
                label: 'ENTFERNUNG',
                value: '${distance.round()} km',
                detail: 'zur Kaaba',
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        TaqwaCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('So findest du die Qibla'),
              for (final line in const [
                'Halte das Handy flach und waagerecht.',
                'Bewege es einmal in einer 8, um den Kompass zu kalibrieren.',
                'Drehe dich, bis der goldene Pfeil nach oben zeigt.',
                'Metall und Magnete in der Nähe stören den Sensor.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 4, color: TaqwaColors.gold),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          line,
                          style: TextStyle(
                            color: TaqwaColors.muted,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Center(
          child: Text(
            'Ohne Sensor zeigt der Ring Norden, der Pfeil die Qibla.',
            textAlign: TextAlign.center,
            style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
          ),
        ),
      ],
    );
  }
}

/// Kompassnadel samt Sensor-Abo. Der Sensor feuert bis zu 50-mal pro Sekunde;
/// deshalb lebt er in einem eigenen Widget und rebuildet nicht die ganze
/// Qibla-Seite. Ein Tiefpass glättet das typische Sensorrauschen.
class _QiblaCompass extends StatefulWidget {
  const _QiblaCompass({required this.qibla});
  final double qibla;

  @override
  State<_QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<_QiblaCompass> {
  static const _channel = EventChannel('taqwa_track/compass');

  StreamSubscription<dynamic>? _subscription;
  Timer? _sensorTimeout;
  double? _heading;
  bool _sensorMissing = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _sensorTimeout = Timer(const Duration(seconds: 3), () {
      if (mounted && _heading == null) {
        setState(() => _sensorMissing = true);
      }
    });
    try {
      _subscription = _channel.receiveBroadcastStream().listen(
        (event) {
          if (!mounted) return;
          final raw = (event as num).toDouble();
          _sensorTimeout?.cancel();
          setState(() {
            _heading = _smooth(raw);
            _sensorMissing = false;
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _sensorMissing = true);
        },
        cancelOnError: false,
      );
    } on Object {
      _sensorMissing = true;
    }
  }

  /// Exponentielle Glättung über den kürzesten Weg um den Kreis.
  double _smooth(double value) {
    final previous = _heading;
    if (previous == null) return value;
    final delta = _angleDelta(value, previous);
    return (previous + delta * 0.28 + 360) % 360;
  }

  @override
  void dispose() {
    _sensorTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final aligned =
        heading != null && _angleDelta(widget.qibla, heading).abs() <= 5;
    return Column(
      children: [
        Semantics(
          label: heading == null
              ? 'Qibla-Kompass, Sensor wird gesucht'
              : 'Qibla-Kompass, Kaaba bei ${widget.qibla.round()} Grad, '
                    'Gerät bei ${heading.round()} Grad',
          child: SizedBox(
            width: 244,
            height: 244,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -((heading ?? 0) * math.pi / 180),
                  child: CustomPaint(
                    size: const Size.square(244),
                    painter: _CompassDialPainter(aligned: aligned),
                  ),
                ),
                Transform.rotate(
                  angle: (widget.qibla - (heading ?? 0)) * math.pi / 180,
                  child: CustomPaint(
                    size: const Size.square(244),
                    painter: _QiblaNeedlePainter(aligned: aligned),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TaqwaColors.panel,
                    border: Border.all(
                      color: aligned ? TaqwaColors.green : TaqwaColors.gold,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.qibla.round()}°',
                      style: TextStyle(
                        color: TaqwaColors.goldLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            heading == null
                ? 'Kompass wird gesucht …'
                : aligned
                ? 'Ausgerichtet – du blickst zur Kaaba'
                : 'Handy flach halten, bis der Pfeil nach oben zeigt',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: aligned ? FontWeight.w700 : FontWeight.w500,
              color: aligned ? TaqwaColors.green : TaqwaColors.goldLight,
            ),
          ),
        ),
        if (heading == null && _sensorMissing)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Center(
              child: Text(
                'Kein Kompass-Sensor gefunden – die Richtung oben gilt trotzdem.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
              ),
            ),
          ),
      ],
    );
  }
}

class _QiblaStat extends StatelessWidget {
  const _QiblaStat({
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
            Icon(icon, size: 13, color: TaqwaColors.gold),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 7,
                  color: TaqwaColors.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: TaqwaColors.goldLight,
          ),
        ),
        Text(detail, style: TextStyle(fontSize: 8, color: TaqwaColors.muted)),
      ],
    ),
  );
}

double _angleDelta(double a, double b) {
  final diff = (a - b) % 360;
  return diff > 180 ? diff - 360 : diff;
}

class _CompassDialPainter extends CustomPainter {
  _CompassDialPainter({required this.aligned});
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius - 1, Paint()..color = TaqwaColors.card);
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = aligned ? TaqwaColors.green : TaqwaColors.border,
    );
    canvas.drawCircle(
      center,
      radius - 26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = TaqwaColors.border,
    );
    final tick = Paint()
      ..strokeWidth = 1
      ..color = TaqwaColors.mutedStrong;
    final strong = Paint()
      ..strokeWidth = 1.8
      ..color = TaqwaColors.gold;
    for (var degrees = 0; degrees < 360; degrees += 15) {
      final rad = (degrees - 90) * math.pi / 180;
      final major = degrees % 90 == 0;
      final length = major ? 12.0 : 6.0;
      final outer = Offset(
        center.dx + math.cos(rad) * (radius - 8),
        center.dy + math.sin(rad) * (radius - 8),
      );
      final inner = Offset(
        center.dx + math.cos(rad) * (radius - 8 - length),
        center.dy + math.sin(rad) * (radius - 8 - length),
      );
      canvas.drawLine(outer, inner, major ? strong : tick);
    }
    const labels = {0: 'N', 90: 'O', 180: 'S', 270: 'W'};
    labels.forEach((degrees, label) {
      final rad = (degrees - 90) * math.pi / 180;
      final position = Offset(
        center.dx + math.cos(rad) * (radius - 42),
        center.dy + math.sin(rad) * (radius - 42),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: degrees == 0 ? TaqwaColors.gold : TaqwaColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.aligned != aligned;
}

class _QiblaNeedlePainter extends CustomPainter {
  _QiblaNeedlePainter({required this.aligned});
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final color = aligned ? TaqwaColors.green : TaqwaColors.gold;
    final tip = center - Offset(0, radius - 28);
    final left = center + Offset(-10, -radius + 78);
    final right = center + Offset(10, -radius + 78);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TaqwaColors.chip,
    );
  }

  @override
  bool shouldRepaint(covariant _QiblaNeedlePainter oldDelegate) =>
      oldDelegate.aligned != aligned;
}

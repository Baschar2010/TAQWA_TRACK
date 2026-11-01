import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'theme.dart';

/// Digitaler Dhikr-Zähler mit Vibrations-Feedback.
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key, required this.controller});
  final TaqwaController controller;

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  static const _phrases = [
    'Subhanallah',
    'Alhamdulillah',
    'Allahu akbar',
    'La ilaha illallah',
  ];

  int _phrase = 0;

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.settings!;
    final count = settings.tasbihCount;
    final target = settings.tasbihTarget;
    final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasbih', style: TextStyle(fontSize: 15)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Zurücksetzen',
            onPressed: () => widget.controller.resetTasbih(),
            icon: const Icon(Icons.restart_alt, size: 20),
          ),
        ],
      ),
      body: StarField(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            children: [
              const Eyebrow('DHIKR-ZÄHLER', color: TaqwaColors.gold),
              const SizedBox(height: 4),
              const Text(
                'Tasbih',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Zähle deine Dhikr mit Vibration – ohne Bildschirm anschauen zu müssen.',
                style: TextStyle(
                  color: TaqwaColors.muted,
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _phrases.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _phrase = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _phrase == i
                              ? const Color(0xFF33250F)
                              : const Color(0xFF171614),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _phrase == i
                                ? TaqwaColors.gold
                                : TaqwaColors.border,
                          ),
                        ),
                        child: Text(
                          _phrases[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: _phrase == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _phrase == i
                                ? TaqwaColors.goldLight
                                : TaqwaColors.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 26),
              GestureDetector(
                key: const ValueKey('tasbih-button'),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await widget.controller.tasbihTap();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF2B2113), Color(0xFF141210)],
                    ),
                    border: Border.all(color: TaqwaColors.gold, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33E5A93C),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _phrases[_phrase],
                        style: const TextStyle(
                          color: TaqwaColors.goldLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 64,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: TaqwaColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'von $target',
                        style: const TextStyle(
                          color: TaqwaColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: TaqwaColors.border,
                  color: TaqwaColors.gold,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  count == 0 && target > 0
                      ? 'Tippe auf den Kreis, um zu beginnen.'
                      : count >= target
                      ? 'Ziel erreicht – möge Allah es annehmen.'
                      : 'Noch ${target - count} bis zum Ziel.',
                  style: const TextStyle(color: TaqwaColors.muted, fontSize: 9),
                ),
              ),
              const SizedBox(height: 24),
              const Eyebrow('ZIEL'),
              const SizedBox(height: 8),
              TaqwaCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final value in [33, 99, 100, 1000]) ...[
                          if (value != 33) const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  widget.controller.setTasbihTarget(value),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: target == value
                                      ? const Color(0xFF33250F)
                                      : const Color(0xFF171614),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: target == value
                                        ? TaqwaColors.gold
                                        : TaqwaColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$value',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: target == value
                                          ? TaqwaColors.goldLight
                                          : TaqwaColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Der Zähler springt nach Erreichen des Ziels automatisch zurück auf 0.',
                      style: TextStyle(
                        color: TaqwaColors.muted,
                        fontSize: 8,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

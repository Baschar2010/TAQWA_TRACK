import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class Hadith {
  const Hadith({
    required this.id,
    required this.text,
    required this.source,
    required this.topic,
  });

  factory Hadith.fromJson(Map<String, dynamic> json) => Hadith(
    id: json['id'] as int,
    text: json['text'] as String,
    source: json['source'] as String,
    topic: (json['topic'] as String?) ?? '',
  );

  final int id;
  final String text;
  final String source;
  final String topic;
}

class HadithLibrary {
  HadithLibrary._();

  static List<Hadith>? _cache;

  static Future<List<Hadith>> load({AssetBundle? bundle}) async {
    if (_cache case final cached?) return cached;
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/data/hadiths.json',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = (decoded['hadiths'] as List<dynamic>)
        .map((item) => Hadith.fromJson(item as Map<String, dynamic>))
        .toList();
    _cache = items;
    return items;
  }

  /// Hadith des Tages – wechselt täglich.
  static Hadith ofTheDay(List<Hadith> all, DateTime day) {
    if (all.isEmpty) {
      return const Hadith(id: 0, text: '', source: '', topic: '');
    }
    final start = DateTime(day.year);
    final index = day.difference(start).inDays % all.length;
    return all[index];
  }
}

class HadithOfTheDayCard extends StatelessWidget {
  const HadithOfTheDayCard({super.key, required this.onOpenAll});
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Hadith>>(
    future: HadithLibrary.load(),
    builder: (context, snapshot) {
      final all = snapshot.data;
      final hadith = all == null
          ? null
          : HadithLibrary.ofTheDay(all, DateTime.now());
      return TaqwaCard(
        goldBorder: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF211A0D),
                    border: Border.all(color: TaqwaColors.gold),
                  ),
                  child: const Icon(
                    Icons.auto_stories_outlined,
                    size: 13,
                    color: TaqwaColors.goldLight,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: Eyebrow('HADITH DES TAGES')),
                TextButton(
                  onPressed: onOpenAll,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Alle ›',
                    style: TextStyle(
                      color: TaqwaColors.goldLight,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (hadith == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TaqwaColors.gold,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                '„${hadith.text}“',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: TaqwaColors.text,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.bookmark_border,
                    size: 11,
                    color: TaqwaColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hadith.source,
                      style: const TextStyle(
                        color: TaqwaColors.muted,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

class HadithListScreen extends StatelessWidget {
  const HadithListScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hadith-Sammlung')),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<Hadith>>(
          future: HadithLibrary.load(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            final hadiths = snapshot.data ?? const <Hadith>[];
            final today = HadithLibrary.ofTheDay(hadiths, DateTime.now());
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              itemCount: hadiths.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final hadith = hadiths[index];
                final isToday = hadith.id == today.id;
                return TaqwaCard(
                  goldBorder: isToday,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Eyebrow(
                              hadith.topic.isEmpty ? 'HADITH' : hadith.topic,
                              color: isToday
                                  ? TaqwaColors.gold
                                  : TaqwaColors.muted,
                            ),
                          ),
                          if (isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3A2A11),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: TaqwaColors.gold),
                              ),
                              child: const Text(
                                'Heute',
                                style: TextStyle(
                                  color: TaqwaColors.goldLight,
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '„${hadith.text}“',
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hadith.source,
                        style: const TextStyle(
                          color: TaqwaColors.muted,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

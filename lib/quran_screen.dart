import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.name,
    required this.latin,
    required this.translation,
    required this.revelation,
    required this.verses,
  });

  factory SurahInfo.fromJson(Map<String, dynamic> json) => SurahInfo(
    number: json['number'] as int,
    name: json['name'] as String,
    latin: json['latin'] as String,
    translation: (json['translation'] as String?) ?? '',
    revelation: (json['revelation'] as String?) ?? '',
    verses: json['verses'] as int,
  );

  final int number;
  final String name;
  final String latin;
  final String translation;
  final String revelation;
  final int verses;
}

class QuranVerse {
  const QuranVerse({required this.number, required this.arabic, required this.german});

  factory QuranVerse.fromJson(Map<String, dynamic> json) => QuranVerse(
    number: json['n'] as int,
    arabic: json['ar'] as String,
    german: (json['de'] as String?) ?? '',
  );

  final int number;
  final String arabic;
  final String german;
}

class QuranLibrary {
  QuranLibrary._();

  static List<SurahInfo>? _surahCache;
  static final Map<int, List<QuranVerse>> _verseCache = {};

  static Future<List<SurahInfo>> surahs() async {
    if (_surahCache case final cached?) return cached;
    final raw = await rootBundle.loadString('assets/quran/surahs.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['surahs'] as List<dynamic>)
        .map((e) => SurahInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    _surahCache = list;
    return list;
  }

  static Future<List<QuranVerse>> verses(int surah) async {
    if (_verseCache[surah] case final cached?) return cached;
    final raw = await rootBundle.loadString('assets/quran/surah_$surah.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['verses'] as List<dynamic>)
        .map((e) => QuranVerse.fromJson(e as Map<String, dynamic>))
        .toList();
    _verseCache[surah] = list;
    return list;
  }
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quran')),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<SurahInfo>>(
          future: QuranLibrary.surahs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            final all = snapshot.data ?? const <SurahInfo>[];
            final normalized = _query.trim().toLowerCase();
            final surahs = normalized.isEmpty
                ? all
                : all
                      .where(
                        (s) =>
                            s.latin.toLowerCase().contains(normalized) ||
                            s.name.contains(_query.trim()) ||
                            s.translation.toLowerCase().contains(normalized) ||
                            s.number.toString() == normalized,
                      )
                      .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Sure suchen …',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: TaqwaColors.gold,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                    itemCount: surahs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      return _SurahTile(surah: surah);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah});
  final SurahInfo surah;

  @override
  Widget build(BuildContext context) => TaqwaCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SurahScreen(surah: surah)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF211A0D),
                border: Border.all(color: TaqwaColors.border),
              ),
              child: Center(
                child: Text(
                  '${surah.number}',
                  style: const TextStyle(
                    color: TaqwaColors.goldLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.latin,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${surah.translation} · ${surah.verses} Verse',
                    style: const TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              surah.name,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: TaqwaColors.goldLight,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ),
  );
}

class SurahScreen extends StatefulWidget {
  const SurahScreen({super.key, required this.surah});
  final SurahInfo surah;

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  late final Future<List<QuranVerse>> _verses = QuranLibrary.verses(
    widget.surah.number,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.surah.number}. ${widget.surah.latin}'),
    ),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<QuranVerse>>(
          future: _verses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            final verses = snapshot.data ?? const <QuranVerse>[];
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              itemCount: verses.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TaqwaCard(
                      goldBorder: true,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.surah.name,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: TaqwaColors.goldLight,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.surah.latin} · ${widget.surah.translation}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '${widget.surah.verses} Verse · '
                            '${widget.surah.revelation == 'Meccan' ? 'Mekkanisch' : 'Medinensisch'}',
                            style: const TextStyle(
                              color: TaqwaColors.muted,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final verse = verses[index - 1];
                return _VerseTile(verse: verse);
              },
            );
          },
        ),
      ),
    ),
  );
}

class _VerseTile extends StatelessWidget {
  const _VerseTile({required this.verse});
  final QuranVerse verse;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: TaqwaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            verse.arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 20,
              height: 1.9,
              color: TaqwaColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF221B0E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TaqwaColors.border),
                ),
                child: Text(
                  '${verse.number}',
                  style: const TextStyle(
                    color: TaqwaColors.gold,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verse.german,
                  style: const TextStyle(
                    color: TaqwaColors.muted,
                    fontSize: 10,
                    height: 1.5,
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

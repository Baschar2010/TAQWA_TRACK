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
    required this.tags,
    required this.isPrayer,
  });

  factory Hadith.fromJson(Map<String, dynamic> json) => Hadith(
    id: json['id'] as int,
    text: json['text'] as String,
    source: json['source'] as String,
    topic: (json['topic'] as String?) ?? '',
    tags: [
      for (final tag in (json['tags'] as List<dynamic>? ?? const []))
        tag as String,
    ],
    isPrayer: json['prayer'] == true,
  );

  final int id;
  final String text;
  final String source;
  final String topic;
  final List<String> tags;
  final bool isPrayer;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return text.toLowerCase().contains(q) ||
        source.toLowerCase().contains(q) ||
        topic.toLowerCase().contains(q) ||
        tags.any((tag) => tag.toLowerCase().contains(q));
  }
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
      return const Hadith(
        id: 0,
        text: '',
        source: '',
        topic: '',
        tags: [],
        isPrayer: false,
      );
    }
    final start = DateTime(day.year);
    final index = day.difference(start).inDays % all.length;
    return all[index];
  }

  /// Gebets-Hadith des Tages – wechselt täglich.
  static Hadith prayerOfTheDay(List<Hadith> all, DateTime day) {
    final prayers = all.where((h) => h.isPrayer).toList();
    if (prayers.isEmpty) return ofTheDay(all, day);
    final start = DateTime(day.year);
    final index = day.difference(start).inDays % prayers.length;
    return prayers[index];
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
                    color: TaqwaColors.chip,
                    border: Border.all(color: TaqwaColors.gold),
                  ),
                  child: Icon(
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
                  child: Text(
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
              Padding(
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
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: TaqwaColors.text,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 11,
                    color: TaqwaColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hadith.source,
                      style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
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

/// Kompakte Hadith-Karte für den Gebete-Tab.
class PrayerHadithCard extends StatelessWidget {
  const PrayerHadithCard({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Hadith>>(
    future: HadithLibrary.load(),
    builder: (context, snapshot) {
      final all = snapshot.data;
      final hadith = all == null
          ? null
          : HadithLibrary.prayerOfTheDay(all, DateTime.now());
      return TaqwaCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mosque_outlined, size: 14, color: TaqwaColors.gold),
                const SizedBox(width: 6),
                const Expanded(child: Eyebrow('HADITH ZUM GEBET')),
                if (hadith != null)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const HadithListScreen(prayerOnly: true),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Gebets-Hadithe ›',
                      style: TextStyle(
                        color: TaqwaColors.goldLight,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (hadith == null)
              SizedBox(
                height: 28,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
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
                style: const TextStyle(fontSize: 11, height: 1.45),
              ),
              const SizedBox(height: 6),
              Text(
                hadith.source,
                style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class HadithListScreen extends StatefulWidget {
  const HadithListScreen({super.key, this.prayerOnly = false});
  final bool prayerOnly;

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  String _query = '';
  late bool _prayerOnly = widget.prayerOnly;
  late final Future<List<Hadith>> _items = HadithLibrary.load();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hadith-Bibliothek')),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<Hadith>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            final all = snapshot.data ?? const <Hadith>[];
            final today = HadithLibrary.ofTheDay(all, DateTime.now());
            final visible = all
                .where((h) => !_prayerOnly || h.isPrayer)
                .where((h) => h.matches(_query))
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Hadithe durchsuchen (z. B. Gebet, Geduld) …',
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: TaqwaColors.gold,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Alle (${all.length})',
                        selected: !_prayerOnly,
                        onTap: () => setState(() => _prayerOnly = false),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Gebet (${all.where((h) => h.isPrayer).length})',
                        selected: _prayerOnly,
                        onTap: () => setState(() => _prayerOnly = true),
                      ),
                      const Spacer(),
                      Text(
                        '${visible.length} Treffer',
                        style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'Keine Hadithe gefunden.',
                            style: TextStyle(
                              color: TaqwaColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (context, index) {
                            final hadith = visible[index];
                            final isToday = hadith.id == today.id;
                            return _HadithTile(hadith: hadith, today: isToday);
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? TaqwaColors.navIndicator : TaqwaColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? TaqwaColors.gold : TaqwaColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? TaqwaColors.goldLight : TaqwaColors.muted,
        ),
      ),
    ),
  );
}

class _HadithTile extends StatelessWidget {
  const _HadithTile({required this.hadith, required this.today});
  final Hadith hadith;
  final bool today;

  @override
  Widget build(BuildContext context) => TaqwaCard(
    goldBorder: today,
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => HadithDetailScreen(hadith)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    hadith.topic.isEmpty ? 'HADITH' : hadith.topic,
                    color: today ? TaqwaColors.gold : TaqwaColors.muted,
                  ),
                ),
                if (today)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: TaqwaColors.goldBorder,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TaqwaColors.gold),
                    ),
                    child: Text(
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
            Row(
              children: [
                Icon(Icons.bookmark_border, size: 10, color: TaqwaColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hadith.source,
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: TaqwaColors.goldLight,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class HadithDetailScreen extends StatelessWidget {
  const HadithDetailScreen(this.hadith, {super.key});
  final Hadith hadith;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(hadith.topic.isEmpty ? 'Hadith' : hadith.topic)),
    body: StarField(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            TaqwaCard(
              goldBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '„${hadith.text}“',
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: TaqwaColors.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 13,
                        color: TaqwaColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hadith.source,
                          style: TextStyle(
                            color: TaqwaColors.goldLight,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hadith.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final tag in hadith.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: TaqwaColors.panel,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: TaqwaColors.border),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 8,
                                color: TaqwaColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '„${hadith.text}“\n— ${hadith.source}'),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hadith kopiert'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text(
                'Hadith kopieren',
                style: TextStyle(fontSize: 10),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: TaqwaColors.goldLight,
                side: BorderSide(color: TaqwaColors.border),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

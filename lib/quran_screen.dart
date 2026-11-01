import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'app_controller.dart';
import 'theme.dart';

/// Suren mit offline mitgelieferter Rezitation (alafasy).
const quranAudioSurahs = {1, 112, 113, 114};

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

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return latin.toLowerCase().contains(q) ||
        name.contains(query.trim()) ||
        translation.toLowerCase().contains(q) ||
        number.toString() == q;
  }
}

class QuranVerse {
  const QuranVerse({
    required this.number,
    required this.arabic,
    required this.german,
  });

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

  /// Nur die zuletzt gelesenen Suren bleiben im Speicher. Der ganze Quran
  /// würde sonst dauerhaft mehrere Megabyte belegen.
  static const _maxCachedSurahs = 3;
  static final Map<int, Future<List<QuranVerse>>> _verseCache = {};

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

  static Future<List<QuranVerse>> verses(int surah) {
    final cached = _verseCache.remove(surah);
    if (cached != null) {
      // Als zuletzt benutzt markieren (LRU).
      _verseCache[surah] = cached;
      return cached;
    }
    final future = _loadVerses(surah);
    _verseCache[surah] = future;
    while (_verseCache.length > _maxCachedSurahs) {
      _verseCache.remove(_verseCache.keys.first);
    }
    return future;
  }

  static Future<List<QuranVerse>> _loadVerses(int surah) async {
    final raw = await rootBundle.loadString('assets/quran/surah_$surah.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['verses'] as List<dynamic>)
        .map((e) => QuranVerse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<SurahInfo?> byNumber(int number) async {
    final all = await surahs();
    for (final surah in all) {
      if (surah.number == number) return surah;
    }
    return null;
  }

  @visibleForTesting
  static void clearVerseCache() => _verseCache.clear();
}

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key, required this.controller});
  final TaqwaController controller;

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  String _query = '';
  late final Future<List<SurahInfo>> _surahs = QuranLibrary.surahs();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quran'),
      actions: [
        IconButton(
          tooltip: 'Lesezeichen',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  QuranBookmarksScreen(controller: widget.controller),
            ),
          ),
          icon: const Icon(Icons.bookmarks_outlined, size: 18),
        ),
      ],
    ),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<SurahInfo>>(
          future: _surahs,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            final all = snapshot.data ?? const <SurahInfo>[];
            final surahs = all.where((s) => s.matches(_query)).toList();
            return Column(
              children: [
                if (_query.isEmpty)
                  ValueListenableBuilder<(int, int)?>(
                    valueListenable: widget.controller.lastReadNotifier,
                    builder: (context, progress, _) => progress == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                            child: _ContinueReadingCard(
                              controller: widget.controller,
                              surahs: all,
                            ),
                          ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
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
                    itemBuilder: (context, index) => _SurahTile(
                      surah: surahs[index],
                      controller: widget.controller,
                    ),
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

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.controller, required this.surahs});
  final TaqwaController controller;
  final List<SurahInfo> surahs;

  @override
  Widget build(BuildContext context) {
    final progress = controller.lastRead;
    if (progress == null) return const SizedBox.shrink();
    SurahInfo? surah;
    for (final item in surahs) {
      if (item.number == progress.$1) surah = item;
    }
    if (surah == null) return const SizedBox.shrink();
    return TaqwaCard(
      goldBorder: true,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SurahScreen(
              surah: surah!,
              controller: controller,
              jumpToAyah: progress.$2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: TaqwaColors.gold,
                size: 22,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('WEITERLESEN', color: TaqwaColors.gold),
                    Text(
                      '${surah.latin} · Ayah ${progress.$2}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: TaqwaColors.goldLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({required this.surah, required this.controller});
  final SurahInfo surah;
  final TaqwaController controller;

  @override
  Widget build(BuildContext context) => TaqwaCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SurahScreen(surah: surah, controller: controller),
        ),
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
                color: TaqwaColors.chip,
                border: Border.all(color: TaqwaColors.border),
              ),
              child: Center(
                child: Text(
                  '${surah.number}',
                  style: TextStyle(
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
                    '${surah.translation} · ${surah.verses} Verse'
                    '${quranAudioSurahs.contains(surah.number) ? ' · Audio' : ''}',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
                  ),
                ],
              ),
            ),
            Text(
              surah.name,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: TaqwaColors.goldLight, fontSize: 15),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ),
  );
}

class SurahScreen extends StatefulWidget {
  const SurahScreen({
    super.key,
    required this.surah,
    required this.controller,
    this.jumpToAyah,
  });
  final SurahInfo surah;
  final TaqwaController controller;
  final int? jumpToAyah;

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  late Future<List<QuranVerse>> _verses;
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _targetKey = GlobalKey();
  StreamSubscription<PlayerState>? _playerSub;
  int? _playing;
  int _highestBuilt = 1;
  Timer? _progressTimer;

  bool get _hasAudio => quranAudioSurahs.contains(widget.surah.number);

  @override
  void initState() {
    super.initState();
    _verses = QuranLibrary.verses(widget.surah.number);
    _playerSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        final next = (_playing ?? 0) + 1;
        if (next <= widget.surah.verses) {
          _playAyah(next);
        } else {
          _player.stop();
          if (mounted) setState(() => _playing = null);
        }
      }
    });
    _scroll.addListener(_onScroll);
    _remember(1);
    if (widget.jumpToAyah != null && widget.jumpToAyah! > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToTarget());
    }
  }

  /// Springt zur gespeicherten Ayah. Zuerst wird grob geschätzt, danach
  /// korrigiert [Scrollable.ensureVisible] auf die tatsächliche Höhe der
  /// Karte – Ayahs sind unterschiedlich lang, eine reine Schätzung landet
  /// sonst schnell mehrere Verse daneben.
  void _jumpToTarget() {
    if (!mounted || !_scroll.hasClients) return;
    final ayah = widget.jumpToAyah;
    if (ayah == null) return;
    final estimate = (ayah - 1) * 118.0;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(estimate.clamp(0.0, max));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _targetKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.05,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _retry() {
    QuranLibrary.clearVerseCache();
    setState(() {
      _verses = QuranLibrary.verses(widget.surah.number);
    });
  }

  void _remember(int ayah) {
    _progressTimer?.cancel();
    _progressTimer = Timer(const Duration(milliseconds: 600), () {
      widget.controller.saveLastRead(widget.surah.number, ayah);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final estimate =
        1 + (_scroll.offset / 118).floor().clamp(0, widget.surah.verses - 1);
    _remember(estimate.clamp(1, widget.surah.verses));
  }

  Future<void> _playAyah(int ayah) async {
    if (!_hasAudio) return;
    setState(() => _playing = ayah);
    try {
      await _player.setAsset('assets/audio/${widget.surah.number}_$ayah.mp3');
      await _player.play();
      _remember(ayah);
    } catch (error) {
      debugPrint('Rezitation konnte nicht geladen werden: $error');
      if (!mounted) return;
      setState(() => _playing = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rezitation für diese Ayah nicht verfügbar.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    _scroll.dispose();
    widget.controller.saveLastRead(
      widget.surah.number,
      _highestBuilt.clamp(1, widget.surah.verses),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.surah.number}. ${widget.surah.latin}'),
      actions: [
        IconButton(
          tooltip: 'Gespeicherte Ayah',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  QuranBookmarksScreen(controller: widget.controller),
            ),
          ),
          icon: const Icon(Icons.bookmarks_outlined, size: 18),
        ),
      ],
    ),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<QuranVerse>>(
          future: _verses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        color: TaqwaColors.muted,
                        size: 34,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Diese Sure konnte nicht geladen werden.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TaqwaColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Erneut laden'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final verses = snapshot.data ?? const <QuranVerse>[];
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              itemCount: verses.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _header();
                final verse = verses[index - 1];
                if (verse.number > _highestBuilt) _highestBuilt = verse.number;
                return _VerseTile(
                  key: verse.number == widget.jumpToAyah ? _targetKey : null,
                  verse: verse,
                  surah: widget.surah.number,
                  controller: widget.controller,
                  playing: _playing == verse.number,
                  hasAudio: _hasAudio,
                  onPlay: () {
                    if (_playing == verse.number) {
                      _player.pause();
                      setState(() => _playing = null);
                    } else {
                      _playAyah(verse.number);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    ),
  );

  Widget _header() => Padding(
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
            style: TextStyle(
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
            style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
          ),
          if (_hasAudio)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Rezitation offline verfügbar (Mishary Alafasy)',
                style: TextStyle(color: TaqwaColors.green, fontSize: 8),
              ),
            ),
        ],
      ),
    ),
  );
}

class _VerseTile extends StatelessWidget {
  const _VerseTile({
    super.key,
    required this.verse,
    required this.surah,
    required this.controller,
    required this.playing,
    required this.hasAudio,
    required this.onPlay,
  });
  final QuranVerse verse;
  final int surah;
  final TaqwaController controller;
  final bool playing;
  final bool hasAudio;
  final VoidCallback onPlay;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${verse.arabic}\n\n${verse.german}\n\n'
            '— Sure $surah, Ayah ${verse.number}',
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ayah kopiert')));
  }

  @override
  Widget build(BuildContext context) {
    final bookmarked = controller.isBookmarked(surah, verse.number);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Semantics(
        hint: 'Lange drücken, um die Ayah zu kopieren',
        child: GestureDetector(
          onLongPress: () => _copy(context),
          child: TaqwaCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  verse.arabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: TaqwaColors.chip,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: TaqwaColors.border),
                      ),
                      child: Text(
                        '${verse.number}',
                        style: TextStyle(
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
                        style: TextStyle(
                          color: TaqwaColors.muted,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (hasAudio)
                      IconButton(
                        tooltip: playing ? 'Pause' : 'Ayah anhören',
                        onPressed: onPlay,
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_outline,
                          size: 20,
                          color: TaqwaColors.gold,
                        ),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    IconButton(
                      tooltip: bookmarked
                          ? 'Lesezeichen entfernen'
                          : 'Ayah merken',
                      onPressed: () =>
                          controller.toggleBookmark(surah, verse.number),
                      icon: Icon(
                        bookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                        color: bookmarked
                            ? TaqwaColors.gold
                            : TaqwaColors.muted,
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuranBookmarksScreen extends StatefulWidget {
  const QuranBookmarksScreen({super.key, required this.controller});
  final TaqwaController controller;

  @override
  State<QuranBookmarksScreen> createState() => _QuranBookmarksScreenState();
}

class _QuranBookmarksScreenState extends State<QuranBookmarksScreen> {
  late final Future<List<SurahInfo>> _surahs = QuranLibrary.surahs();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lesezeichen')),
    body: StarField(
      child: SafeArea(
        child: FutureBuilder<List<SurahInfo>>(
          future: _surahs,
          builder: (context, snapshot) {
            final surahs = snapshot.data ?? const <SurahInfo>[];
            final marks = widget.controller.bookmarks;
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: CircularProgressIndicator(color: TaqwaColors.gold),
              );
            }
            if (marks.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Noch keine Lesezeichen.\nTippe beim Lesen auf das Lesezeichen-Symbol.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 11),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: marks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 7),
              itemBuilder: (context, index) {
                final mark = marks[index];
                SurahInfo? surah;
                for (final item in surahs) {
                  if (item.number == mark.$1) surah = item;
                }
                return TaqwaCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      surah == null
                          ? 'Sure ${mark.$1}'
                          : '${surah.latin} · Ayah ${mark.$2}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    subtitle: Text(
                      'Antippen zum Weiterlesen',
                      style: TextStyle(fontSize: 8, color: TaqwaColors.muted),
                    ),
                    trailing: IconButton(
                      onPressed: () async {
                        await widget.controller.toggleBookmark(
                          mark.$1,
                          mark.$2,
                        );
                        setState(() {});
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: TaqwaColors.muted,
                      ),
                    ),
                    onTap: surah == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SurahScreen(
                                surah: surah!,
                                controller: widget.controller,
                                jumpToAyah: mark.$2,
                              ),
                            ),
                          ),
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

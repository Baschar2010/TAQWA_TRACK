import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain.dart';

class PrayerAward {
  const PrayerAward({required this.xpAdded, required this.streakAdvanced});
  final int xpAdded;
  final bool streakAdvanced;
}

class HabitAward {
  const HabitAward(this.xpAdded);
  final int xpAdded;
}

class FamilyMember {
  const FamilyMember({required this.id, required this.name});
  final int id;
  final String name;
}

class Partner {
  const Partner({
    required this.id,
    required this.code,
    required this.name,
    this.alias,
    this.prayerMask = '00000',
    this.habitsDone = 0,
    this.habitsTotal = 0,
    this.streak = 0,
    this.snapshotDay = '',
    this.snapshotAt,
    this.reminderAt,
    this.reminderText,
  });
  final int id;
  final String code;
  final String name;

  /// Nur auf diesem Gerät gesetzter Spitzname. Er wird nie per QR-Code
  /// übertragen und überschreibt deshalb nie den Namen des anderen Geräts.
  final String? alias;
  final String prayerMask;
  final int habitsDone;
  final int habitsTotal;
  final int streak;
  final String snapshotDay;
  final String? snapshotAt;
  final String? reminderAt;
  final String? reminderText;

  String get displayName {
    final local = alias?.trim() ?? '';
    return local.isEmpty ? name : local;
  }

  int get prayersDone => prayerMask.split('').where((c) => c == '1').length;

  bool prayerDone(Prayer prayer) {
    final index = Prayer.values.indexOf(prayer);
    return index < prayerMask.length && prayerMask[index] == '1';
  }
}

class TaqwaRepository {
  TaqwaRepository({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _path = path;

  final DatabaseFactory _factory;
  final String? _path;
  Database? _db;

  Future<Database> get database async {
    if (_db case final db?) return db;
    final path =
        _path ?? p.join(await getDatabasesPath(), 'taqwa_track.sqlite');
    _db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return _db!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL,
      xp INTEGER NOT NULL DEFAULT 0,
      streak INTEGER NOT NULL DEFAULT 0,
      location_name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      last_completed_day TEXT,
      calculation_method TEXT NOT NULL DEFAULT 'muslim_world_league',
      hanafi INTEGER NOT NULL DEFAULT 1,
      profile_id TEXT NOT NULL DEFAULT '',
      onboarded INTEGER NOT NULL DEFAULT 0,
      language TEXT NOT NULL DEFAULT 'de',
      oled INTEGER NOT NULL DEFAULT 0,
      theme_mode TEXT NOT NULL DEFAULT 'system',
      adhan_enabled INTEGER NOT NULL DEFAULT 0,
      adhan_minutes_before INTEGER NOT NULL DEFAULT 0,
      tasbih_count INTEGER NOT NULL DEFAULT 0,
      tasbih_target INTEGER NOT NULL DEFAULT 33,
      outbox_reminder_at TEXT,
      outbox_reminder_text TEXT,
      gold_day TEXT
    )''');
    await db.insert('settings', {
      'id': 1,
      'name': 'Mein Profil',
      'xp': 0,
      'streak': 0,
      'location_name': 'Duisburg',
      'latitude': 51.4344,
      'longitude': 6.7623,
      'last_completed_day': null,
      'calculation_method': 'muslim_world_league',
      'hanafi': 1,
      'profile_id': generateProfileCode(),
      'onboarded': 0,
    });
    await db.execute('''CREATE TABLE prayer_logs (
      day TEXT NOT NULL,
      prayer TEXT NOT NULL,
      done INTEGER NOT NULL DEFAULT 0,
      xp_awarded INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (day, prayer)
    )''');
    await db.execute('''CREATE TABLE daily_awards (
      day TEXT PRIMARY KEY,
      five_bonus INTEGER NOT NULL DEFAULT 0,
      streak_awarded INTEGER NOT NULL DEFAULT 0
    )''');
    await db.execute('''CREATE TABLE habits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      sort_order INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1,
      built_in INTEGER NOT NULL DEFAULT 0
    )''');
    for (final (i, name) in [
      'Qur’an lesen',
      '100× Dhikr',
      'Dankbarkeit',
    ].indexed) {
      await db.insert('habits', {'name': name, 'sort_order': i, 'built_in': 1});
    }
    await db.execute('''CREATE TABLE habit_logs (
      day TEXT NOT NULL,
      habit_id INTEGER NOT NULL,
      status INTEGER NOT NULL DEFAULT 0,
      xp_awarded INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (day, habit_id),
      FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE family_members (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE family_prayers (
      day TEXT NOT NULL,
      member_id INTEGER NOT NULL,
      prayer TEXT NOT NULL,
      done INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (day, member_id, prayer),
      FOREIGN KEY (member_id) REFERENCES family_members(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE partners (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      alias TEXT,
      linked_at TEXT NOT NULL,
      prayer_mask TEXT NOT NULL DEFAULT '00000',
      habits_done INTEGER NOT NULL DEFAULT 0,
      habits_total INTEGER NOT NULL DEFAULT 0,
      streak INTEGER NOT NULL DEFAULT 0,
      snapshot_day TEXT NOT NULL DEFAULT '',
      snapshot_at TEXT,
      reminder_at TEXT,
      reminder_text TEXT
    )''');
    await db.execute('''CREATE TABLE quran_bookmarks (
      surah INTEGER NOT NULL,
      ayah INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (surah, ayah)
    )''');
    await db.execute('''CREATE TABLE quran_progress (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      surah INTEGER NOT NULL DEFAULT 1,
      ayah INTEGER NOT NULL DEFAULT 1,
      updated_at TEXT
    )''');
    await db.insert('quran_progress', {'id': 1});
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE settings ADD COLUMN profile_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE settings ADD COLUMN onboarded INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('''CREATE TABLE IF NOT EXISTS partners (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        linked_at TEXT NOT NULL
      )''');
      final rows = await db.query('settings', where: 'id = 1');
      if (rows.isNotEmpty && (rows.single['profile_id'] as String).isEmpty) {
        await db.update('settings', {
          'profile_id': generateProfileCode(),
        }, where: 'id = 1');
      }
    }
    if (oldVersion < 3) {
      for (final statement in [
        'ALTER TABLE settings ADD COLUMN oled INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE settings ADD COLUMN adhan_enabled INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE settings ADD COLUMN adhan_minutes_before INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE settings ADD COLUMN tasbih_count INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE settings ADD COLUMN tasbih_target INTEGER NOT NULL DEFAULT 33',
        'ALTER TABLE settings ADD COLUMN outbox_reminder_at TEXT',
        'ALTER TABLE settings ADD COLUMN outbox_reminder_text TEXT',
        'ALTER TABLE settings ADD COLUMN gold_day TEXT',
        'ALTER TABLE habits ADD COLUMN built_in INTEGER NOT NULL DEFAULT 0',
        "ALTER TABLE partners ADD COLUMN prayer_mask TEXT NOT NULL DEFAULT '00000'",
        'ALTER TABLE partners ADD COLUMN habits_done INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE partners ADD COLUMN habits_total INTEGER NOT NULL DEFAULT 0',
        'ALTER TABLE partners ADD COLUMN streak INTEGER NOT NULL DEFAULT 0',
        "ALTER TABLE partners ADD COLUMN snapshot_day TEXT NOT NULL DEFAULT ''",
        'ALTER TABLE partners ADD COLUMN snapshot_at TEXT',
        'ALTER TABLE partners ADD COLUMN reminder_at TEXT',
        'ALTER TABLE partners ADD COLUMN reminder_text TEXT',
        '''CREATE TABLE IF NOT EXISTS quran_bookmarks (
          surah INTEGER NOT NULL,
          ayah INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          PRIMARY KEY (surah, ayah)
        )''',
        '''CREATE TABLE IF NOT EXISTS quran_progress (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          surah INTEGER NOT NULL DEFAULT 1,
          ayah INTEGER NOT NULL DEFAULT 1,
          updated_at TEXT
        )''',
      ]) {
        await db.execute(statement);
      }
      await db.rawUpdate(
        'UPDATE habits SET built_in = 1 WHERE id IN '
        '(SELECT id FROM habits ORDER BY sort_order, id LIMIT 3)',
      );
      await db.insert('quran_progress', {
        'id': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Ohne Namenseingabe ist das Profil ab jetzt automatisch eingerichtet.
      await db.update('settings', {'onboarded': 1}, where: 'id = 1');
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE settings ADD COLUMN language TEXT NOT NULL DEFAULT 'de'",
      );
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE partners ADD COLUMN alias TEXT');
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE settings ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'",
      );
    }
  }

  Future<AppSettings> loadSettings() async {
    final db = await database;
    final row = (await db.query('settings', where: 'id = 1')).single;
    return AppSettings(
      name: row['name']! as String,
      xp: row['xp']! as int,
      streak: row['streak']! as int,
      locationName: row['location_name']! as String,
      latitude: (row['latitude']! as num).toDouble(),
      longitude: (row['longitude']! as num).toDouble(),
      lastCompletedDay: row['last_completed_day'] as String?,
      calculationMethod: row['calculation_method']! as String,
      hanafi: row['hanafi'] == 1,
      profileId: (row['profile_id'] as String?) ?? '',
      onboarded: row['onboarded'] == 1,
      language: (row['language'] as String?) ?? 'de',
      oled: row['oled'] == 1,
      themeMode: (row['theme_mode'] as String?) ?? 'system',
      adhanEnabled: row['adhan_enabled'] == 1,
      adhanMinutesBefore: (row['adhan_minutes_before'] as int?) ?? 0,
      tasbihCount: (row['tasbih_count'] as int?) ?? 0,
      tasbihTarget: (row['tasbih_target'] as int?) ?? 33,
      outboxReminderAt: row['outbox_reminder_at'] as String?,
      outboxReminderText: row['outbox_reminder_text'] as String?,
      goldDay: row['gold_day'] as String?,
    );
  }

  Future<void> updateSettings({
    String? name,
    String? locationName,
    double? latitude,
    double? longitude,
    String? calculationMethod,
    bool? hanafi,
    String? language,
    bool? oled,
    String? themeMode,
    bool? adhanEnabled,
    int? adhanMinutesBefore,
    int? tasbihCount,
    int? tasbihTarget,
    String? outboxReminderAt,
    String? outboxReminderText,
    bool clearOutbox = false,
    String? goldDay,
  }) async {
    final values = <String, Object?>{};
    if (name != null) values['name'] = name;
    if (locationName != null) values['location_name'] = locationName;
    if (latitude != null) values['latitude'] = latitude;
    if (longitude != null) values['longitude'] = longitude;
    if (calculationMethod != null) {
      values['calculation_method'] = calculationMethod;
    }
    if (hanafi != null) {
      values['hanafi'] = hanafi ? 1 : 0;
    }
    if (language != null) values['language'] = language;
    if (oled != null) values['oled'] = oled ? 1 : 0;
    if (themeMode != null) values['theme_mode'] = themeMode;
    if (adhanEnabled != null) {
      values['adhan_enabled'] = adhanEnabled ? 1 : 0;
    }
    if (adhanMinutesBefore != null) {
      values['adhan_minutes_before'] = adhanMinutesBefore;
    }
    if (tasbihCount != null) values['tasbih_count'] = tasbihCount;
    if (tasbihTarget != null) values['tasbih_target'] = tasbihTarget;
    if (clearOutbox) {
      values['outbox_reminder_at'] = null;
      values['outbox_reminder_text'] = null;
    } else {
      if (outboxReminderAt != null) {
        values['outbox_reminder_at'] = outboxReminderAt;
      }
      if (outboxReminderText != null) {
        values['outbox_reminder_text'] = outboxReminderText;
      }
    }
    if (goldDay != null) values['gold_day'] = goldDay;
    if (values.isNotEmpty) {
      await (await database).update('settings', values, where: 'id = 1');
    }
  }

  /// Sorgt dafür, dass jede Installation automatisch ein eigenes Profil hat.
  Future<AppSettings> ensureProfile() async {
    final db = await database;
    var settings = await loadSettings();
    if (settings.profileId.isEmpty) {
      final code = generateProfileCode();
      await db.update('settings', {'profile_id': code}, where: 'id = 1');
      settings = await loadSettings();
    }
    return settings;
  }

  Future<Map<Prayer, bool>> prayerStatuses(DateTime date) async {
    final rows = await (await database).query(
      'prayer_logs',
      where: 'day = ?',
      whereArgs: [dayKey(date)],
    );
    return {
      for (final prayer in Prayer.values) prayer: false,
      for (final row in rows)
        Prayer.values.byName(row['prayer']! as String): row['done'] == 1,
    };
  }

  Future<PrayerAward> togglePrayer(DateTime date, Prayer prayer) async {
    final db = await database;
    final key = dayKey(date);
    return db.transaction((txn) async {
      final existing = await txn.query(
        'prayer_logs',
        where: 'day = ? AND prayer = ?',
        whereArgs: [key, prayer.name],
      );
      final row = existing.isEmpty ? null : existing.single;
      final nextDone = row?['done'] != 1;
      var earned = 0;
      final xpWasAwarded = row?['xp_awarded'] == 1;
      if (nextDone && !xpWasAwarded) earned = 10;
      await txn.insert('prayer_logs', {
        'day': key,
        'prayer': prayer.name,
        'done': nextDone ? 1 : 0,
        'xp_awarded': (xpWasAwarded || earned > 0) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      var advanced = false;
      final doneRows = await txn.query(
        'prayer_logs',
        where: 'day = ? AND done = 1',
        whereArgs: [key],
      );
      final awardRows = await txn.query(
        'daily_awards',
        where: 'day = ?',
        whereArgs: [key],
      );
      final award = awardRows.isEmpty ? null : awardRows.single;
      if (doneRows.length == 5 && award?['five_bonus'] != 1) {
        earned += 20;
        final settings = (await txn.query('settings', where: 'id = 1')).single;
        final last = settings['last_completed_day'] as String?;
        final yesterday = dayKey(date.subtract(const Duration(days: 1)));
        final previousStreak = settings['streak']! as int;
        final nextStreak = last == key
            ? previousStreak
            : last == yesterday
            ? previousStreak + 1
            : 1;
        if (last != key) {
          earned += 10;
          advanced = true;
        }
        await txn.update('settings', {
          'xp': (settings['xp']! as int) + earned,
          'streak': nextStreak,
          'last_completed_day': key,
        }, where: 'id = 1');
        await txn.insert('daily_awards', {
          'day': key,
          'five_bonus': 1,
          'streak_awarded': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (earned > 0) {
        await txn.rawUpdate('UPDATE settings SET xp = xp + ? WHERE id = 1', [
          earned,
        ]);
      }
      return PrayerAward(xpAdded: earned, streakAdvanced: advanced);
    });
  }

  Future<List<Map<String, Object?>>> habits() async => (await database).query(
    'habits',
    where: 'active = 1',
    orderBy: 'sort_order, id',
  );

  Future<Map<int, HabitStatus>> habitStatuses(DateTime date) async {
    final rows = await (await database).query(
      'habit_logs',
      where: 'day = ?',
      whereArgs: [dayKey(date)],
    );
    return {
      for (final row in rows)
        row['habit_id']! as int: HabitStatus.values[row['status']! as int],
    };
  }

  Future<HabitAward> setHabitStatus(
    DateTime date,
    int habitId,
    HabitStatus status,
  ) async {
    final db = await database;
    final key = dayKey(date);
    return db.transaction((txn) async {
      final rows = await txn.query(
        'habit_logs',
        where: 'day = ? AND habit_id = ?',
        whereArgs: [key, habitId],
      );
      final old = rows.isEmpty ? null : rows.single;
      final wasAwarded = old?['xp_awarded'] == 1;
      final points = status == HabitStatus.done && !wasAwarded ? 5 : 0;
      await txn.insert('habit_logs', {
        'day': key,
        'habit_id': habitId,
        'status': status.index,
        'xp_awarded': (wasAwarded || points > 0) ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (points > 0) {
        await txn.rawUpdate('UPDATE settings SET xp = xp + ? WHERE id = 1', [
          points,
        ]);
      }
      return HabitAward(points);
    });
  }

  Future<int> addHabit(String name) async {
    final db = await database;
    final max =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM habits',
          ),
        ) ??
        0;
    return db.insert('habits', {'name': name.trim(), 'sort_order': max});
  }

  Future<void> removeHabit(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('habit_logs', where: 'habit_id = ?', whereArgs: [id]);
      await txn.delete('habits', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Map<String, Map<int, HabitStatus>>> habitWeek(DateTime endDate) async {
    final start = endDate.subtract(const Duration(days: 7));
    final rows = await (await database).query(
      'habit_logs',
      where: 'day >= ? AND day <= ?',
      whereArgs: [dayKey(start), dayKey(endDate)],
    );
    final result = <String, Map<int, HabitStatus>>{};
    for (final row in rows) {
      result.putIfAbsent(
        row['day']! as String,
        () => {},
      )[row['habit_id']! as int] = HabitStatus.values[row['status']! as int];
    }
    return result;
  }

  Future<List<FamilyMember>> familyMembers() async => (await database)
      .query('family_members', orderBy: 'id')
      .then(
        (rows) => rows
            .map(
              (r) =>
                  FamilyMember(id: r['id']! as int, name: r['name']! as String),
            )
            .toList(),
      );

  Future<int> addFamilyMember(String name) async =>
      (await database).insert('family_members', {'name': name.trim()});

  Future<void> removeFamilyMember(int id) async {
    final db = await database;
    await db.delete('family_prayers', where: 'member_id = ?', whereArgs: [id]);
    await db.delete('family_members', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> completeOnboarding(
    String name,
    String profileId, {
    String language = 'de',
  }) async {
    await (await database).update('settings', {
      'name': name.trim().isEmpty ? 'Mein Profil' : name.trim(),
      'profile_id': profileId,
      'language': language,
      'onboarded': 1,
    }, where: 'id = 1');
  }

  Future<List<Partner>> partners() async => (await database)
      .query('partners', orderBy: 'id')
      .then(
        (rows) => rows
            .map(
              (r) => Partner(
                id: r['id']! as int,
                code: r['code']! as String,
                name: r['name']! as String,
                alias: r['alias'] as String?,
                prayerMask: (r['prayer_mask'] as String?) ?? '00000',
                habitsDone: (r['habits_done'] as int?) ?? 0,
                habitsTotal: (r['habits_total'] as int?) ?? 0,
                streak: (r['streak'] as int?) ?? 0,
                snapshotDay: (r['snapshot_day'] as String?) ?? '',
                snapshotAt: r['snapshot_at'] as String?,
                reminderAt: r['reminder_at'] as String?,
                reminderText: r['reminder_text'] as String?,
              ),
            )
            .toList(),
      );

  /// Verknüpft bzw. aktualisiert einen Partner aus einem gescannten QR-Code.
  Future<Partner> savePartnerSnapshot(ProfileSnapshot snapshot) async {
    final db = await database;
    final values = <String, Object?>{
      'code': snapshot.code,
      'name': snapshot.name.isEmpty ? 'Partner' : snapshot.name,
      'prayer_mask': snapshot.prayerMask,
      'habits_done': snapshot.habitsDone,
      'habits_total': snapshot.habitsTotal,
      'streak': snapshot.streak,
      'snapshot_day': snapshot.day,
      'snapshot_at': DateTime.now().toIso8601String(),
      'reminder_at': snapshot.reminderAt,
      'reminder_text': snapshot.reminderText,
    };
    final existing = await db.query(
      'partners',
      where: 'code = ?',
      whereArgs: [snapshot.code],
    );
    if (existing.isEmpty) {
      values['linked_at'] = DateTime.now().toIso8601String();
      await db.insert('partners', values);
    } else {
      await db.update(
        'partners',
        values,
        where: 'code = ?',
        whereArgs: [snapshot.code],
      );
    }
    return (await partners()).firstWhere((p) => p.code == snapshot.code);
  }

  /// Fortschritt der Standard-Habits (ohne selbst angelegte Habits).
  Future<(int done, int total)> builtInHabitProgress(DateTime date) async {
    final db = await database;
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM habits WHERE active = 1 AND built_in = 1',
          ),
        ) ??
        0;
    final done =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''SELECT COUNT(*) FROM habit_logs l
               JOIN habits h ON h.id = l.habit_id
               WHERE l.day = ? AND l.status = ? AND h.built_in = 1''',
            [dayKey(date), HabitStatus.done.index],
          ),
        ) ??
        0;
    return (done, total);
  }

  Future<void> markReminderDelivered(int id) async => (await database).update(
    'partners',
    {'reminder_at': null, 'reminder_text': null},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> unlinkPartner(int id) async =>
      (await database).delete('partners', where: 'id = ?', whereArgs: [id]);

  /// Setzt einen rein lokalen Spitznamen. Er bleibt auf diesem Gerät und
  /// wird nicht über den QR-Code an das andere Gerät übertragen.
  /// `null` oder ein leerer Text entfernt den Spitznamen wieder.
  Future<void> setPartnerAlias(int id, String? alias) async {
    final clean = alias?.trim() ?? '';
    await (await database).update(
      'partners',
      {'alias': clean.isEmpty ? null : clean},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<(int, int)>> quranBookmarks() async => (await database)
      .query('quran_bookmarks', orderBy: 'created_at DESC')
      .then(
        (rows) =>
            rows.map((r) => (r['surah']! as int, r['ayah']! as int)).toList(),
      );

  Future<bool> toggleQuranBookmark(int surah, int ayah) async {
    final db = await database;
    final existing = await db.query(
      'quran_bookmarks',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
    );
    if (existing.isEmpty) {
      await db.insert('quran_bookmarks', {
        'surah': surah,
        'ayah': ayah,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    }
    await db.delete(
      'quran_bookmarks',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
    );
    return false;
  }

  Future<(int, int)?> quranProgress() async {
    final rows = await (await database).query(
      'quran_progress',
      where: 'id = 1',
    );
    if (rows.isEmpty) return null;
    return (rows.single['surah']! as int, rows.single['ayah']! as int);
  }

  Future<void> saveQuranProgress(int surah, int ayah) async =>
      (await database).update('quran_progress', {
        'surah': surah,
        'ayah': ayah,
        'updated_at': DateTime.now().toIso8601String(),
      }, where: 'id = 1');

  Future<Map<String, bool>> familyPrayerStatus(
    DateTime date,
    int memberId,
  ) async {
    final rows = await (await database).query(
      'family_prayers',
      where: 'day = ? AND member_id = ?',
      whereArgs: [dayKey(date), memberId],
    );
    return {
      for (final prayer in Prayer.values) prayer.name: false,
      for (final row in rows) row['prayer']! as String: row['done'] == 1,
    };
  }

  Future<void> setFamilyPrayer(
    DateTime date,
    int memberId,
    Prayer prayer,
    bool done,
  ) async => (await database).insert('family_prayers', {
    'day': dayKey(date),
    'member_id': memberId,
    'prayer': prayer.name,
    'done': done ? 1 : 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

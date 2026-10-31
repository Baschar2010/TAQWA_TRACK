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
  const Partner({required this.id, required this.code, required this.name});
  final int id;
  final String code;
  final String name;
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
        version: 2,
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
      onboarded INTEGER NOT NULL DEFAULT 0
    )''');
    await db.insert('settings', {
      'id': 1,
      'name': 'Hamza',
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
      active INTEGER NOT NULL DEFAULT 1
    )''');
    for (final (i, name) in [
      'Qur’an lesen',
      '100× Dhikr',
      'Dankbarkeit',
    ].indexed) {
      await db.insert('habits', {'name': name, 'sort_order': i});
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
      linked_at TEXT NOT NULL
    )''');
  }

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
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
    );
  }

  Future<void> updateSettings({
    String? name,
    String? locationName,
    double? latitude,
    double? longitude,
    String? calculationMethod,
    bool? hanafi,
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
    if (values.isNotEmpty) {
      await (await database).update('settings', values, where: 'id = 1');
    }
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
    await db.delete(
      'family_prayers',
      where: 'member_id = ?',
      whereArgs: [id],
    );
    await db.delete('family_members', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> completeOnboarding(String name, String profileId) async {
    await (await database).update('settings', {
      'name': name.trim(),
      'profile_id': profileId,
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
              ),
            )
            .toList(),
      );

  Future<bool> linkPartner(String code, String name) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return false;
    final exists = await (await database).query(
      'partners',
      where: 'code = ?',
      whereArgs: [clean],
    );
    if (exists.isNotEmpty) return false;
    await (await database).insert('partners', {
      'code': clean,
      'name': name.trim().isEmpty ? 'Partner' : name.trim(),
      'linked_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<void> unlinkPartner(int id) async =>
      (await database).delete('partners', where: 'id = ?', whereArgs: [id]);

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

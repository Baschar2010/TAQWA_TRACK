import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taqwa_track/app_controller.dart';
import 'package:taqwa_track/data/taqwa_repository.dart';
import 'package:taqwa_track/domain.dart';
import 'package:taqwa_track/main.dart';

class _FakeRepository extends TaqwaRepository {
  _FakeRepository() : super(factory: databaseFactoryFfi);
  AppSettings settings = const AppSettings(
    name: 'Hamza',
    xp: 0,
    streak: 0,
    locationName: 'Duisburg',
    latitude: 51.4344,
    longitude: 6.7623,
    lastCompletedDay: null,
    calculationMethod: 'muslim_world_league',
    hanafi: true,
  );
  final prayerLog = <Prayer, bool>{for (final p in Prayer.values) p: false};
  final habitList = <Map<String, Object?>>[
    {'id': 1, 'name': 'Qur’an lesen'},
    {'id': 2, 'name': '100× Dhikr'},
    {'id': 3, 'name': 'Dankbarkeit'},
  ];
  final habitLog = <int, HabitStatus>{};
  final awardedHabits = <int>{};
  final members = <FamilyMember>[];
  final familyLog = <int, Map<String, bool>>{};

  @override
  Future<AppSettings> loadSettings() async => settings;
  @override
  Future<Map<Prayer, bool>> prayerStatuses(DateTime date) async => {
    ...prayerLog,
  };
  @override
  Future<PrayerAward> togglePrayer(DateTime date, Prayer prayer) async {
    prayerLog[prayer] = !prayerLog[prayer]!;
    final points = prayerLog[prayer]! ? 10 : 0;
    settings = settings.copyWith(xp: settings.xp + points);
    return PrayerAward(xpAdded: points, streakAdvanced: false);
  }

  @override
  Future<List<Map<String, Object?>>> habits() async => habitList;
  @override
  Future<Map<int, HabitStatus>> habitStatuses(DateTime date) async => {
    ...habitLog,
  };
  @override
  Future<Map<String, Map<int, HabitStatus>>> habitWeek(DateTime date) async =>
      {};
  @override
  Future<HabitAward> setHabitStatus(
    DateTime date,
    int id,
    HabitStatus status,
  ) async {
    habitLog[id] = status;
    final points = status == HabitStatus.done && awardedHabits.add(id) ? 5 : 0;
    settings = settings.copyWith(xp: settings.xp + points);
    return HabitAward(points);
  }

  @override
  Future<int> addHabit(String name) async {
    final id = (habitList.last['id']! as int) + 1;
    habitList.add({'id': id, 'name': name});
    return id;
  }

  @override
  Future<void> removeHabit(int id) async =>
      habitList.removeWhere((h) => h['id'] == id);
  @override
  Future<List<FamilyMember>> familyMembers() async => [...members];
  @override
  Future<int> addFamilyMember(String name) async {
    final id = members.length + 1;
    members.add(FamilyMember(id: id, name: name));
    familyLog[id] = {for (final p in Prayer.values) p.name: false};
    return id;
  }

  @override
  Future<Map<String, bool>> familyPrayerStatus(DateTime date, int id) async => {
    ...familyLog[id]!,
  };
  @override
  Future<void> setFamilyPrayer(
    DateTime date,
    int id,
    Prayer prayer,
    bool done,
  ) async {
    familyLog[id]![prayer.name] = done;
  }

  @override
  Future<void> updateSettings({
    String? name,
    String? locationName,
    double? latitude,
    double? longitude,
    String? calculationMethod,
    bool? hanafi,
  }) async {
    settings = settings.copyWith(
      name: name,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      calculationMethod: calculationMethod,
      hanafi: hanafi,
    );
  }

  @override
  Future<void> close() async {}
}

void main() {
  late TaqwaController controller;
  late _FakeRepository repository;
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('de_DE');
  });

  setUp(() async {
    repository = _FakeRepository();
    controller = TaqwaController(
      repository,
      clock: () => DateTime(2026, 10, 30, 12),
    );
    await controller.initialize();
  });

  testWidgets('prayer, calendar, and family controls respond', (tester) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);
    expect(find.text('TAQWA TRACK'), findsOneWidget);
    expect(find.text('As-salāmu ʿalaykum, Hamza'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('prayer-fajr')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.settings!.xp, 10);
    expect(controller.prayers[Prayer.fajr], isTrue);

    await tester.tap(find.text('Kalender'));
    await settleApp(tester);
    expect(find.text('Habit-Tracker'), findsOneWidget);
    expect(find.text('Qur’an lesen'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('habit-1-2026-10-30')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.settings!.xp, 15);
    expect(controller.todayHabits[1], HabitStatus.done);

    await tester.tap(find.text('Family'));
    await settleApp(tester);
    expect(find.text('Noch keine Mitglieder'), findsOneWidget);
    await controller.addFamilyMember('Aisha');
    await tester.pump();
    expect(find.text('Aisha'), findsOneWidget);
    final member = controller.family.single;
    await controller.toggleFamilyPrayer(member.id, Prayer.fajr, true);
    await tester.pump();
    expect(controller.familyPrayers[member.id]?['fajr'], isTrue);
  });

  testWidgets('Gebete-Tab zeigt die Tages-Habits und hakt sie ab', (
    tester,
  ) async {
    await tester.pumpWidget(TaqwaTrackApp(controller: controller));
    await settleApp(tester);

    await tester.tap(find.text('Gebete'));
    await settleApp(tester);
    expect(find.text('Tages-Habits'), findsOneWidget);
    expect(find.textContaining('HEUTE ·'), findsOneWidget);
    expect(find.text('0/5'), findsOneWidget);
    expect(find.textContaining('bis zum Tagesziel'), findsOneWidget);

    final fajr = find.byKey(const ValueKey('habit-fajr'));
    await tester.ensureVisible(fajr);
    await tester.tap(fajr);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.todayPrayers[Prayer.fajr], isTrue);
    expect(find.text('1/5'), findsOneWidget);

    for (final prayer in Prayer.values.skip(1)) {
      await controller.togglePrayerToday(prayer);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.allPrayersTodayDone, isTrue);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.textContaining('MashaAllah'), findsOneWidget);
  });
}

Future<void> settleApp(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

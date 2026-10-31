import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'data/taqwa_repository.dart';
import 'domain.dart';

class Habit {
  const Habit({required this.id, required this.name});
  final int id;
  final String name;
}

class TaqwaController extends ChangeNotifier {
  TaqwaController(this.repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaqwaRepository repository;
  final DateTime Function() _clock;

  AppSettings? settings;
  PrayerSchedule? schedule;
  Map<Prayer, bool> prayers = {};
  List<Habit> habits = [];
  Map<int, HabitStatus> todayHabits = {};
  Map<String, Map<int, HabitStatus>> weekHabits = {};
  List<FamilyMember> family = [];
  Map<int, Map<String, bool>> familyPrayers = {};
  DateTime selectedDate = DateTime.now();
  bool ready = false;
  String? error;

  DateTime get now => _clock();
  int get completedPrayers => prayers.values.where((done) => done).length;
  int get completedHabits =>
      todayHabits.values.where((s) => s == HabitStatus.done).length;
  Prayer? get nextPrayer => schedule?.nextPrayer(now);
  Duration? get timeUntilNextPrayer {
    final prayer = nextPrayer;
    if (prayer == null) return null;
    return schedule!.times[prayer]!.difference(now);
  }

  Future<void> initialize() async {
    try {
      settings = await repository.loadSettings();
      selectedDate = DateTime(now.year, now.month, now.day);
      await refresh();
      ready = true;
      notifyListeners();
    } catch (e) {
      error = 'Die lokalen App-Daten konnten nicht geladen werden: $e';
      ready = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final current = settings ?? await repository.loadSettings();
    schedule = PrayerSchedule.calculate(
      date: selectedDate,
      latitude: current.latitude,
      longitude: current.longitude,
      method: current.calculationMethod,
      hanafi: current.hanafi,
    );
    prayers = await repository.prayerStatuses(selectedDate);
    habits = (await repository.habits())
        .map(
          (row) => Habit(id: row['id']! as int, name: row['name']! as String),
        )
        .toList();
    todayHabits = await repository.habitStatuses(selectedDate);
    weekHabits = await repository.habitWeek(selectedDate);
    family = await repository.familyMembers();
    familyPrayers = {
      for (final member in family)
        member.id: await repository.familyPrayerStatus(selectedDate, member.id),
    };
  }

  Future<PrayerAward> togglePrayer(Prayer prayer) async {
    final award = await repository.togglePrayer(selectedDate, prayer);
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
    return award;
  }

  Future<HabitAward> setHabitStatus(int id, HabitStatus status) async {
    final award = await repository.setHabitStatus(selectedDate, id, status);
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
    return award;
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate = DateTime(date.year, date.month, date.day);
    await refresh();
    notifyListeners();
  }

  Future<void> changeMonth(int delta) async {
    final next = DateTime(selectedDate.year, selectedDate.month + delta, 1);
    await selectDate(DateTime(next.year, next.month, 1));
  }

  Future<void> addHabit(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await repository.addHabit(clean);
    await refresh();
    notifyListeners();
  }

  Future<void> removeHabit(int id) async {
    await repository.removeHabit(id);
    await refresh();
    notifyListeners();
  }

  Future<void> updateName(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    await repository.updateSettings(name: clean);
    settings = await repository.loadSettings();
    notifyListeners();
  }

  Future<void> updateCalculation({String? method, bool? hanafi}) async {
    await repository.updateSettings(calculationMethod: method, hanafi: hanafi);
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
  }

  Future<void> updateCoordinates({
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    await repository.updateSettings(
      locationName: label,
      latitude: latitude,
      longitude: longitude,
    );
    settings = await repository.loadSettings();
    await refresh();
    notifyListeners();
  }

  Future<void> useDeviceLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Standortdienste sind ausgeschaltet.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Standortzugriff wurde nicht erlaubt. Du kannst Koordinaten manuell eingeben.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    await updateCoordinates(
      label: 'Mein Standort',
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> addFamilyMember(String name) async {
    if (name.trim().isEmpty) return;
    await repository.addFamilyMember(name);
    await refresh();
    notifyListeners();
  }

  Future<void> toggleFamilyPrayer(
    int memberId,
    Prayer prayer,
    bool done,
  ) async {
    await repository.setFamilyPrayer(selectedDate, memberId, prayer, done);
    await refresh();
    notifyListeners();
  }

  Future<void> close() => repository.close();
}

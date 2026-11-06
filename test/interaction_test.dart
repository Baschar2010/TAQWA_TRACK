import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa_track/admin_feedback.dart';
import 'package:taqwa_track/app_info.dart';
import 'package:taqwa_track/widgets/compass_widget.dart';

/// Interaktions-Tests fuer Bereiche, die in der Haupt-Suite noch nicht
/// abgedeckt sind: Qibla-Kompass (Kalibrieren-Button), Admin-Login
/// (Ersteinrichtung, Anmelden, Passwort vergessen), Feedback-Dashboard
/// (Zusammenfassung kopieren, Reset-Anfrage freigeben), Notfall-Reset
/// sowie Admin-Verwaltung (Anlegen, Passwort zuruecksetzen,
/// Loesch-Schutz des Haupt-Admins, Konto loeschen).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // --- Helper ------------------------------------------------------

  /// Mockt path_provider auf ein temporaeres Verzeichnis.
  Future<Directory> mockStorageDir() async {
    final dir = await Directory.systemTemp.createTemp('taqwa_itest');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        if (call.method.endsWith('Directory')) return dir.path;
        return null;
      },
    );
    return dir;
  }

  void unmockStorage() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  }

  /// Laesst ggf. aktive SnackBar-Timer ablaufen.
  Future<void> drainSnack(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4600));
  }

  /// Entladet die Widgetstruktur und raumt Speicher auf.
  Future<void> teardown(WidgetTester tester, Directory? dir) async {
    unmockStorage();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    dir?.deleteSync(recursive: true);
    await AdminStorage.clear();
    await FeedbackStorage.clear();
    await ResetRequestStorage.clear();
  }

  Future<void> pumpAdminScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminFeedbackScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Anmeldet den Haupt-Admin 'Baschar' mit Passwort [password] im
  /// bereits gepumpten Login-Screen.
  Future<void> loginAsMain(WidgetTester tester, String password) async {
    await tester.enterText(find.byType(TextField).at(0), 'Baschar');
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.text('Anmelden'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // --- Pure Logik --------------------------------------------------

  test('FeedbackEntry serialisiert verlustfrei und toleriert Leerdaten', () {
    final entry = FeedbackEntry(
      rating: 4,
      message: 'Sehr gut',
      name: 'Khadija',
      createdAt: DateTime(2026, 11, 3, 9, 30),
    );
    final restored = FeedbackEntry.fromJson(entry.toJson());
    expect(restored.rating, 4);
    expect(restored.message, 'Sehr gut');
    expect(restored.name, 'Khadija');
    expect(restored.createdAt, DateTime(2026, 11, 3, 9, 30));

    final empty = FeedbackEntry.fromJson(const {});
    expect(empty.rating, 0);
    expect(empty.message, '');
    expect(empty.name, '');
  });

  test('AdminAccount serialisiert und Passwort-Hash ist stabil', () {
    final account = AdminAccount(
      name: 'Baschar',
      passwordHash: 'abc',
      isMain: true,
    );
    final restored = AdminAccount.fromJson(account.toJson());
    expect(restored.name, 'Baschar');
    expect(restored.passwordHash, 'abc');
    expect(restored.isMain, isTrue);

    final hash = hashPassword('Taqwa 2026');
    expect(hash.length, 64);
    expect(hash, hashPassword('Taqwa 2026'));
    expect(hash, isNot(hashPassword('taqwa 2026')));
  });

  test('ResetRequest serialisiert', () {
    final req = ResetRequest(
      name: 'Ali',
      createdAt: DateTime(2026, 11, 2, 18),
    );
    final restored = ResetRequest.fromJson(req.toJson());
    expect(restored.name, 'Ali');
    expect(restored.createdAt, DateTime(2026, 11, 2, 18));
  });

  // --- Admin-Storage ----------------------------------------------

  test('AdminStorage speichert, findet und loescht '
      '(unabhaengig von Gross-/Kleinschreibung)', () async {
    final dir = await mockStorageDir();
    await AdminStorage.upsert(
      AdminAccount(name: 'Baschar', passwordHash: 'h1', isMain: true),
    );
    await AdminStorage.upsert(
      AdminAccount(name: 'Omar', passwordHash: 'h2', isMain: false),
    );

    var found = await AdminStorage.find('baschar');
    expect(found, isNotNull);
    expect(found!.isMain, isTrue);
    found = await AdminStorage.find('OMAR');
    expect(found, isNotNull);
    expect(found!.isMain, isFalse);
    expect(await AdminStorage.find('Unbekannt'), isNull);

    // Upsert aktualisiert statt zu duplizieren.
    await AdminStorage.upsert(
      AdminAccount(name: 'Omar', passwordHash: 'h3', isMain: false),
    );
    final list = await AdminStorage.load();
    expect(list.length, 2);
    expect(list.singleWhere((a) => a.name == 'Omar').passwordHash, 'h3');

    await AdminStorage.remove('Omar');
    expect((await AdminStorage.load()).length, 1);

    unmockStorage();
    dir.deleteSync(recursive: true);
    await AdminStorage.clear();
  });

  test('ResetRequestStorage haelt nur eine Anfrage pro Name', () async {
    final dir = await mockStorageDir();
    await ResetRequestStorage.add('Ali');
    await ResetRequestStorage.add('Ali');
    await ResetRequestStorage.add('Fatima');
    var reqs = await ResetRequestStorage.load();
    expect(reqs.length, 2);

    await ResetRequestStorage.remove('Ali');
    reqs = await ResetRequestStorage.load();
    expect(reqs.length, 1);
    expect(reqs.single.name, 'Fatima');

    unmockStorage();
    dir.deleteSync(recursive: true);
    await ResetRequestStorage.clear();
  });

  // --- Kompass ----------------------------------------------------

  testWidgets('Kompass: Sensor-Hinweis erscheint, Kalibrieren-Button '
      'zeigt SnackBar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: CompassWidget(latitude: 51.4344, longitude: 6.7623),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Sensor-Timeout (3 s) abwarten: ohne Sensor-Backend gibt es keinen
    // Kompass-Puls und der Fehlertext erscheint.
    await tester.pump(const Duration(seconds: 3, milliseconds: 200));

    expect(find.text('Kompass wird gesucht …'), findsOneWidget);
    expect(
      find.text(
        'Kein Kompass-Sensor gefunden – die Richtung oben gilt trotzdem.',
      ),
      findsOneWidget,
    );
    expect(find.text('Kompass kalibrieren'), findsOneWidget);

    await tester.tap(find.text('Kompass kalibrieren'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kompass wird neu kalibriert …'), findsOneWidget);

    await drainSnack(tester);
    await teardown(tester, null);
  });

  // --- Admin-Login: Ersteinrichtung --------------------------------

  testWidgets('Ersteinrichtung: kurzes Passwort, Nicht-uebereinstimmung '
      'und Erfolg bis zum Dashboard', (tester) async {
    final dir = await mockStorageDir();
    await pumpAdminScreen(tester);

    expect(find.text('ERSTEINRICHTUNG'), findsOneWidget);

    // 1. Zu kurzes Passwort.
    await tester.enterText(find.byType(TextField).at(0), 'Ab1');
    await tester.enterText(find.byType(TextField).at(1), 'Ab1');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pump();
    expect(
      find.text('Passwort muss mindestens 4 Zeichen haben.'),
      findsOneWidget,
    );
    await drainSnack(tester);

    // 2. Passwoerter stimmen nicht ueberein.
    await tester.enterText(find.byType(TextField).at(0), 'GQ2026');
    await tester.enterText(find.byType(TextField).at(1), 'GQ2027');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pump();
    expect(find.text('Passwörter stimmen nicht überein.'), findsOneWidget);
    await drainSnack(tester);

    // 3. Gueltiges Passwort: Dashboard wird erreicht.
    await tester.enterText(find.byType(TextField).at(0), 'GQ2026');
    await tester.enterText(find.byType(TextField).at(1), 'GQ2026');
    await tester.tap(find.text('Passwort speichern'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('0 FEEDBACK(S) · Baschar'), findsOneWidget);
    expect(find.text('Feedbacks zusammenfassen'), findsOneWidget);

    await teardown(tester, dir);
  });

  // --- Notfall-Reset am Login-Screen -------------------------------

  testWidgets('Login-Screen: Notfall-Reset via Langdruck loescht '
      'alle Admin-Konten', (tester) async {
    final dir = await mockStorageDir();
    await AdminStorage.upsert(
      AdminAccount(
        name: 'Baschar',
        passwordHash: hashPassword('GQ2026'),
        isMain: true,
      ),
    );

    await pumpAdminScreen(tester);
    expect(find.text('ANMELDUNG'), findsOneWidget);

    await tester.longPress(
      find.text('Version $appVersion · Build $appBuild'),
    );
    await tester.pump();
    expect(find.text('Notfall-Reset'), findsOneWidget);

    // Abbrechen entfernt nichts.
    await tester.tap(find.text('Abbrechen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ANMELDUNG'), findsOneWidget);
    expect(await AdminStorage.find('Baschar'), isNotNull);

    await tester.longPress(
      find.text('Version $appVersion · Build $appBuild'),
    );
    await tester.pump();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ERSTEINRICHTUNG'), findsOneWidget);
    expect(await AdminStorage.load(), isEmpty);

    await drainSnack(tester);
    await teardown(tester, dir);
  });

  // --- Admin-Login: Anmelden + Passwort vergessen -------------------

  testWidgets('Login: falsche Daten werden abgelehnt, korrekte oeffnen; '
      'Vergessen-Link validiert den Namen', (tester) async {
    final dir = await mockStorageDir();
    await AdminStorage.upsert(
      AdminAccount(
        name: 'Baschar',
        passwordHash: hashPassword('GQ2026'),
        isMain: true,
      ),
    );
    await ResetRequestStorage.add('Ali');
    await pumpAdminScreen(tester);

    // Unbekannter Admin beim Vergessen-Link.
    await tester.enterText(find.byType(TextField).at(0), 'Mysterium');
    await tester.tap(find.text('Passwort vergessen?'));
    await tester.pump();
    expect(find.text('Admin nicht gefunden.'), findsOneWidget);
    await drainSnack(tester);

    // Leerer Name beim Vergessen-Link.
    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.tap(find.text('Passwort vergessen?'));
    await tester.pump();
    expect(
      find.text('Bitte zuerst den Admin-Namen eingeben.'),
      findsOneWidget,
    );
    await drainSnack(tester);

    // Falsches Passwort beim Login.
    await tester.enterText(find.byType(TextField).at(0), 'Baschar');
    await tester.enterText(find.byType(TextField).at(1), 'falsch');
    await tester.tap(find.text('Anmelden'));
    await tester.pump();
    expect(find.text('Ungültige Anmeldedaten.'), findsOneWidget);
    await drainSnack(tester);

    // Korrektes Passwort: Dashboard mit Feedback + offene Reset-Anfrage.
    await loginAsMain(tester, 'GQ2026');
    expect(find.text('PASSWORT-RESET-ANFRAGEN'), findsOneWidget);
    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Noch keine Feedbacks vorhanden.'), findsOneWidget);

    await drainSnack(tester);
    await teardown(tester, dir);
  });

  // --- Dashboard: Zusammenfassung + Reset-Anfragen-Freigabe ---------

  testWidgets('Dashboard: Zusammenfassung kopieren und Reset-Anfrage '
      'freigeben', (tester) async {
    final dir = await mockStorageDir();
    await AdminStorage.upsert(
      AdminAccount(
        name: 'Baschar',
        passwordHash: hashPassword('GQ2026'),
        isMain: true,
      ),
    );
    await FeedbackStorage.save(
      FeedbackEntry(rating: 5, message: 'MashaAllah', name: 'Khadija'),
    );
    await ResetRequestStorage.add('Fatima');

    await pumpAdminScreen(tester);
    await loginAsMain(tester, 'GQ2026');

    expect(find.text('1 FEEDBACK(S) · Baschar'), findsOneWidget);
    expect(find.text('MashaAllah'), findsOneWidget);

    // Feedback-Zusammenfassung in die Zwischenablage.
    await tester.tap(find.text('Feedbacks zusammenfassen'));
    await tester.pump();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clip!.text, startsWith('TAQWA TRACK – Feedback-Zusammenfassung'));
    expect(clip.text, contains('Khadija'));

    // Reset-Anfrage freigeben: Eintrag verschwindet.
    await tester.ensureVisible(find.text('Freigeben'));
    await tester.pump();
    await tester.tap(find.text('Freigeben'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await ResetRequestStorage.load(), isEmpty);

    await drainSnack(tester);
    await teardown(tester, dir);
  });

  // --- Admin-Verwaltung --------------------------------------------

  testWidgets('Admin-Verwaltung: anlegen, Passwort zuruecksetzen, '
      'Loesch-Schutz des Haupt-Admins, Sub-Admin loeschen',
      (tester) async {
    final dir = await mockStorageDir();
    await AdminStorage.upsert(
      AdminAccount(
        name: 'Baschar',
        passwordHash: hashPassword('GQ2026'),
        isMain: true,
      ),
    );

    await pumpAdminScreen(tester);
    await loginAsMain(tester, 'GQ2026');

    // Verwaltung oeffnen.
    await tester.tap(find.byIcon(Icons.admin_panel_settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ADMIN-KONTEN'), findsOneWidget);
    expect(find.text('Haupt-Admin'), findsOneWidget);

    // 1. Neuen Admin anlegen.
    await tester.tap(find.text('Hinzufügen'));
    await tester.pump();
    expect(find.text('Neuen Admin anlegen'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Omar');
    // Zu kurzes Passwort: Dialog bleibt offen.
    await tester.enterText(find.byType(TextField).at(1), 'xy1');
    await tester.tap(find.text('Anlegen'));
    await tester.pump();
    // Nun gueltig.
    await tester.enterText(find.byType(TextField).at(1), 'passw1');
    await tester.tap(find.text('Anlegen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Omar'), findsOneWidget);
    expect(
      (await AdminStorage.find('Omar'))!.passwordHash,
      hashPassword('passw1'),
    );
    await drainSnack(tester);

    // 2. Passwort zuruecksetzen.
    await tester.tap(find.byIcon(Icons.key).last);
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'neu5678');
    await tester.tap(find.text('Zurücksetzen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      (await AdminStorage.find('Omar'))!.passwordHash,
      hashPassword('neu5678'),
    );
    await drainSnack(tester);

    // 3. Haupt-Admin-Loeschung braucht exakte Namensbestaetigung.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect(find.text('Haupt-Admin löschen?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Baxchar');
    await tester.tap(find.text('Endgültig löschen'));
    await tester.pump();
    expect(find.text('Bestätigung fehlgeschlagen.'), findsOneWidget);
    expect(await AdminStorage.find('Baschar'), isNotNull);
    await drainSnack(tester);

    // 4. Sub-Admin-Konto loeschen.
    final deleteButtons = find.byIcon(Icons.delete_outline);
    expect(deleteButtons, findsNWidgets(2));
    await tester.tap(deleteButtons.at(1));
    await tester.pump();
    expect(find.text('Konto „Omar“ löschen?'), findsOneWidget);
    await tester.tap(find.text('Konto löschen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await AdminStorage.find('Omar'), isNull);
    expect(await AdminStorage.find('Baschar'), isNotNull);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await drainSnack(tester);
    await teardown(tester, dir);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa_track/app_info.dart';
import 'package:taqwa_track/feedback_screen.dart';
import 'package:taqwa_track/update_service.dart';

void main() {
  group('Versionsvergleich', () {
    test('normalisiert Tags und Build-Suffixe', () {
      expect(normalizeVersion('v1.6.0'), '1.6.0');
      expect(normalizeVersion('V1.6.0'), '1.6.0');
      expect(normalizeVersion(' 1.6.0+9 '), '1.6.0');
      expect(normalizeVersion('v1.6.0-rc1'), '1.6.0');
      expect(normalizeVersion('release-1.6'), isNull);
      expect(normalizeVersion(''), isNull);
    });

    test('erkennt neuere, gleiche und ältere Versionen', () {
      expect(compareVersions('1.6.0', '1.5.0'), greaterThan(0));
      expect(compareVersions('1.5.0', '1.6.0'), lessThan(0));
      expect(compareVersions('v1.6.0', '1.6'), 0);
      expect(compareVersions('1.6.0+9', '1.6.0'), 0);
      expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('2.0', '1.99.99'), greaterThan(0));
    });
  });

  group('ReleaseInfo', () {
    test('liest Tag, APK-Link und Notizen aus der GitHub-Antwort', () {
      final release = ReleaseInfo.fromGitHub({
        'tag_name': 'v1.6.0',
        'html_url':
            'https://github.com/Baschar2010/TAQWA_TRACK/releases/tag/v1.6.0',
        'body': '## Neu\n- Update-Check\n- Feedback',
        'assets': [
          {
            'name': 'TAQWA_TRACK_v1.6.0.apk',
            'browser_download_url': 'https://example.com/app.apk',
          },
        ],
      });
      expect(release, isNotNull);
      expect(release!.version, '1.6.0');
      expect(release.tag, 'v1.6.0');
      expect(release.apkUrl, 'https://example.com/app.apk');
      expect(release.notes, contains('Update-Check'));
    });

    test('fällt ohne APK auf die Release-Seite zurück', () {
      final release = ReleaseInfo.fromGitHub({
        'tag_name': '1.6.0',
        'html_url':
            'https://github.com/Baschar2010/TAQWA_TRACK/releases/tag/v1.6.0',
        'assets': <Object>[],
      });
      expect(release!.apkUrl, release.pageUrl);
    });

    test('ignoriert kaputte Antworten', () {
      expect(ReleaseInfo.fromGitHub(null), isNull);
      expect(ReleaseInfo.fromGitHub('text'), isNull);
      expect(ReleaseInfo.fromGitHub(<String, Object?>{}), isNull);
      expect(ReleaseInfo.fromGitHub({'tag_name': 'keine-version'}), isNull);
      expect(
        ReleaseInfo.fromGitHub({'tag_name': 'v1.6.0', 'assets': 'x'}),
        isNotNull,
      );
    });
  });

  group('UpdateService', () {
    ReleaseInfo release(String version) => ReleaseInfo(
      version: version,
      tag: 'v$version',
      apkUrl: 'https://example.com/$version.apk',
      pageUrl: 'https://example.com/$version',
    );

    test('meldet nur eine echt neuere Version', () async {
      final service = UpdateService(
        currentVersion: '1.5.0',
        fetchLatest: () async => release('1.6.0'),
      );
      final found = await service.check();
      expect(found?.version, '1.6.0');
    });

    test('schweigt bei gleicher oder älterer Version', () async {
      final same = UpdateService(
        currentVersion: '1.6.0',
        fetchLatest: () async => release('1.6.0'),
      );
      final older = UpdateService(
        currentVersion: '1.6.0',
        fetchLatest: () async => release('1.5.9'),
      );
      expect(await same.check(), isNull);
      expect(await older.check(), isNull);
    });

    test('bleibt offline still', () async {
      final offline = UpdateService(
        fetchLatest: () async => throw const FormatException('offline'),
      );
      final empty = UpdateService(fetchLatest: () async => null);
      expect(await offline.check(), isNull);
      expect(await empty.check(), isNull);
    });
  });

  group('Feedback', () {
    test('baut eine vollständige E-Mail mit Sternen', () {
      const draft = FeedbackDraft(
        rating: 4,
        name: 'Bilal',
        message: 'Die Quran-Ansicht ist sehr schön.',
      );
      final body = feedbackMailBody(draft);
      expect(body, contains('★★★★☆ (4/5)'));
      expect(body, contains('Bilal'));
      expect(body, contains(appVersion));
      expect(body, contains('Die Quran-Ansicht ist sehr schön.'));
      expect(feedbackSubject(draft), contains('4/5'));
    });

    test('kommt ohne Namen und ohne Nachricht zurecht', () {
      const draft = FeedbackDraft(rating: 0, message: '   ');
      final body = feedbackMailBody(draft);
      expect(body, contains('Keine Sterne vergeben'));
      expect(body, contains('(keine Nachricht)'));
      expect(body, isNot(contains('Von:')));
      expect(feedbackSubject(draft), 'TAQWA TRACK Feedback');
      expect(draft.isEmpty, isTrue);
    });

    test('kodiert die mailto-Adresse korrekt', () {
      const draft = FeedbackDraft(rating: 5, message: 'Sehr gut & gerne mehr');
      final uri = feedbackMailUri(draft);
      expect(uri.scheme, 'mailto');
      expect(uri.path, supportEmail);
      expect(uri.query, contains('subject='));
      expect(uri.query, contains('body='));
      expect(
        Uri.decodeQueryComponent(uri.query),
        contains('Sehr gut & gerne mehr'),
      );
    });
  });
}

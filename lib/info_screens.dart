import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

const supportEmail = 'alsafdibaschar5@gmail.com';

/// Öffnet das E-Mail-Programm mit einer vorbereiteten Nachricht.
Future<void> contactSupport(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: 'subject=TAQWA TRACK – Feedback',
  );
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-Mail-Adresse kopiert: $supportEmail'),
          ),
        );
      }
    }
  } catch (_) {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail-Adresse kopiert: $supportEmail')),
      );
    }
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Datenschutz', style: TextStyle(fontSize: 15)),
      centerTitle: true,
    ),
    body: StarField(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const TaqwaCard(
              goldBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('DATENSCHUTZERKLÄRUNG', color: TaqwaColors.gold),
                  SizedBox(height: 6),
                  Text(
                    'TAQWA TRACK',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Stand: Januar 2026 · Version 1.4.0',
                    style: TextStyle(color: TaqwaColors.muted, fontSize: 9),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Diese Erklärung beschreibt, welche Daten TAQWA TRACK '
                    'verarbeitet. Kurzfassung: Alle persönlichen Daten bleiben '
                    'ausschließlich auf deinem Gerät. Es gibt keine Cloud, kein '
                    'Konto, keine Werbung und kein Tracking.',
                    style: TextStyle(fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const _LegalSection(
              number: '1',
              title: 'Verantwortlicher',
              body:
                  'Verantwortlich für diese App ist der Entwickler von '
                  'TAQWA TRACK. Kontakt für Datenschutzanfragen: '
                  '$supportEmail.',
            ),
            const _LegalSection(
              number: '2',
              title: 'Grundsatz der Datenminimierung',
              body:
                  'TAQWA TRACK wurde als Offline-First-Anwendung entwickelt. '
                  'Es werden keine Benutzerkonten angelegt und keine '
                  'personenbezogenen Daten an Server übertragen. Die App '
                  'funktioniert vollständig ohne Internetverbindung.',
            ),
            const _LegalSection(
              number: '3',
              title: 'Lokal gespeicherte Daten',
              body:
                  'Auf deinem Gerät werden ausschließlich die Daten gespeichert, '
                  'die für die Funktion der App erforderlich sind:\n\n'
                  '• Name und gewählte Sprache\n'
                  '• Gebetsstatus, Habits, XP, Streak und Gold-Status\n'
                  '• Quran-Lesezeichen und zuletzt gelesene Ayah\n'
                  '• Tasbih-Zähler und App-Einstellungen\n'
                  '• gekoppelte Familienprofile (Name, Fortschritt, '
                  'Kopplungscode)\n'
                  '• Standortkoordinaten für die Gebetszeitberechnung\n\n'
                  'Diese Daten verlassen dein Gerät nicht. Ein Backup kann '
                  'ausschließlich über die Android-Systemfunktionen erfolgen.',
            ),
            const _LegalSection(
              number: '4',
              title: 'Berechtigungen',
              body:
                  'Die App fragt nur Berechtigungen an, die für die jeweilige '
                  'Funktion nötig sind:\n\n'
                  '• Kamera – ausschließlich zum Scannen von TAQWA-TRACK-'
                  'QR-Codes. Es werden keine Fotos gespeichert oder '
                  'übertragen.\n'
                  '• Benachrichtigungen – für Gebets-Erinnerungen und '
                  'Partner-Hinweise.\n'
                  '• Standort – optional, zur lokalen Berechnung der '
                  'Gebetszeiten. Du kannst Koordinaten auch manuell eingeben.\n'
                  '• Vibration – für das Tasbih-Feedback.\n\n'
                  'Berechtigungen können jederzeit in den Android-Einstellungen '
                  'entzogen werden.',
            ),
            const _LegalSection(
              number: '5',
              title: 'Keine Weitergabe und kein Tracking',
              body:
                  'Es werden keine Analyse-, Werbe- oder Crash-Reporting-Dienste '
                  'eingesetzt. Es findet keine Übermittlung an Dritte statt. '
                  'Die App enthält keine In-App-Käufe und keine sozialen '
                  'Netzwerke.',
            ),
            const _LegalSection(
              number: '6',
              title: 'Familien-Kopplung per QR-Code',
              body:
                  'Die Kopplung erfolgt ausschließlich direkt zwischen zwei '
                  'Geräten. Der QR-Code enthält den Anzeigenamen, den '
                  'Fortschritt des aktuellen Tages und optional eine '
                  'Erinnerungsnachricht. Er wird nur von der Kamera des '
                  'gegenüberliegenden Geräts gelesen und nicht an Server '
                  'gesendet.',
            ),
            const _LegalSection(
              number: '7',
              title: 'Speicherdauer und Löschung',
              body:
                  'Alle Daten bleiben so lange gespeichert, wie die App '
                  'installiert ist. Durch Löschen der App-Daten oder '
                  'Deinstallieren der App werden alle lokalen Daten '
                  'unwiderruflich entfernt. Kopplungen können jederzeit im '
                  'Family-Tab gelöst werden.',
            ),
            const _LegalSection(
              number: '8',
              title: 'Kinder und Jugendschutz',
              body:
                  'Die App richtet sich an alle Altersgruppen und erhebt keine '
                  'Daten von Kindern. Es gibt keine Werbung und keine '
                  'Chat-Funktionen mit Fremden.',
            ),
            const _LegalSection(
              number: '9',
              title: 'Religiöse Inhalte',
              body:
                  'Gebetszeiten werden lokal mit der Adhan-Bibliothek '
                  'berechnet. Quran-Text, Übersetzung und Hadithe sind '
                  'offline gespeicherte Inhalte. Für verbindliche religiöse '
                  'Aussagen wende dich bitte an eine qualifizierte Stelle.',
            ),
            const _LegalSection(
              number: '10',
              title: 'Änderungen dieser Erklärung',
              body:
                  'Bei neuen Funktionen kann diese Erklärung aktualisiert '
                  'werden. Die jeweils gültige Fassung ist in der App unter '
                  'Profil → Datenschutz abrufbar. Es gilt die dort angegebene '
                  'Version.',
            ),
            const _LegalSection(
              number: '11',
              title: 'Deine Rechte',
              body:
                  'Da keine personenbezogenen Daten an uns übertragen werden, '
                  'können wir keine Auskunft über gespeicherte Daten erteilen – '
                  'wir besitzen keine. Du behältst die volle Kontrolle über '
                  'deine lokalen Daten und kannst sie jederzeit selbst löschen. '
                  'Bei Fragen erreichst du uns unter $supportEmail.',
            ),
            const SizedBox(height: 4),
            TaqwaCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: TaqwaColors.gold,
                ),
                title: const Text(
                  'Datenschutz-Kontakt',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  supportEmail,
                  style: TextStyle(fontSize: 9, color: TaqwaColors.muted),
                ),
                trailing: const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: TaqwaColors.goldLight,
                ),
                onTap: () => contactSupport(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TaqwaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF231B0D),
                  border: Border.all(color: TaqwaColors.gold),
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: TaqwaColors.goldLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: const TextStyle(
              color: TaqwaColors.muted,
              fontSize: 10,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FaqEntry {
  const _FaqEntry(this.question, this.answer);
  final String question;
  final String answer;
}

const _faqs = <_FaqEntry>[
  _FaqEntry(
    'Funktioniert TAQWA TRACK ohne Internet?',
    'Ja. Gebetszeiten werden lokal berechnet, Quran, Hadithe und Audio sind '
        'in der App gespeichert. Nur Android-Systemdienste (z. B. '
        'Zeitzone) können beim ersten Start kurz online sein.',
  ),
  _FaqEntry(
    'Wie verbinde ich mich mit meiner Familie?',
    'Öffne den Family-Tab. Dort siehst du deinen persönlichen QR-Code. '
        'Tippe auf „QR-Code scannen“ und scanne den Code des anderen Geräts. '
        'Danach seht ihr euren Tagesfortschritt gegenseitig. Für einen '
        'aktuellen Stand scannt ihr euch erneut – es gibt keinen Server.',
  ),
  _FaqEntry(
    'Warum kommt keine Gebets-Erinnerung an?',
    'Prüfe in den Android-Einstellungen, ob Benachrichtigungen für TAQWA '
        'TRACK erlaubt sind und ob die App von der Akku-Optimierung '
        'ausgenommen ist. Aktiviere Erinnerungen anschließend erneut unter '
        'Profil → Einstellungen → Benachrichtigungen.',
  ),
  _FaqEntry(
    'Warum höre ich nur bei wenigen Suren Audio?',
    'Die Rezitation ist offline eingebettet, damit keine Daten verbraucht '
        'werden. Aus Platzgründen sind die kurzen Suren 1, 112, 113 und 114 '
        'enthalten. Alle anderen Suren sind vollständig als Text lesbar.',
  ),
  _FaqEntry(
    'Woher stammen die Hadithe?',
    'Die Bibliothek enthält ausgewählte Hadithe aus Sahih al-Buchari, Sahih '
        'Muslim, Sunan Abi Dawud, Sunan at-Tirmidhi und Musnad Ahmad mit '
        'Quellenangabe. Sie ist offline durchsuchbar.',
  ),
  _FaqEntry(
    'Was bedeutet die Gold-Animation?',
    'Wenn du alle fünf Gebete eines Tages abhakst, springt dein Tagesstatus '
        'von Grün auf Gold. Die Animation erscheint einmal pro Tag. Dein '
        'Streak zählt aufeinanderfolgende vollständige Tage.',
  ),
  _FaqEntry(
    'Kann ich die Sprache später ändern?',
    'Ja, unter Profil → Einstellungen → Sprache. Die Auswahl wirkt sofort '
        'auf Navigation und Systemtexte.',
  ),
  _FaqEntry(
    'Werden meine Daten in die Cloud gespeichert?',
    'Nein. Es gibt kein Konto und keine Cloud. Alle Daten liegen in einer '
        'lokalen SQLite-Datenbank. Beim Deinstallieren werden sie gelöscht.',
  ),
  _FaqEntry(
    'Kann ich meine Daten sichern?',
    'Ein automatisches Cloud-Backup gibt es nicht. Du kannst ein '
        'Android-Gerätebackup nutzen. Ein manueller Export ist für eine '
        'spätere Version geplant.',
  ),
  _FaqEntry(
    'Was bringt der OLED-Modus?',
    'Er ersetzt das dunkelgraue Theme durch echtes Schwarz. Auf OLED-Displays '
        'spart das Akku und wirkt besonders kontrastreich.',
  ),
  _FaqEntry(
    'Ist der Quran-Text vollständig?',
    'Ja, alle 114 Suren mit arabischem Text und deutscher Übersetzung sind '
        'offline enthalten. Die Übersetzung ist eine verständliche '
        'Übertragung, kein exegetisches Werk.',
  ),
  _FaqEntry(
    'Wie lösche ich eine Familien-Kopplung?',
    'Im Family-Tab bei der Person auf das Drei-Punkte-Menü tippen und '
        '„Kopplung lösen“ wählen. Die Person wird sofort entfernt.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hilfe & Support', style: TextStyle(fontSize: 15)),
      centerTitle: true,
    ),
    body: StarField(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const TaqwaCard(
              goldBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow('WIR HELFEN GERNE', color: TaqwaColors.gold),
                  SizedBox(height: 5),
                  Text(
                    'Häufige Fragen',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Antworten zu Offline-Nutzung, Familie, Erinnerungen und '
                    'deinen Daten.',
                    style: TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final faq in _faqs) _FaqTile(faq: faq),
            const SizedBox(height: 6),
            TaqwaCard(
              goldBorder: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 18,
                        color: TaqwaColors.gold,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Noch Fragen?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Schreib uns direkt – Feedback, Fehler oder Wünsche '
                    'landen persönlich beim Entwickler.',
                    style: TextStyle(
                      color: TaqwaColors.muted,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => contactSupport(context),
                      icon: const Icon(Icons.mail_outline, size: 16),
                      label: const Text(
                        supportEmail,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: TaqwaColors.gold,
                        foregroundColor: const Color(0xFF17120A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'TAQWA TRACK · Version 1.4.0 · Offline-First',
                style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});
  final _FaqEntry faq;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: TaqwaCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            iconColor: TaqwaColors.gold,
            collapsedIconColor: TaqwaColors.muted,
            title: Text(
              faq.question,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.answer,
                  style: const TextStyle(
                    color: TaqwaColors.muted,
                    fontSize: 10,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

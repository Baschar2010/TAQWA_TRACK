# TAQWA_TRACK Release-Keystore

Persistenter Signierschluessel fuer Release-Builds (damit Updates ohne
Deinstallation installiert werden koennen).

- Keystore-Datei: `android/app/release.jks`
- Konfiguration: `android/key.properties` (gitignored)
- Alias: `taqwa_release`
- Store-Passwort: `TaqwaRelease2026`
- Key-Passwort: `TaqwaRelease2026`
- Gueltigkeit: 10000 Tage
- Algorithmus: RSA 2048

Bei einem neuen Rechner die Datei `release.jks` an denselben Pfad legen und
`key.properties` neu anlegen (siehe oben). Niemals den Keystore verlieren -
sonst koennen keine Updates mehr signiert werden.
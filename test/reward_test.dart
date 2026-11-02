import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa_track/reward.dart';
import 'package:taqwa_track/theme.dart';

void main() {
  test('Belohnungsstufe: neutral, grün ab eins, Gold erst bei allen', () {
    expect(dayTier(0, 5), DayTier.none);
    expect(dayTier(1, 5), DayTier.partial);
    expect(dayTier(4, 5), DayTier.partial);
    expect(dayTier(5, 5), DayTier.complete);
    // Keine Einheiten vorhanden: nichts zu feiern.
    expect(dayTier(0, 0), DayTier.none);
  });

  test('Farben: Grün für Teilfortschritt, #FFD700 für den Abschluss', () {
    TaqwaColors.use(darkPalette);
    expect(tierColor(DayTier.none), TaqwaColors.muted);
    expect(tierColor(DayTier.partial), TaqwaColors.green);
    expect(tierColor(DayTier.complete), rewardGold);
    expect(rewardGold.toARGB32(), 0xFFFFD700);
  });
}

import 'domain.dart';

/// Ergebnis einer Kopplung.
class LinkResult {
  const LinkResult({this.snapshot, this.mutual = false, this.reason});

  /// Der gescannte Partner, oder `null`, wenn der Code nicht gelesen wurde.
  final ProfileSnapshot? snapshot;

  /// `true`, wenn das Gegenüber im selben Moment ebenfalls verknüpft wurde.
  final bool mutual;

  /// Zusätzlicher Hinweis, falls die Gegenseite nicht erreichbar war.
  final String? reason;

  bool get linked => snapshot != null;
}

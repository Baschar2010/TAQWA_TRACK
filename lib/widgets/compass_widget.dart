import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../domain.dart';
import '../theme.dart';

/// Glättungsfaktor für den Tiefpass (Low-Pass) auf den Magnetometer-Wert.
const double kCompassAlpha = 0.15;

/// Qibla-Kompass mit Magnetometer (sensors_plus), Tiefpass-Glättung,
/// GPS-basierter Qibla-Berechnung.
class CompassWidget extends StatefulWidget {
  const CompassWidget({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<CompassWidget> {
  StreamSubscription<MagnetometerEvent>? _subscription;
  Timer? _sensorTimeout;

  double? _heading;
  bool _sensorMissing = false;
  double _qibla = 0;

  double? _filteredHeading;

  @override
  void initState() {
    super.initState();
    _qibla = qiblaBearing(widget.latitude, widget.longitude);
    _refreshPosition();
    _listen();
  }

  Future<void> _refreshPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _qibla = qiblaBearing(position.latitude, position.longitude);
      });
    } catch (_) {
      // GPS nicht verfügbar – Fallback auf übergebene Koordinaten.
    }
  }

  void _listen() {
    _sensorTimeout = Timer(const Duration(seconds: 3), () {
      if (mounted && _heading == null) {
        setState(() => _sensorMissing = true);
      }
    });
    try {
      _subscription = magnetometerEventStream().listen(
        (event) {
          if (!mounted) return;
          _sensorTimeout?.cancel();
          final rawHeading = _headingFromMagnetometer(event);
          final smoothed = _lowPass(rawHeading);
          setState(() {
            _heading = smoothed;
            _sensorMissing = false;
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _sensorMissing = true);
        },
        cancelOnError: false,
      );
    } on Object {
      if (mounted) setState(() => _sensorMissing = true);
    }
  }

  double _headingFromMagnetometer(MagnetometerEvent e) {
    var degrees = math.atan2(e.y, e.x) * 180 / math.pi;
    if (degrees < 0) degrees += 360;
    return degrees;
  }

  double _lowPass(double value) {
    final previous = _filteredHeading;
    if (previous == null) {
      _filteredHeading = value;
      return value;
    }
    // kürzester Weg um den Kreis
    var delta = value - previous;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    final next = (previous + delta * kCompassAlpha + 360) % 360;
    _filteredHeading = next;
    return next;
  }

  @override
  void dispose() {
    _sensorTimeout?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final aligned =
        heading != null && _angleDelta(_qibla, heading).abs() <= 5;
    return Column(
      children: [
        Semantics(
          label: heading == null
              ? 'Qibla-Kompass, Sensor wird gesucht'
              : 'Qibla-Kompass, Kaaba bei ${_qibla.round()} Grad, '
                    'Gerät bei ${heading.round()} Grad',
          child: SizedBox(
            width: 244,
            height: 244,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -((heading ?? 0) * math.pi / 180),
                  child: CustomPaint(
                    size: const Size.square(244),
                    painter: _CompassDialPainter(aligned: aligned),
                  ),
                ),
                Transform.rotate(
                  angle: (_qibla - (heading ?? 0)) * math.pi / 180,
                  child: CustomPaint(
                    size: const Size.square(244),
                    painter: _QiblaNeedlePainter(aligned: aligned),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TaqwaColors.panel,
                    border: Border.all(
                      color: aligned ? TaqwaColors.green : TaqwaColors.gold,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_qibla.round()}°',
                      style: TextStyle(
                        color: TaqwaColors.goldLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            heading == null
                ? 'Kompass wird gesucht …'
                : aligned
                    ? 'Ausgerichtet – du blickst zur Kaaba'
                    : 'Handy flach halten, bis der Pfeil nach oben zeigt',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: aligned ? FontWeight.w700 : FontWeight.w500,
              color: aligned ? TaqwaColors.green : TaqwaColors.goldLight,
            ),
          ),
        ),
        if (heading == null && _sensorMissing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: Text(
                'Kein Kompass-Sensor gefunden – die Richtung oben gilt trotzdem.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TaqwaColors.muted, fontSize: 8),
              ),
            ),
          ),
      ],
    );
  }
}

double _angleDelta(double a, double b) {
  final diff = (a - b) % 360;
  return diff > 180 ? diff - 360 : diff;
}

class _CompassDialPainter extends CustomPainter {
  _CompassDialPainter({required this.aligned});
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius - 1, Paint()..color = TaqwaColors.card);
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = aligned ? TaqwaColors.green : TaqwaColors.border,
    );
    canvas.drawCircle(
      center,
      radius - 26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = TaqwaColors.border,
    );
    final tick = Paint()
      ..strokeWidth = 1
      ..color = TaqwaColors.mutedStrong;
    final strong = Paint()
      ..strokeWidth = 1.8
      ..color = TaqwaColors.gold;
    for (var degrees = 0; degrees < 360; degrees += 15) {
      final rad = (degrees - 90) * math.pi / 180;
      final major = degrees % 90 == 0;
      final length = major ? 12.0 : 6.0;
      final outer = Offset(
        center.dx + math.cos(rad) * (radius - 8),
        center.dy + math.sin(rad) * (radius - 8),
      );
      final inner = Offset(
        center.dx + math.cos(rad) * (radius - 8 - length),
        center.dy + math.sin(rad) * (radius - 8 - length),
      );
      canvas.drawLine(outer, inner, major ? strong : tick);
    }
    const labels = {0: 'N', 90: 'O', 180: 'S', 270: 'W'};
    labels.forEach((degrees, label) {
      final rad = (degrees - 90) * math.pi / 180;
      final position = Offset(
        center.dx + math.cos(rad) * (radius - 42),
        center.dy + math.sin(rad) * (radius - 42),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: degrees == 0 ? TaqwaColors.gold : TaqwaColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.aligned != aligned;
}

class _QiblaNeedlePainter extends CustomPainter {
  _QiblaNeedlePainter({required this.aligned});
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final color = aligned ? TaqwaColors.green : TaqwaColors.gold;
    final tip = center - Offset(0, radius - 28);
    final left = center + Offset(-10, -radius + 78);
    final right = center + Offset(10, -radius + 78);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TaqwaColors.chip,
    );
  }

  @override
  bool shouldRepaint(covariant _QiblaNeedlePainter oldDelegate) =>
      oldDelegate.aligned != aligned;
}

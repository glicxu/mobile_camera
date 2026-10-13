import 'situations.dart';
import 'models.dart';

/// Smoothed, hysteretic measurements for the persistent Landscape instruments.
class LandscapeInstrumentState {
  final _horizon = _StableAttention();
  final _stability = _StableAttention();
  final _exposure = _StableAttention();

  double horizonAngle = 0;
  double exposurePosition = 0;

  bool get horizonAvailable => _horizon.available;
  bool get horizonNeedsAttention => _horizon.attention;
  bool get horizonSevere => horizonNeedsAttention && horizonAngle.abs() >= 8;
  bool get stabilityAvailable => _stability.available;
  bool get stabilityNeedsAttention => _stability.attention;
  bool get exposureAvailable => _exposure.available;
  bool get exposureNeedsAttention => _exposure.attention;

  void reset() {
    _horizon.reset();
    _stability.reset();
    _exposure.reset();
    horizonAngle = 0;
    exposurePosition = 0;
  }

  void update(
    SituationSignals signals, {
    double? backgroundLuminance,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    final measuredAngle =
        signals.horizon?.angleDegrees ?? signals.motion?.rollDegrees;
    if (measuredAngle != null) {
      horizonAngle = _smooth(horizonAngle, measuredAngle, _horizon.available);
      final magnitude = horizonAngle.abs();
      _horizon.update(
        _horizon.attention ? magnitude > 1.5 : magnitude >= 3,
        now,
      );
    }

    final motion = signals.motion?.magnitude;
    if (motion != null) {
      _stability.update(
        _stability.attention ? motion > .14 : motion >= .22,
        now,
      );
    }

    if (backgroundLuminance != null) {
      final measured = ((backgroundLuminance - 128) / 100).clamp(-1.0, 1.0);
      exposurePosition = _smooth(
        exposurePosition,
        measured,
        _exposure.available,
      );
      final tooDark = backgroundLuminance < (_exposure.attention ? 75 : 55);
      final tooBright = backgroundLuminance > (_exposure.attention ? 180 : 200);
      _exposure.update(tooDark || tooBright, now);
    }
  }

  static double _smooth(double old, double next, bool hasOld) =>
      hasOld ? old * .75 + next * .25 : next;
}

class _StableAttention {
  bool available = false;
  bool attention = false;
  bool? _candidate;
  DateTime? _candidateSince;
  DateTime? _greenHoldUntil;

  void reset() {
    available = false;
    attention = false;
    _candidate = null;
    _candidateSince = null;
    _greenHoldUntil = null;
  }

  void update(bool next, DateTime now) {
    available = true;
    if (next == attention) {
      _candidate = null;
      _candidateSince = null;
      return;
    }
    if (next && _greenHoldUntil?.isAfter(now) == true) return;
    if (_candidate != next) {
      _candidate = next;
      _candidateSince = now;
      return;
    }
    if (now.difference(_candidateSince!) < const Duration(seconds: 1)) return;
    attention = next;
    _candidate = null;
    _candidateSince = null;
    if (!attention) _greenHoldUntil = now.add(const Duration(seconds: 2));
  }
}

/// Holds one creative suggestion until the scene changes substantially.
class LandscapeCreativeCoach {
  String? _key;
  String? _candidate;
  DateTime? _candidateSince;
  DateTime? _shownAt;

  void reset() {
    _key = null;
    _candidate = null;
    _candidateSince = null;
    _shownAt = null;
  }

  SituationGuidance update(SituationSignals signals, {DateTime? now}) {
    now ??= DateTime.now();
    final proposed = _classify(signals);
    if (_key == null) {
      _key = proposed;
      _shownAt = now;
    } else if (proposed == _key) {
      _candidate = null;
      _candidateSince = null;
    } else if (_candidate != proposed) {
      _candidate = proposed;
      _candidateSince = now;
    } else if (now.difference(_shownAt!) >= const Duration(seconds: 8) &&
        now.difference(_candidateSince!) >= const Duration(seconds: 2)) {
      _key = proposed;
      _shownAt = now;
      _candidate = null;
      _candidateSince = null;
    }
    return _guidance[_key!]!;
  }

  String _classify(SituationSignals signals) {
    final open = signals.openAreaRatio;
    if (_key == 'open_sky' && (open ?? 0) > .48) return 'open_sky';
    if ((open ?? 0) >= .72) return 'open_sky';
    final area = signals.salientObject?.rect.area;
    if (area != null && area >= .08 && area <= .38) return 'anchor';
    return 'depth';
  }

  static const _guidance = <String, SituationGuidance>{
    'depth': SituationGuidance(
      'Build depth in the scene',
      'Include a nearby subject, a middle distance, and the background.',
      AdviceTone.waiting,
    ),
    'open_sky': SituationGuidance(
      'Use the open sky deliberately',
      'Place the horizon low and keep the strongest cloud or color away from the center.',
      AdviceTone.waiting,
    ),
    'anchor': SituationGuidance(
      'Give the landscape an anchor',
      'Place the main feature away from the center and leave space around it.',
      AdviceTone.waiting,
    ),
  };
}

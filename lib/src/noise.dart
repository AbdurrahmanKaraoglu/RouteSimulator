import 'dart:math' as math;

/// GPS error model. All randomness is derived from [seed] and the sample time, so the same seed always produces
/// the same output (also after `seek`, and on every platform including the web).
class GpsNoise {
  /// Creates an error model; every parameter has a realistic default for a phone in open sky.
  const GpsNoise({
    this.horizontalError = 3,
    this.altitudeError = 4,
    this.speedError = 0.3,
    this.seed = 0,
    this.accuracy,
    this.jumpProbability = 0,
    this.jumpDistance = 40,
    this.dropoutProbability = 0,
    this.dropoutDuration = const Duration(seconds: 5),
  });

  /// No noise, no jumps, no dropouts. Reported accuracy is 1 m.
  static const GpsNoise none = GpsNoise(horizontalError: 0, altitudeError: 0, speedError: 0);

  /// Standard deviation of the horizontal error per axis (north and east), in metres.
  final double horizontalError;

  /// Standard deviation of the altitude error, in metres.
  final double altitudeError;

  /// Standard deviation of the speed error, in m/s. Also reported as `speedAccuracy`.
  final double speedError;

  /// Seed for the deterministic random generator.
  final int seed;

  /// Reported accuracy in metres. When `null` it is derived from [horizontalError]: the radius containing 68% of
  /// fixes (≈ 1.51 σ, like Android's `Location.getAccuracy()`), varied by ±20% per sample.
  final double? accuracy;

  /// Probability (0..1) that a sample is a multipath jump of [jumpDistance] metres in a random direction. The
  /// reported accuracy is not increased — real receivers often under-report such errors.
  final double jumpProbability;

  /// Size of a jump in metres.
  final double jumpDistance;

  /// Probability (0..1) that a time window of [dropoutDuration] has no fix at all (tunnel, urban canyon).
  final double dropoutProbability;

  /// Length of a signal loss window.
  final Duration dropoutDuration;

  /// Whether this model changes anything at all.
  bool get isNone =>
      horizontalError == 0 && altitudeError == 0 && speedError == 0 && jumpProbability == 0 && dropoutProbability == 0;

  /// Throws [ArgumentError] when a value is out of range.
  void validate() {
    void nonNegative(double v, String name) {
      if (!(v >= 0) || !v.isFinite) throw ArgumentError.value(v, name, 'must be a non-negative finite number');
    }

    void probability(double v, String name) {
      if (!(v >= 0 && v <= 1)) throw ArgumentError.value(v, name, 'must be between 0 and 1');
    }

    nonNegative(horizontalError, 'horizontalError');
    nonNegative(altitudeError, 'altitudeError');
    nonNegative(speedError, 'speedError');
    nonNegative(jumpDistance, 'jumpDistance');
    if (accuracy != null) nonNegative(accuracy!, 'accuracy');
    probability(jumpProbability, 'jumpProbability');
    probability(dropoutProbability, 'dropoutProbability');
    if (dropoutProbability > 0 && dropoutDuration <= Duration.zero) {
      throw ArgumentError.value(dropoutDuration, 'dropoutDuration', 'must be positive');
    }
  }
}

/// Multiplies two 32-bit integers modulo 2³², exactly on the VM and the web.
int _imul(int a, int b) {
  final ah = (a >> 16) & 0xffff;
  final al = a & 0xffff;
  final bh = (b >> 16) & 0xffff;
  final bl = b & 0xffff;
  return (al * bl + (((ah * bl + al * bh) & 0xffff) << 16)) & 0xffffffff;
}

int _mix(int h) {
  h &= 0xffffffff;
  h ^= h >> 16;
  h = _imul(h, 0x85ebca6b);
  h ^= h >> 13;
  h = _imul(h, 0xc2b2ae35);
  h ^= h >> 16;
  return h & 0xffffffff;
}

/// Small deterministic generator (mulberry32) keyed by seed, sample key and purpose.
class NoiseRandom {
  NoiseRandom(int seed, int key, int salt) {
    final lo = key & 0xffffffff;
    final hi = (key / 4294967296).floor() & 0xffffffff;
    _state = _mix(_mix(_mix(seed & 0xffffffff) ^ lo) ^ _mix(hi ^ _imul(salt, 0x9e3779b9)));
  }

  late int _state;

  /// Uniform double in `[0, 1)`.
  double nextDouble() {
    _state = (_state + 0x6d2b79f5) & 0xffffffff;
    var t = _state;
    t = _imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xffffffff)) & 0xffffffff;
    return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296;
  }

  /// Standard normal sample (Box–Muller).
  double nextGaussian() {
    final u1 = math.max(nextDouble(), 1e-12);
    final u2 = nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}

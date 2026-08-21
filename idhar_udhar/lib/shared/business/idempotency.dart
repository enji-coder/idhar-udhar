/// In-memory idempotency for the mock apps. Production uses DB unique keys.
class IdempotencyGuard {
  IdempotencyGuard();

  final Map<String, Object?> _seen = <String, Object?>{};

  /// Returns the previous result if [key] was already used; otherwise stores [create].
  T run<T>(String key, T Function() create) {
    if (_seen.containsKey(key)) {
      return _seen[key] as T;
    }
    final T value = create();
    _seen[key] = value;
    return value;
  }

  bool seen(String key) => _seen.containsKey(key);

  void clear() => _seen.clear();
}

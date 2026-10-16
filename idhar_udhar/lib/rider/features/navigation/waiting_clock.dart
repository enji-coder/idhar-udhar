/// Waiting display driven by server timestamps, not a resettable counter.
String formatWaitingClock(int? elapsedSeconds) {
  if (elapsedSeconds == null || elapsedSeconds < 0) {
    return '--:--';
  }
  final int minutes = elapsedSeconds ~/ 60;
  final int seconds = elapsedSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

int waitingElapsedSeconds({
  required DateTime arrivalAt,
  required DateTime serverNow,
  required DateTime fetchedAt,
  required DateTime now,
  DateTime? pickedUpAt,
}) {
  final DateTime end = pickedUpAt ?? serverNow;
  final int base = end.difference(arrivalAt).inSeconds;
  if (pickedUpAt != null) {
    return base < 0 ? 0 : base;
  }
  final int drifted = now.difference(fetchedAt).inSeconds;
  final int total = base + (drifted < 0 ? 0 : drifted);
  return total < 0 ? 0 : total;
}

int freeWaitingRemainingSeconds({
  required int elapsedSeconds,
  required int freeMinutes,
}) {
  final int freeSeconds = freeMinutes < 0 ? 0 : freeMinutes * 60;
  final int remaining = freeSeconds - elapsedSeconds;
  return remaining < 0 ? 0 : remaining;
}

/// Seconds after the free window. Never negative.
int chargeableWaitingSeconds({
  required int elapsedSeconds,
  required int freeMinutes,
}) {
  final int freeSeconds = freeMinutes < 0 ? 0 : freeMinutes * 60;
  final int extra = elapsedSeconds - freeSeconds;
  return extra < 0 ? 0 : extra;
}

/// Same rule as the backend pickup-wait assessment:
/// completed minutes are floored, then multiplied by the snapshotted rate.
/// Returns null when [perMinute] is not a rupee amount.
String? previewWaitingAmount({
  required int elapsedSeconds,
  required int freeMinutes,
  required String perMinute,
}) {
  final int? paise = _rupeePaise(perMinute);
  if (paise == null) {
    return null;
  }
  final int elapsedMinutes = elapsedSeconds <= 0 ? 0 : elapsedSeconds ~/ 60;
  final int free = freeMinutes < 0 ? 0 : freeMinutes;
  final int chargeable = elapsedMinutes - free;
  final int safeMinutes = chargeable < 0 ? 0 : chargeable;
  final int total = safeMinutes * paise;
  final int whole = total ~/ 100;
  final int frac = total % 100;
  return '$whole.${frac.toString().padLeft(2, '0')}';
}

/// Waiting-screen copy. A generic not-found sentence is not a missing field.
String waitingFailureMessage({String? code, String? message}) {
  switch (code) {
    case 'NOT_FOUND':
      return 'Waiting details for this order are not available.';
    case 'FARE_NOT_CONFIRMED':
      return 'Waiting rules for this order are not available.';
  }
  final String text = (message ?? '').trim();
  if (text.isEmpty || text == 'We could not find that.') {
    return 'Waiting charges could not be loaded.';
  }
  return text;
}

int? _rupeePaise(String raw) {
  final String trimmed = raw.trim();
  final RegExpMatch? match =
      RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(trimmed);
  if (match == null) {
    return null;
  }
  final int whole = int.parse(match.group(1)!);
  final String frac = (match.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(frac);
}

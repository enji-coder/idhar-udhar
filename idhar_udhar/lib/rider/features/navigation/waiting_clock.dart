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

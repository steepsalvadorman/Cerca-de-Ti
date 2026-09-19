/// Formats an integer amount of soles as Peruvian currency (e.g. 1234 ->
/// "S/ 1,234.00"), matching the `es-PE` convention (comma thousands
/// separator, period decimal separator — the opposite of `es-CL`, which
/// this app originally targeted before the market moved to Peru).
String formatSoles(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final sign = value < 0 ? '-' : '';
  return 'S/ $sign$buffer.00';
}

const _shortMonths = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Formats an ISO-8601 timestamp as a short local date (e.g. "2 jul"),
/// matching the style used across the client's request history.
String formatShortDate(String isoTimestamp) {
  final date = DateTime.parse(isoTimestamp).toLocal();
  return '${date.day} ${_shortMonths[date.month - 1]}';
}

/// Formats an ISO-8601 timestamp for chat bubbles (e.g. "14:30" today,
/// "2 jul 14:30" on another day).
String formatChatTime(String isoTimestamp) {
  final date = DateTime.parse(isoTimestamp).toLocal();
  final now = DateTime.now();
  final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
  if (isToday) return time;
  return '${date.day} ${_shortMonths[date.month - 1]} $time';
}

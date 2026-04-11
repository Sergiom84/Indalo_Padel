DateTime? chronologyDateTime(String? dateValue, String? timeValue) {
  final date = _parseDateOnly(dateValue);
  if (date == null) {
    return null;
  }

  final time = _parseTimeOnly(timeValue);
  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
    time?.second ?? 0,
  );
}

int compareChronology({
  required String? leftDate,
  required String? leftTime,
  required String? rightDate,
  required String? rightTime,
  bool ascending = true,
}) {
  final left = chronologyDateTime(leftDate, leftTime);
  final right = chronologyDateTime(rightDate, rightTime);

  if (left != null && right != null) {
    final comparison = left.compareTo(right);
    return ascending ? comparison : -comparison;
  }

  if (left != null) {
    return ascending ? -1 : 1;
  }
  if (right != null) {
    return ascending ? 1 : -1;
  }
  return 0;
}

DateTime? _parseDateOnly(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final normalized = value.length >= 10 ? value.substring(0, 10) : value;
  final parts = normalized.split('-');
  if (parts.length != 3) {
    return null;
  }

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }

  return DateTime(year, month, day);
}

_ChronologyTime? _parseTimeOnly(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final parts = value.split(':');
  if (parts.length < 2) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  if (hour == null || minute == null) {
    return null;
  }

  return _ChronologyTime(hour: hour, minute: minute, second: second);
}

class _ChronologyTime {
  final int hour;
  final int minute;
  final int second;

  const _ChronologyTime({
    required this.hour,
    required this.minute,
    required this.second,
  });
}

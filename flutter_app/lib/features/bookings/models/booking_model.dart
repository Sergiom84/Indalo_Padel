class BookingModel {
  final int id;
  final int? courtId;
  final String? venueName;
  final String? courtName;
  final String? date;
  final String? startTime;
  final int? durationMinutes;
  final double? price;
  final String status;
  final String? notes;
  final String? calendarSyncStatus;
  final String? googleEventId;

  const BookingModel({
    required this.id,
    this.courtId,
    this.venueName,
    this.courtName,
    this.date,
    this.startTime,
    this.durationMinutes,
    this.price,
    this.status = 'pendiente',
    this.notes,
    this.calendarSyncStatus,
    this.googleEventId,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: _asInt(json['id']),
      courtId: _asNullableInt(json['court_id'] ?? json['courtId']),
      venueName: (json['venue_name'] ?? json['pista_name']) as String?,
      courtName: json['court_name'] as String?,
      date: (json['date'] ?? json['booking_date'] ?? json['fecha']) as String?,
      startTime: (json['start_time'] ?? json['hora_inicio']) as String?,
      durationMinutes:
          _asNullableInt(json['duration_minutes'] ?? json['duration']),
      price: _asNullableDouble(json['price'] ?? json['total_price']),
      status: (json['status'] ?? 'pendiente') as String,
      notes: json['notes'] as String?,
      calendarSyncStatus:
          (json['calendar_sync_status'] ?? json['sync_status']) as String?,
      googleEventId: json['google_event_id'] as String?,
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

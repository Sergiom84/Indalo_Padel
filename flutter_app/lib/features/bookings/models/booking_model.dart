class BookingModel {
  final int id;
  final String? venueName;
  final String? courtName;
  final String? date;
  final String? startTime;
  final double? price;
  final String status;
  final String? notes;

  const BookingModel({
    required this.id,
    this.venueName,
    this.courtName,
    this.date,
    this.startTime,
    this.price,
    this.status = 'pendiente',
    this.notes,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as int? ?? 0,
      venueName: (json['venue_name'] ?? json['pista_name']) as String?,
      courtName: json['court_name'] as String?,
      date: (json['date'] ?? json['booking_date'] ?? json['fecha']) as String?,
      startTime: (json['start_time'] ?? json['hora_inicio']) as String?,
      price: (json['price'] ?? json['total_price'] as num?)?.toDouble(),
      status: (json['status'] ?? 'pendiente') as String,
      notes: json['notes'] as String?,
    );
  }
}

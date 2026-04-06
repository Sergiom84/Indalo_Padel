class VenueModel {
  final int id;
  final String name;
  final String location;
  final int courtCount;
  final String? openingTime;
  final String? closingTime;
  final List<CourtModel> courts;

  const VenueModel({
    required this.id,
    required this.name,
    required this.location,
    required this.courtCount,
    this.openingTime,
    this.closingTime,
    this.courts = const [],
  });

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    final courtsList = (json['courts'] as List<dynamic>?)
            ?.map((c) => CourtModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return VenueModel(
      id: json['id'] as int? ?? 0,
      name: (json['nombre'] ?? json['name'] ?? '') as String,
      location: (json['ubicacion'] ?? json['location'] ?? '') as String,
      courtCount: (json['court_count'] as int?) ?? courtsList.length,
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
      courts: courtsList,
    );
  }
}

class CourtModel {
  final int id;
  final String name;
  final String? surfaceType;
  final bool? isIndoor;

  const CourtModel({
    required this.id,
    required this.name,
    this.surfaceType,
    this.isIndoor,
  });

  factory CourtModel.fromJson(Map<String, dynamic> json) {
    return CourtModel(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? '') as String,
      surfaceType: (json['surface_type'] ?? json['surface']) as String?,
      isIndoor: json['is_indoor'] as bool?,
    );
  }
}

class AvailabilityModel {
  final List<CourtModel> courts;
  final List<TimeSlotModel> timeSlots;

  const AvailabilityModel({required this.courts, required this.timeSlots});

  factory AvailabilityModel.fromJson(Map<String, dynamic> json) {
    final courts = (json['courts'] as List<dynamic>?)
            ?.map((c) => CourtModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    final rawSlots = (json['time_slots'] ?? json['slots']) as List<dynamic>? ?? [];
    final timeSlots = rawSlots.map((s) => TimeSlotModel.fromJson(s as Map<String, dynamic>)).toList();

    return AvailabilityModel(courts: courts, timeSlots: timeSlots);
  }
}

class TimeSlotModel {
  final String startTime;
  final Map<String, CourtSlot> courts; // key = court_id as string

  const TimeSlotModel({required this.startTime, required this.courts});

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    final startTime = (json['start_time'] ?? json['time'] ?? '') as String;

    final courtsMap = <String, CourtSlot>{};
    final rawCourts = json['courts'];
    if (rawCourts is Map) {
      rawCourts.forEach((key, value) {
        if (value is Map) {
          courtsMap[key.toString()] = CourtSlot.fromJson(value as Map<String, dynamic>);
        }
      });
    } else if (rawCourts is List) {
      for (final c in rawCourts) {
        if (c is Map) {
          final id = c['court_id']?.toString() ?? '';
          courtsMap[id] = CourtSlot.fromJson(c as Map<String, dynamic>);
        }
      }
    }

    return TimeSlotModel(startTime: startTime, courts: courtsMap);
  }
}

class CourtSlot {
  final bool available;
  final double? price;

  const CourtSlot({required this.available, this.price});

  factory CourtSlot.fromJson(Map<String, dynamic> json) {
    return CourtSlot(
      available: json['available'] as bool? ?? false,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

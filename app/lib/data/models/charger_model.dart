import 'review_model.dart';

class AvailabilitySlot {
  final int dayOfWeek; // 0=Sunday, 6=Saturday
  final String startTime; // '08:00'
  final String endTime; // '20:00'

  const AvailabilitySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  String get dayName {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return (dayOfWeek >= 0 && dayOfWeek < 7) ? days[dayOfWeek] : 'Day $dayOfWeek';
  }
}

class ChargerModel {
  final int id;
  final int hostId;
  final String title;
  final String? description;
  final double lat;
  final double lng;
  final String address;
  final String connectorType;
  final double powerKw;
  final double pricePerKwh;
  final double? pricePerHour;
  final List<String> photos;
  final bool isActive;
  final bool isFeatured;
  final String? createdAt;
  final double? distanceKm;
  final double? avgRating;
  final int reviewCount;
  final String? hostName;
  final String? hostEmail;
  final List<AvailabilitySlot> availability;
  final List<ReviewModel> reviews;

  const ChargerModel({
    required this.id,
    required this.hostId,
    required this.title,
    this.description,
    required this.lat,
    required this.lng,
    required this.address,
    required this.connectorType,
    required this.powerKw,
    required this.pricePerKwh,
    this.pricePerHour,
    this.photos = const [],
    this.isActive = true,
    this.isFeatured = false,
    this.createdAt,
    this.distanceKm,
    this.avgRating,
    this.reviewCount = 0,
    this.hostName,
    this.hostEmail,
    this.availability = const [],
    this.reviews = const [],
  });

  factory ChargerModel.fromJson(Map<String, dynamic> json) {
    return ChargerModel(
      id: json['id'] as int,
      hostId: json['host_id'] as int? ?? 0,
      title: json['title'] as String,
      description: json['description'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String,
      connectorType: json['connector_type'] as String,
      powerKw: (json['power_kw'] as num).toDouble(),
      pricePerKwh: (json['price_per_kwh'] as num).toDouble(),
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble(),
      photos: (json['photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1,
      createdAt: json['created_at'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      hostName: json['host_name'] as String?,
      hostEmail: json['host_email'] as String?,
      availability: (json['availability'] as List<dynamic>?)
              ?.map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      reviews: (json['reviews'] as List<dynamic>?)
              ?.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host_id': hostId,
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'address': address,
      'connector_type': connectorType,
      'power_kw': powerKw,
      'price_per_kwh': pricePerKwh,
      'price_per_hour': pricePerHour,
      'photos': photos,
      'is_active': isActive,
      'is_featured': isFeatured,
      'created_at': createdAt,
      'distance_km': distanceKm,
      'avg_rating': avgRating,
      'review_count': reviewCount,
      'host_name': hostName,
      'host_email': hostEmail,
    };
  }

  double get displayHourlyRate => pricePerHour ?? (pricePerKwh * (powerKw > 7.4 ? 7.4 : powerKw));
}


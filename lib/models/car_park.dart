enum Availability { available, almostFull, full }

/// A Park&Ride facility with its current occupancy, parsed from the
/// TfNSW Car Park API (`/v1/carpark?facility=<id>`). All numeric fields are
/// delivered as strings by the API.
class CarPark {
  const CarPark({
    required this.facilityId,
    required this.name,
    required this.suburb,
    required this.address,
    required this.spots,
    required this.occupied,
    this.latitude,
    this.longitude,
    this.messageDate,
  });

  /// Fraction of [spots] below which a car park is reported "Almost Full".
  /// TfNSW recommends 10% and says it should be configurable.
  static const almostFullThreshold = 0.10;

  final String facilityId;
  final String name;
  final String suburb;
  final String address;
  final int spots;
  final int occupied;
  final double? latitude;
  final double? longitude;
  final String? messageDate;

  /// TfNSW recommended formula: availability = spots - occupancy.total.
  int get available => (spots - occupied).clamp(0, spots);

  Availability get availability {
    if (available < 1) return Availability.full;
    if (available < spots * almostFullThreshold) return Availability.almostFull;
    return Availability.available;
  }

  factory CarPark.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map<String, dynamic>?) ?? const {};
    final occupancy = (json['occupancy'] as Map<String, dynamic>?) ?? const {};
    final rawName = (json['facility_name'] as String?)?.trim() ?? 'Unknown';
    final suburb = (location['suburb'] as String?)?.trim() ?? '';

    return CarPark(
      facilityId: '${json['facility_id']}',
      // Names are prefixed with "Park&Ride - "; the suburb column already says it.
      name: rawName.replaceFirst(RegExp(r'^Park&Ride\s*[-–]\s*'), ''),
      suburb: suburb.isEmpty ? 'Unknown' : suburb,
      address: (location['address'] as String?)?.trim() ?? '',
      spots: int.tryParse('${json['spots']}') ?? 0,
      occupied: int.tryParse('${occupancy['total']}') ?? 0,
      latitude: double.tryParse('${location['latitude']}'.trim()),
      longitude: double.tryParse('${location['longitude']}'.trim()),
      messageDate: (json['MessageDate'] as String?)?.replaceAll(' ', ''),
    );
  }
}

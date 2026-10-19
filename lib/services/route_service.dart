import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'location_service.dart';

class TravelEstimate {
  const TravelEstimate({
    required this.meters,
    required this.seconds,
    required this.isRoute,
  });

  final double meters;
  final double seconds;

  /// True for a driving route; false for a straight-line approximation.
  final bool isRoute;
}

/// Driving distance and time between two points.
///
/// Uses the public OSRM demo server (no key, best-effort availability) and
/// falls back to a straight-line distance at [_fallbackSpeedKmh] if it fails.
class RouteService {
  RouteService({http.Client? client}) : _client = client ?? http.Client();

  static const _fallbackSpeedKmh = 40.0;

  final http.Client _client;

  Future<TravelEstimate> estimate(LatLng from, LatLng to) async {
    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.lng},${from.lat};${to.lng},${to.lat}?overview=false',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final route = (jsonDecode(response.body)['routes'] as List).first;
        return TravelEstimate(
          meters: (route['distance'] as num).toDouble(),
          seconds: (route['duration'] as num).toDouble(),
          isRoute: true,
        );
      }
    } catch (_) {
      // fall through to the straight-line estimate
    }

    final meters = Geolocator.distanceBetween(from.lat, from.lng, to.lat, to.lng);
    return TravelEstimate(
      meters: meters,
      seconds: meters / (_fallbackSpeedKmh * 1000 / 3600),
      isRoute: false,
    );
  }
}

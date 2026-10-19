import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/car_park.dart';

class CarParkApiException implements Exception {
  CarParkApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the TfNSW Car Park API.
///
/// The key is read from `PARK_N_RIDE_API_KEY` in the project's `.env` file
/// (bundled as an asset and loaded in `main`), falling back to
/// `--dart-define=PARK_N_RIDE_API_KEY=...`.
class CarParkApi {
  CarParkApi({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? _keyFromEnv();

  static String _keyFromEnv() {
    const defined = String.fromEnvironment('PARK_N_RIDE_API_KEY');
    if (defined.isNotEmpty) return defined;
    return dotenv.isInitialized
        ? (dotenv.maybeGet('PARK_N_RIDE_API_KEY') ?? '').trim()
        : '';
  }

  static const _fullListUrl = 'https://api.transport.nsw.gov.au/v1/carpark/full-list';

  final http.Client _client;
  final String _apiKey;

  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Fetches every facility with its current occupancy in a single request.
  Future<List<CarPark>> fetchAll() async {
    if (!hasApiKey) {
      throw CarParkApiException(
        'No API key. Add PARK_N_RIDE_API_KEY=<your key> to the .env file.',
      );
    }

    final response = await _client.get(Uri.parse(_fullListUrl), headers: {
      'Authorization': 'apikey $_apiKey',
      'Accept': 'application/json',
    });
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CarParkApiException('The API key was rejected (${response.statusCode}).');
    }
    if (response.statusCode != 200) {
      throw CarParkApiException('Car Park API returned ${response.statusCode}.');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    final carParks = [
      for (final item in list) CarPark.fromJson(item as Map<String, dynamic>),
    ].where((c) => c.spots > 0).toList();
    if (carParks.isEmpty) {
      throw CarParkApiException('No car park data was returned.');
    }
    return carParks;
  }
}

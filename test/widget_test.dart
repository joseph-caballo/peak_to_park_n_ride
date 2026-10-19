import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:peak_to_park_n_ride/models/car_park.dart';
import 'package:peak_to_park_n_ride/screens/car_park_screen.dart';
import 'package:peak_to_park_n_ride/services/car_park_api.dart';
import 'package:peak_to_park_n_ride/services/location_service.dart';
import 'package:peak_to_park_n_ride/services/route_service.dart';

Map<String, dynamic> _facility(String id, String name, String suburb, String spots, String total) => {
      'facility_id': id,
      'facility_name': 'Park&Ride - $name',
      'spots': spots,
      'location': {'suburb': suburb, 'address': 'x', 'latitude': ' -33.7', 'longitude': '150.9'},
      'occupancy': {'total': total},
      'MessageDate': '2024-11-25T11:08:35',
    };

class _FakeLocation extends LocationService {
  @override
  Future<LatLng> current() async => (lat: -33.8, lng: 151.0);
}

class _FakeRoutes extends RouteService {
  @override
  Future<TravelEstimate> estimate(LatLng from, LatLng to) async =>
      const TravelEstimate(meters: 12300, seconds: 1080, isRoute: true);
}

void main() {
  test('availability follows TfNSW formula and thresholds', () {
    CarPark make(String spots, String total) =>
        CarPark.fromJson(_facility('1', 'A', 'S', spots, total));

    expect(make('100', '40').available, 60);
    expect(make('100', '40').availability, Availability.available);
    expect(make('100', '95').availability, Availability.almostFull);
    expect(make('100', '100').availability, Availability.full);
    expect(make('100', '130').available, 0);
  });

  testWidgets('dropdown filters the table and labels multi car park suburbs', (tester) async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/carpark/full-list');
      return http.Response(
        jsonEncode([
          _facility('1', 'Tallawong P1', 'Tallawong', '121', '21'),
          _facility('2', 'Tallawong P2', 'Tallawong', '455', '30'),
          _facility('3', 'Hornsby', 'Hornsby', '145', '145'),
        ]),
        200,
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: CarParkScreen(
        api: CarParkApi(client: client, apiKey: 'test'),
        locationService: _FakeLocation(),
        routeService: _FakeRoutes(),
      ),
    ));
    await tester.pumpAndSettle();

    // "All suburbs": Car park column: suburb names, or descriptive names for multi car park suburbs.
    expect(find.text('Car park'), findsOneWidget);
    expect(find.text('Tallawong P1'), findsOneWidget);
    expect(find.text('Tallawong P2'), findsOneWidget);
    expect(find.text('Hornsby'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);

    Future<void> pick(String suburb) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(suburb).last);
      await tester.pumpAndSettle();
    }

    // Multi car park suburb keeps the Car park column.
    await pick('Tallawong');
    expect(find.text('Car park'), findsOneWidget);
    expect(find.text('Tallawong P1'), findsOneWidget);
    expect(find.text('Hornsby'), findsNothing);
    expect(find.textContaining('km (straight-line)'), findsOneWidget);

    // Single car park suburb hides it.
    await pick('Hornsby');
    expect(find.text('Car park'), findsNothing);
    expect(find.text('Full'), findsOneWidget);
    // Travel-time estimate is disabled for now.
    expect(find.textContaining('min'), findsNothing);
  });
}

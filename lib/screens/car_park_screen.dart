import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/car_park.dart';
import '../services/car_park_api.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';

class CarParkScreen extends StatefulWidget {
  const CarParkScreen({super.key, this.api, this.locationService, this.routeService});

  /// Injectable for tests.
  final CarParkApi? api;
  final LocationService? locationService;
  final RouteService? routeService;

  @override
  State<CarParkScreen> createState() => _CarParkScreenState();
}

class _CarParkScreenState extends State<CarParkScreen> {
  static const _allSuburbs = 'All suburbs';

  late final CarParkApi _api = widget.api ?? CarParkApi();
  late final LocationService _location = widget.locationService ?? LocationService();
  // late final RouteService _routes = widget.routeService ?? RouteService();
  late Future<List<CarPark>> _future;
  String _selectedSuburb = _allSuburbs;
  Future<TravelEstimate>? _travel;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchAll();
  }

  void _reload() => setState(() => _future = _api.fetchAll());

  void _selectSuburb(String suburb, List<CarPark> carParks) {
    // Re-picking the same suburb keeps the existing distance.
    if (suburb == _selectedSuburb) return;
    setState(() {
      _selectedSuburb = suburb;
      _travel = suburb == _allSuburbs ? null : _estimateTravel(suburb, carParks);
    });
  }

  /// Display name per facility id: the suburb, or the car park's own
  /// descriptive name (e.g. "Penrith (multi-level)") when a suburb has several.
  static Map<String, String> _carParkLabels(List<CarPark> carParks) {
    final counts = <String, int>{};
    for (final c in carParks) {
      counts[c.suburb] = (counts[c.suburb] ?? 0) + 1;
    }
    return {
      for (final c in carParks)
        c.facilityId: counts[c.suburb]! > 1 ? c.name : c.suburb,
    };
  }

  /// Travel from the phone's location to the centre of the suburb's car parks.
  Future<TravelEstimate> _estimateTravel(String suburb, List<CarPark> carParks) async {
    final points = carParks
        .where((c) => c.suburb == suburb && c.latitude != null && c.longitude != null)
        .toList();
    if (points.isEmpty) {
      throw LocationException('No coordinates available for $suburb.');
    }
    final destination = (
      lat: points.map((c) => c.latitude!).reduce((a, b) => a + b) / points.length,
      lng: points.map((c) => c.longitude!).reduce((a, b) => a + b) / points.length,
    );
    final origin = await _location.current();
    // TODO: travel-time estimate disabled for now; re-enable to get the driving
    // route distance and time from the routing service.
    // return _routes.estimate(origin, destination);
    final meters = Geolocator.distanceBetween(
      origin.lat,
      origin.lng,
      destination.lat,
      destination.lng,
    );
    return TravelEstimate(meters: meters, seconds: 0, isRoute: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: ColoredBox(color: _brandAccent, child: SizedBox(height: 3, width: double.infinity)),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ParkAndRideLogo(),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                      children: const [
                        TextSpan(text: 'Park'),
                        TextSpan(text: '&', style: TextStyle(color: _brandAccent)),
                        TextSpan(text: 'Ride'),
                      ],
                    ),
                  ),
                  Text(
                    'AVAILABILITY',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<CarPark>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(message: '${snapshot.error}', onRetry: _reload);
          }
          return _buildContent(snapshot.requireData);
        },
      ),
    );
  }

  Widget _buildContent(List<CarPark> carParks) {
    final suburbs = {for (final c in carParks) c.suburb}.toList()..sort();
    final selected = suburbs.contains(_selectedSuburb) ? _selectedSuburb : _allSuburbs;
    final labels = _carParkLabels(carParks);
    final visible = carParks
        .where((c) => selected == _allSuburbs || c.suburb == selected)
        .toList()
      ..sort((a, b) {
        final bySuburb = a.suburb.compareTo(b.suburb);
        return bySuburb != 0 ? bySuburb : labels[a.facilityId]!.compareTo(labels[b.facilityId]!);
      });
    // Suburbs with several car parks always show the Car park column so the
    // individual car parks (Suburb - P1, P2, ...) can be told apart.
    final showCarPark = selected == _allSuburbs ||
        visible.any((c) => labels[c.facilityId] != c.suburb);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            decoration: const InputDecoration(
              labelText: 'Suburb',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in [_allSuburbs, ...suburbs])
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (value) {
              if (value != null) _selectSuburb(value, carParks);
            },
          ),
        ),
        _TravelInfo(travel: _travel),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: _CarParkTable(
                carParks: visible,
                labels: labels,
                showCarPark: showCarPark,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            '* Estimated availability; may differ from actual parking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

const _brandBlue = Color(0xFF1565C0);
const _brandAccent = Color(0xFFFFB300);

/// White "P" tile with an amber train, drawn from built-in icons.
class _ParkAndRideLogo extends StatelessWidget {
  const _ParkAndRideLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.local_parking, color: _brandBlue, size: 30),
          Positioned(
            right: 2,
            bottom: 2,
            child: Icon(Icons.train, color: _brandAccent, size: 15),
          ),
        ],
      ),
    );
  }
}

class _TravelInfo extends StatelessWidget {
  const _TravelInfo({required this.travel});

  final Future<TravelEstimate>? travel;

  static String _distance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

  // static String _duration(double seconds) {
  //   final minutes = (seconds / 60).ceil();
  //   if (minutes < 60) return '$minutes min';
  //   return '${minutes ~/ 60} h ${minutes % 60} min';
  // }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    Widget wrap(Widget child) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: child,
        );

    if (travel == null) {
      return wrap(Text(
        'Select a suburb to see the distance from your location.',
        style: style,
      ));
    }

    return FutureBuilder<TravelEstimate>(
      future: travel,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return wrap(const Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Finding your location…'),
          ]));
        }
        if (snapshot.hasError) {
          return wrap(Text('${snapshot.error}', style: style));
        }
        final t = snapshot.requireData;
        return wrap(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.place, size: 20),
              const SizedBox(width: 8),
              Text('${_distance(t.meters)} (straight-line)', style: style),
              // Text('${_distance(t.meters)}  ·  ~${_duration(t.seconds)}', style: style),
            ]),
            // if (!t.isRoute)
            //   Text(
            //     'Straight-line estimate at 40 km/h (route unavailable).',
            //     style: Theme.of(context).textTheme.bodySmall,
            //   ),
          ],
        ));
      },
    );
  }
}

class _CarParkTable extends StatelessWidget {
  const _CarParkTable({
    required this.carParks,
    required this.labels,
    required this.showCarPark,
  });

  final List<CarPark> carParks;

  /// Car park display name by facility id.
  final Map<String, String> labels;

  /// Adds a leading "Car park" column.
  final bool showCarPark;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall;
    Widget cell(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          // Scale down rather than overflow so every column stays visible.
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
        );

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: Theme.of(context).dividerColor),
      ),
      children: [
        TableRow(children: [
          if (showCarPark) cell(Text('Car park', style: headerStyle)),
          cell(Text('Available / Spaces', style: headerStyle)),
          cell(Text('Status', style: headerStyle)),
        ]),
        for (final c in carParks)
          TableRow(children: [
            if (showCarPark) cell(Text(labels[c.facilityId] ?? c.suburb)),
            cell(Row(mainAxisSize: MainAxisSize.min, children: [
              _NumberBadge(text: '${c.available}', color: Colors.green.shade100),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('/'),
              ),
              _NumberBadge(text: '${c.spots}', color: Colors.grey.shade300),
            ])),
            cell(_StatusChip(availability: c.availability)),
          ]),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.availability});

  final Availability availability;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (availability) {
      Availability.available => ('Available', Colors.green),
      Availability.almostFull => ('Almost Full', Colors.orange),
      Availability.full => ('Full', Colors.red),
    };
    return Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

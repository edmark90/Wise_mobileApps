import 'package:flutter_test/flutter_test.dart';
import 'package:wise/models/schedule_route.dart';

void main() {
  group('ScheduleRoute.fromJson', () {
    test('converts GeoJSON [lng, lat] pairs to LatLng(lat, lng)', () {
      final route = ScheduleRoute.fromJson({
        'schedule_id': 12,
        'truck_number': 'Truck 02',
        'route_name': 'Tunasan Route',
        'starting_point': 'Arandia Street',
        'collection_date': '2026-10-26',
        'collection_time': '07:00:00',
        'status': 'Upcoming',
        'depot': {
          'name': 'Tunasan Dispatch Depot',
          'address': 'Arandia Street, Barangay Tunasan, Muntinlupa City',
          'latitude': 14.384538,
          'longitude': 121.051391,
        },
        'stops': [
          {
            'id': 4,
            'barangay': 'Alabang',
            'street': 'Alabang Public Market',
            'sequence': 1,
            'collection_time': '07:30:00',
            'status': 'Upcoming',
            'latitude': 14.41928,
            'longitude': 121.04453,
            'is_exact': true,
            'waypoint_index': 1,
          },
        ],
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [121.051391, 14.384538],
            [121.04453, 14.41928],
          ],
        },
        'legs': [
          [
            [121.051391, 14.384538],
            [121.04453, 14.41928],
          ],
        ],
        'is_segmented': true,
        'distance_meters': 15400,
        'duration_seconds': 1800,
        'message': null,
        'warnings': ['Stop 1: inside Muntinlupa'],
      });

      expect(route.scheduleId, 12);
      expect(route.truckNumber, 'Truck 02');
      expect(route.geometry, hasLength(2));
      expect(route.geometry.first.latitude, 14.384538);
      expect(route.geometry.first.longitude, 121.051391);
      expect(route.legs.single.first.latitude, 14.384538);
      expect(route.stops.single.position?.latitude, 14.41928);
      expect(route.stops.single.position?.longitude, 121.04453);
      expect(route.stops.single.waypointIndex, 1);
      expect(route.stops.single.isExact, isTrue);
      expect(route.stops.single.formattedTime, '7:30 AM');
      expect(route.isSegmented, isTrue);
      expect(route.distanceLabel, '15.4 km');
      expect(route.durationLabel, '30 min');
      expect(route.warnings, hasLength(1));
    });

    test('handles missing geometry and missing stop coordinates safely', () {
      final route = ScheduleRoute.fromJson({
        'schedule_id': 9,
        'collection_date': '2026-10-26',
        'depot': {
          'name': 'Depot',
          'address': '',
          'latitude': 14.384538,
          'longitude': 121.051391,
        },
        'stops': [
          {
            'id': 1,
            'barangay': 'Buli',
            'sequence': 1,
            'collection_time': '08:00:00',
            'latitude': null,
            'longitude': null,
          },
        ],
        'geometry': null,
        'legs': null,
        'message': 'Routing service unavailable.',
        'warnings': [],
      });

      expect(route.hasGeometry, isFalse);
      expect(route.stops.single.position, isNull);
      expect(route.message, 'Routing service unavailable.');
      expect(route.legs, isEmpty);
    });
  });
}

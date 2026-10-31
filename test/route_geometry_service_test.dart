import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wise/models/collection_schedule.dart';
import 'package:wise/services/muntinlupa_geocoding.dart';
import 'package:wise/services/route_geometry_service.dart';

void main() {
  group('MuntinlupaGeocoding', () {
    test('resolves coordinates for known barangay and street', () {
      final loc = MuntinlupaGeocoding.resolve(
        barangay: 'Alabang',
        street: 'Alabang Public Market',
      );
      expect(loc, isNotNull);
      expect(loc!.isExact, isTrue);
      expect(loc.position.latitude, 14.41928);
      expect(loc.position.longitude, 121.04453);
    });

    test('matches the website registry for landmarks that used to drift', () {
      // assets/js/components/route-map.js: 'Cupang|Soldiers Hills Road' is
      // [14.40011, 121.03921]; the old mobile table had 14.45940, 121.04869.
      final loc = MuntinlupaGeocoding.resolve(
        barangay: 'Cupang',
        street: 'Soldiers Hills Road',
      );
      expect(loc, isNotNull);
      expect(loc!.position.latitude, 14.40011);
      expect(loc.position.longitude, 121.03921);
    });

    test('resolves coordinates for barangay center when street is unknown', () {
      final loc = MuntinlupaGeocoding.resolve(
        barangay: 'Barangay Putatan',
        street: 'Unknown alley',
      );
      expect(loc, isNotNull);
      expect(loc!.position.latitude, 14.39497);
      expect(loc.position.longitude, 121.04483);
      expect(loc.isApproximate, isTrue);
    });

    test('leaves unresolvable locations unplaced instead of inventing a point', () {
      expect(
        MuntinlupaGeocoding.resolve(
          barangay: 'Nonexistent',
          street: 'Nowhere',
        ),
        isNull,
      );
    });
  });

  group('RouteGeometryService.buildRouteFromSchedule', () {
    test('generates valid ScheduleRoute with coordinates from CollectionSchedule', () async {
      final schedule = CollectionSchedule(
        id: 42,
        barangay: 'Bayanan',
        zone: 'Zone 1',
        collectionDate: '2026-10-26',
        collectionTime: '08:00:00',
        assignedPersonnel: 'Team Alpha',
        truckNumber: 'Truck 05',
        status: 'Upcoming',
        stops: [
          const CollectionStop(
            id: 101,
            scheduleId: 42,
            barangay: 'Bayanan',
            street: 'Bayanan Public Market',
            sequence: 1,
            collectionTime: '08:00:00',
          ),
          const CollectionStop(
            id: 102,
            scheduleId: 42,
            barangay: 'Bayanan',
            street: 'Bayanan Barangay Hall',
            sequence: 2,
            collectionTime: '08:30:00',
          ),
        ],
      );

      final route = await RouteGeometryService.instance.buildRouteFromSchedule(schedule);

      expect(route.scheduleId, 42);
      expect(route.truckNumber, 'Truck 05');
      expect(route.stops, hasLength(2));
      expect(route.stops.first.position, isNotNull);
      expect(route.stops.last.position, isNotNull);
      expect(route.stops.first.position, isNot(equals(route.stops.last.position)));
      expect(route.depot.position, MuntinlupaGeocoding.depotPosition);
      expect(route.distanceMeters, isNotNull);
      expect(route.distanceMeters! > 0, isTrue);
      expect(route.durationSeconds, isNotNull);
      expect(route.durationSeconds! > 0, isTrue);
    });

    test('synthesizes stop when schedule.stops is empty', () async {
      final schedule = const CollectionSchedule(
        id: 77,
        barangay: 'Poblacion',
        zone: 'Muntinlupa City Hall',
        collectionDate: '2026-10-26',
        collectionTime: '09:00:00',
        assignedPersonnel: 'Crew 1',
        truckNumber: 'Truck 01',
        status: 'Upcoming',
        stops: [],
      );

      final route = await RouteGeometryService.instance.buildRouteFromSchedule(schedule);

      expect(route.stops, hasLength(1));
      expect(route.stops.single.barangay, 'Poblacion');
      expect(route.stops.single.street, 'Muntinlupa City Hall');
      expect(route.stops.single.position, isNotNull);
    });

    test('falls back to straight, clearly approximate legs without road data', () async {
      final schedule = CollectionSchedule(
        id: 43,
        barangay: 'Bayanan',
        zone: 'Zone 1',
        collectionDate: '2026-10-26',
        collectionTime: '08:00:00',
        assignedPersonnel: 'Team Alpha',
        truckNumber: 'Truck 05',
        status: 'Upcoming',
        stops: [
          const CollectionStop(
            id: 201,
            scheduleId: 43,
            barangay: 'Tunasan',
            street: 'Buendia Street',
            sequence: 1,
            collectionTime: '08:00:00',
          ),
          const CollectionStop(
            id: 202,
            scheduleId: 43,
            barangay: 'Sucat',
            street: 'Sucat Barangay Hall',
            sequence: 2,
            collectionTime: '08:30:00',
          ),
        ],
      );

      final route = await RouteGeometryService.instance
          .buildRouteFromSchedule(schedule);

      // No road geometry is available in a test environment: the route must be
      // direct stop-to-stop lines, never invented curves presented as roads.
      expect(route.isSegmented, isFalse);
      expect(route.legs, hasLength(2));
      expect(route.legs.every((leg) => leg.length == 2), isTrue);
      expect(route.stops.map((stop) => stop.waypointIndex), [1, 2]);
      expect(route.distanceMeters, isNotNull);
    });

    test('unresolved stops keep no position so the chain is never bent', () async {
      final schedule = const CollectionSchedule(
        id: 45,
        barangay: 'Atlantis',
        zone: 'Nowhere Street',
        collectionDate: '2026-10-26',
        collectionTime: '09:00:00',
        assignedPersonnel: 'Crew 2',
        truckNumber: 'Truck 02',
        status: 'Upcoming',
        stops: [
          CollectionStop(
            id: 401,
            scheduleId: 45,
            barangay: 'Atlantis',
            street: 'Nowhere Street',
            sequence: 1,
            collectionTime: '09:00:00',
          ),
        ],
      );

      final route = await RouteGeometryService.instance
          .buildRouteFromSchedule(schedule);

      expect(route.stops.single.position, isNull);
      expect(route.stops.single.waypointIndex, isNull);
      expect(route.warnings, isNotEmpty);
      expect(route.hasGeometry, isFalse);
    });

    test('builds an instant map route without touching the network', () {
      const schedule = CollectionSchedule(
        id: 44,
        barangay: 'Poblacion',
        zone: 'Muntinlupa City Hall',
        collectionDate: '2026-10-26',
        collectionTime: '09:00:00',
        assignedPersonnel: 'Crew 1',
        truckNumber: 'Truck 01',
        status: 'Upcoming',
        stops: [
          CollectionStop(
            id: 301,
            scheduleId: 44,
            barangay: 'Poblacion',
            street: 'Muntinlupa City Hall',
            sequence: 1,
            collectionTime: '09:00:00',
          ),
        ],
      );

      final route = RouteGeometryService.instance.buildLocalRoute(schedule);

      // Map and pins are ready immediately; the road line arrives later.
      expect(route.stops, hasLength(1));
      expect(route.stops.single.position, isNotNull);
      expect(route.stops.single.waypointIndex, 1);
      expect(route.hasGeometry, isFalse);
      expect(route.isSegmented, isFalse);
    });
  });

  group('splitRouteIntoLegs', () {
    test('cuts one road polyline into legs aligned with every waypoint', () {
      const depot = LatLng(14.384538, 121.051391);
      const stop1 = LatLng(14.39, 121.05);
      const stop2 = LatLng(14.40, 121.045);
      final geometry = <LatLng>[
        depot,
        const LatLng(14.386, 121.0505),
        stop1,
        const LatLng(14.396, 121.048),
        stop2,
      ];

      final legs = RouteGeometryService.splitRouteIntoLegs(
        geometry,
        const [depot, stop1, stop2],
      );

      expect(legs, isNotNull);
      final cut = legs!;
      expect(cut, hasLength(2));
      expect(cut.first.first, depot);
      expect(cut.first.last, stop1);
      expect(cut.last.first, stop1);
      expect(cut.last.last, stop2);
      // Every road vertex is preserved; only the shared cut points repeat.
      expect(cut.expand((leg) => leg).length, geometry.length + 1);
    });

    test('keeps a two-point leg when two stops share one vertex', () {
      const depot = LatLng(14.384538, 121.051391);
      const shared = LatLng(14.39, 121.05);
      final geometry = <LatLng>[
        depot,
        const LatLng(14.386, 121.0505),
        shared,
      ];

      final legs = RouteGeometryService.splitRouteIntoLegs(
        geometry,
        const [depot, shared, shared],
      );

      // Leg count must match (waypoints - 1) so waypoint indexes stay valid.
      expect(legs, isNotNull);
      final cut = legs!;
      expect(cut, hasLength(2));
      expect(cut[1], hasLength(2));
      expect(cut[1].first, shared);
      expect(cut[1].last, shared);
    });

    test('still cuts real road geometry when a stop snaps far from it', () {
      const depot = LatLng(14.384538, 121.051391);
      const unreachable = LatLng(15.5, 121.9);
      const last = LatLng(14.39, 121.05);
      final geometry = <LatLng>[
        depot,
        const LatLng(14.386, 121.0505),
        last,
      ];

      // Real road geometry must never be discarded: the lenient pass cuts at
      // the nearest vertex so the line still follows the road.
      final legs = RouteGeometryService.splitRouteIntoLegs(
        geometry,
        const [depot, unreachable, last],
      );
      expect(legs, isNotNull);
      expect(legs!, hasLength(2));

      // The strict website-compatible probe still reports the mismatch.
      expect(
        RouteGeometryService.findNearestVertexIndex(geometry, unreachable, 0),
        isNull,
      );
    });
  });
}

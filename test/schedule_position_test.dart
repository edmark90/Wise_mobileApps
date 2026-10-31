import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wise/models/schedule_route.dart';
import 'package:wise/services/schedule_position_service.dart';

const _depot = DepotInfo(
  name: 'Tunasan Dispatch Depot',
  address: 'Arandia Street, Barangay Tunasan, Muntinlupa City',
  position: LatLng(14.384538, 121.051391),
);

ScheduleRoute _route({
  String date = '2026-10-26',
  String status = 'Upcoming',
  bool segmented = true,
  List<RouteStopPoint>? stops,
}) {
  final stopList = stops ??
      [
        const RouteStopPoint(
          id: 1,
          barangay: 'Alabang',
          street: 'Alabang Public Market',
          sequence: 1,
          collectionTime: '07:00:00',
          position: LatLng(14.41928, 121.04453),
          isExact: true,
          waypointIndex: 1,
        ),
        const RouteStopPoint(
          id: 2,
          barangay: 'Putatan',
          street: 'Barangay Putatan Barangay Hall',
          sequence: 2,
          collectionTime: '08:00:00',
          position: LatLng(14.39500, 121.04832),
          isExact: true,
          waypointIndex: 2,
        ),
        const RouteStopPoint(
          id: 3,
          barangay: 'Tunasan',
          street: 'Buendia Street',
          sequence: 3,
          collectionTime: '09:00:00',
          position: LatLng(14.37956, 121.05250),
          isExact: true,
          waypointIndex: 3,
        ),
      ];

  return ScheduleRoute(
    scheduleId: 7,
    truckNumber: 'Truck 01',
    routeName: 'Alabang Route',
    startingPoint: 'Alabang Public Market',
    collectionDate: date,
    collectionTime: '07:00:00',
    status: status,
    depot: _depot,
    stops: stopList,
    geometry: segmented
        ? const [
            LatLng(14.384538, 121.051391),
            LatLng(14.41928, 121.04453),
            LatLng(14.39500, 121.04832),
            LatLng(14.37956, 121.05250),
          ]
        : const [],
    legs: segmented
        ? const [
            [
              LatLng(14.384538, 121.051391),
              LatLng(14.41928, 121.04453),
            ],
            [
              LatLng(14.41928, 121.04453),
              LatLng(14.39500, 121.04832),
            ],
            [
              LatLng(14.39500, 121.04832),
              LatLng(14.37956, 121.05250),
            ],
          ]
        : const [],
    isSegmented: segmented,
  );
}

DateTime _manila(int hour, int minute) => DateTime(2026, 10, 26, hour, minute);

void main() {
  group('schedule-based truck position', () {
    test('future date keeps the truck at the depot', () {
      final route = _route(date: '2026-10-27');
      final position =
          SchedulePositionService.resolve(route, now: _manila(23, 0));

      expect(position.phase, SchedulePhase.atDepot);
      expect(position.coordinate, _depot.position);
      expect(position.nextStopIndex, 0);
    });

    test('before the first scheduled time keeps the truck at the depot', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(6, 59));

      expect(position.phase, SchedulePhase.atDepot);
      expect(position.coordinate, _depot.position);
      expect(position.detail, contains('7:00 AM'));
    });

    test('at the first scheduled time the truck is at stop 1', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(7, 0));

      expect(position.phase, SchedulePhase.atStop);
      expect(position.stopIndex, 0);
      expect(position.nextStopIndex, 1);
      expect(position.coordinate, route.stops[0].position);
    });

    test('between scheduled times the truck stays at the last reached stop', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(7, 59));

      expect(position.phase, SchedulePhase.atStop);
      expect(position.stopIndex, 0);
      expect(position.coordinate, route.stops[0].position);
    });

    test('at the second scheduled time the truck jumps to stop 2', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(8, 15));

      expect(position.phase, SchedulePhase.atStop);
      expect(position.stopIndex, 1);
      expect(position.nextStopIndex, 2);
      expect(position.coordinate, route.stops[1].position);
    });

    test('at the final scheduled time the route is completed', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(9, 0));

      expect(position.phase, SchedulePhase.completed);
      expect(position.stopIndex, 2);
      expect(position.nextStopIndex, isNull);
      expect(position.coordinate, route.stops[2].position);
      expect(
        SchedulePositionService.remainingSegments(route, position),
        isEmpty,
      );
    });

    test('a past collection date is completed', () {
      final route = _route(date: '2026-10-20');
      final position =
          SchedulePositionService.resolve(route, now: _manila(10, 0));

      expect(position.phase, SchedulePhase.completed);
      expect(position.coordinate, route.stops.last.position);
    });

    test('a cancelled assignment never shows an active route', () {
      final route = _route(status: 'Cancelled');
      final position =
          SchedulePositionService.resolve(route, now: _manila(8, 0));

      expect(position.phase, SchedulePhase.cancelled);
      expect(
        SchedulePositionService.remainingSegments(route, position),
        isEmpty,
      );
    });

    test('Manila wall clock is UTC+8 regardless of device timezone', () {
      final manila = SchedulePositionService.manilaWallClock(
        DateTime.utc(2026, 10, 26, 0, 0),
      );

      expect(manila, DateTime(2026, 10, 26, 8, 0));
    });

    test('a UTC instant resolves at the correct Manila scheduled time', () {
      final route = _route();
      final now = SchedulePositionService.manilaWallClock(
        DateTime.utc(2026, 10, 26, 0, 0), // 8:00 AM in Manila
      );
      final position = SchedulePositionService.resolve(route, now: now);

      expect(position.phase, SchedulePhase.atStop);
      expect(position.stopIndex, 1);
    });

    test('unresolved stop coordinates fall back to the depot', () {
      final route = _route(
        stops: const [
          RouteStopPoint(
            id: 1,
            barangay: 'Alabang',
            collectionTime: '07:00:00',
          ),
        ],
      );
      final position =
          SchedulePositionService.resolve(route, now: _manila(7, 30));

      expect(position.phase, SchedulePhase.completed);
      expect(position.coordinate, _depot.position);
    });
  });

  group('remaining route segments', () {
    test('before departure every saved leg is shown', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(6, 0));

      expect(
        SchedulePositionService.remainingSegments(route, position),
        hasLength(3),
      );
    });

    test('reached legs are hidden', () {
      final route = _route();
      final atFirst =
          SchedulePositionService.resolve(route, now: _manila(7, 30));
      final atSecond =
          SchedulePositionService.resolve(route, now: _manila(8, 30));

      expect(
        SchedulePositionService.remainingSegments(route, atFirst),
        hasLength(2),
      );
      expect(
        SchedulePositionService.remainingSegments(route, atSecond),
        hasLength(1),
      );
    });

    test('straight stop-to-stop lines are used when geometry is missing', () {
      final route = _route(segmented: false);
      final position =
          SchedulePositionService.resolve(route, now: _manila(7, 30));
      final segments =
          SchedulePositionService.remainingSegments(route, position);

      expect(segments, hasLength(2));
      expect(segments.first.first, route.stops[0].position);
      expect(segments.last.last, route.stops[2].position);
    });

    test('no active line remains after completion', () {
      final route = _route();
      final position =
          SchedulePositionService.resolve(route, now: _manila(9, 1));

      expect(
        SchedulePositionService.remainingSegments(route, position),
        isEmpty,
      );
    });
  });
}

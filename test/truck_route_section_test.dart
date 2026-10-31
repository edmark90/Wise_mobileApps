import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:wise/models/collection_schedule.dart';
import 'package:wise/models/schedule_route.dart';
import 'package:wise/widgets/schedule/truck_route_section.dart';

CollectionSchedule _assignment(int id) => CollectionSchedule(
  id: id,
  barangay: 'Alabang',
  zone: 'Alabang Public Market',
  collectionDate: '2099-01-01',
  collectionTime: '07:00:00',
  assignedPersonnel: 'Crew $id',
  truckNumber: 'Truck 0$id',
  status: 'Upcoming',
  stops: [
    CollectionStop(
      id: id * 10,
      scheduleId: id,
      barangay: 'Alabang',
      street: 'Alabang Public Market',
      collectionTime: '07:00:00',
    ),
  ],
);

ScheduleRoute _route(int id) => ScheduleRoute(
  scheduleId: id,
  truckNumber: 'Truck 0$id',
  routeName: 'Alabang Route $id',
  startingPoint: 'Alabang Public Market',
  collectionDate: '2099-01-01',
  collectionTime: '07:00:00',
  status: 'Upcoming',
  depot: const DepotInfo(
    name: 'Tunasan Dispatch Depot',
    address: 'Arandia Street, Barangay Tunasan, Muntinlupa City',
    position: LatLng(14.384538, 121.051391),
  ),
  stops: [
    RouteStopPoint(
      id: id * 10,
      barangay: 'Alabang',
      street: 'Alabang Public Market',
      collectionTime: '07:00:00',
    ),
  ],
);

void main() {
  testWidgets('shows one truck at a time and reuses loaded geometry', (
    tester,
  ) async {
    final calls = <int>[];
    var selected = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: TruckRouteSection(
                  assignments: [_assignment(1), _assignment(2)],
                  selectedScheduleId: selected,
                  onScheduleSelected: (schedule) {
                    setState(() => selected = schedule.id);
                  },
                  loadRoute: (id) async {
                    calls.add(id);
                    return _route(id);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(calls, [1]);
    expect(find.text('Truck 01'), findsWidgets);
    expect(find.text('Truck 02'), findsOneWidget);
    // Only the selected truck's route area exists.
    expect(find.text('Stop coordinates unavailable'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Truck 02'));
    await tester.pumpAndSettle();

    expect(calls, [1, 2]);
    final chip2 = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Truck 02'),
    );
    expect(chip2.selected, isTrue);
    expect(find.text('Stop coordinates unavailable'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Truck 01'));
    await tester.pumpAndSettle();

    // Switching back reuses the cached route; no second request.
    expect(calls, [1, 2]);
    expect(find.text('Stop coordinates unavailable'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

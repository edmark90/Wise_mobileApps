import '../core/network/api_client.dart';
import '../core/network/network_exception.dart';
import '../models/collection_schedule.dart';

/// REST access to collection schedules.
class ScheduleService {
  ScheduleService._();
  static final ScheduleService instance = ScheduleService._();

  Future<List<CollectionSchedule>> getUpcomingSchedules(String startDate, String endDate) async {
    final response = await ApiClient.instance.get(
      '/collection-schedules/mobile/upcoming/',
      query: {'start_date': startDate, 'end_date': endDate},
    );

    if (response.statusCode == 401) {
      throw const ApiException('Unauthorized. Please sign in again.');
    }
    final data = ApiClient.instance.decode(response, fallback: 'Failed to load schedules');
    return (data as List)
        .map((json) => CollectionSchedule.fromJson((json as Map).cast<String, dynamic>()))
        .toList();
  }
}

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/collection_schedule.dart';
import 'route_journey_view.dart';

/// Bottom sheet with full details of a collection route plus the day's
/// route journey preview.
class ScheduleDetailSheet extends StatelessWidget {
  final CollectionSchedule schedule;
  final List<CollectionSchedule> allSchedules;

  const ScheduleDetailSheet({
    super.key,
    required this.schedule,
    required this.allSchedules,
  });

  Color _zoneColor(String zone) {
    switch (zone) {
      case 'Zone 1': return const Color(0xFF16A34A);
      case 'Zone 2': return const Color(0xFF3B82F6);
      case 'Zone 3': return const Color(0xFFF59E0B);
      case 'Zone 4': return const Color(0xFF8B5CF6);
      case 'Zone 5': return const Color(0xFFEC4899);
      default: return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = _zoneColor(schedule.zone);
    final index = allSchedules.indexOf(schedule);
    final routeStops = allSchedules.map((s) => s.barangay).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: schedule.statusBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: schedule.statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COLLECTION ROUTE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        schedule.barangay,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule.formattedDate,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: schedule.statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    schedule.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: schedule.statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24, indent: 20, endIndent: 20),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info cards row
                  Row(
                    children: [
                      _InfoCard(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: schedule.formattedTime,
                        color: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 10),
                      _InfoCard(
                        icon: Icons.location_on_rounded,
                        label: 'Zone',
                        value: schedule.zone.isEmpty ? 'N/A' : schedule.zone,
                        color: zoneColor,
                      ),
                      const SizedBox(width: 10),
                      _InfoCard(
                        icon: Icons.person_outline,
                        label: 'Personnel',
                        value: schedule.assignedPersonnel.isEmpty ? 'N/A' : schedule.assignedPersonnel,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Route preview title
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Route Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text(
                        '${routeStops.length} stop${routeStops.length > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  RouteJourneyView(
                    stops: allSchedules,
                    currentIndex: index,
                  ),

                  const SizedBox(height: 24),

                  // All routes for the day
                  const Text(
                    'All Routes Today',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(allSchedules.length, (i) {
                    final s = allSchedules[i];
                    final isCurrent = i == index;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.primary : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.barangay,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                Text(
                                  '${s.formattedTime} • ${s.zone.isEmpty ? 'No zone' : s.zone}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: s.statusBgColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              s.status,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: s.statusColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800]),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

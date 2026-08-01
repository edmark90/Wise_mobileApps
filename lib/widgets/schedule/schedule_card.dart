import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/collection_schedule.dart';

/// Single collection route card with a timeline bar.
class ScheduleCard extends StatelessWidget {
  final CollectionSchedule schedule;
  final int cardIndex;
  final int totalInGroup;
  final VoidCallback onTap;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.cardIndex,
    required this.totalInGroup,
    required this.onTap,
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
    final isFirst = cardIndex == 0;
    final isLast = cardIndex == totalInGroup - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFirst ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: isFirst ? AppColors.primary.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left timeline bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        if (isFirst) AppColors.primary else const Color(0xFFCBD5E1),
                        if (isLast) AppColors.primary else const Color(0xFFCBD5E1),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Time column
                SizedBox(
                  width: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        schedule.formattedTime.split(' ')[0],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        schedule.formattedTime.split(' ')[1],
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Vertical divider
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.grey[200],
                  margin: const EdgeInsets.symmetric(vertical: 12),
                ),
                const SizedBox(width: 10),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                schedule.barangay,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: schedule.statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                schedule.status,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: schedule.statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: zoneColor),
                            const SizedBox(width: 3),
                            Text(
                              schedule.zone.isEmpty ? 'No zone' : schedule.zone,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                            if (schedule.assignedPersonnel.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Text(
                                schedule.assignedPersonnel,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

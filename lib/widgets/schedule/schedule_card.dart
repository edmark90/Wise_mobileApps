import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/collection_schedule.dart';

/// Single collection route assignment card with a timeline bar, truck identification, and stops.
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

  @override
  Widget build(BuildContext context) {
    final isFirst = cardIndex == 0;
    final isLast = cardIndex == totalInGroup - 1;
    final hasStops = schedule.stops.isNotEmpty;
    final stopsCount = hasStops ? schedule.stops.length : 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                        schedule.formattedTime.split(' ').first,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        schedule.formattedTime.split(' ').length > 1 ? schedule.formattedTime.split(' ').last : '',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Vertical divider
                Container(
                  width: 1,
                  height: 38,
                  color: Colors.grey[200],
                  margin: const EdgeInsets.symmetric(vertical: 10),
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
                            Flexible(
                              child: Text(
                                schedule.routeName?.isNotEmpty == true
                                    ? schedule.routeName!
                                    : '${schedule.barangay} Route',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (schedule.truckNumber.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_shipping_rounded, size: 10, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 3),
                                    Text(
                                      schedule.truckNumber,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: schedule.statusBgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                schedule.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: schedule.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.pin_drop_rounded, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                hasStops
                                    ? '${stopsCount} Stop${stopsCount > 1 ? 's' : ''}: ${schedule.stops.map((s) => s.barangay + (s.street.isNotEmpty ? " (${s.street})" : "")).join(" • ")}'
                                    : schedule.barangay + (schedule.zone.isNotEmpty ? ' - ${schedule.zone}' : ''),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (schedule.assignedPersonnel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                schedule.assignedPersonnel,
                                style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

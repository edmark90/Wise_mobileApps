import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../design_system/widgets/app_card.dart';
import '../../models/collection_schedule.dart';
import '../../services/route_color_service.dart';
import 'status_timeline.dart';

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
    final routeColor = RouteColorService.getColorForSchedule(schedule).color;
    final liveStatus = deriveLiveStatus(schedule);
    final statusColor = scheduleStatusColor(liveStatus);
    final statusBgColor = scheduleStatusBgColor(liveStatus);
    final isFirst = cardIndex == 0;
    final hasStops = schedule.stops.isNotEmpty;
    final stopsCount = hasStops ? schedule.stops.length : 1;
    final timeParts = schedule.formattedTime.split(' ');
    final timeStr = timeParts.isNotEmpty ? timeParts.first : '';
    final ampmStr = timeParts.length > 1 ? timeParts.last : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        color: Colors.white,
        borderColor: isFirst ? routeColor.withValues(alpha: 0.3) : AppColors.border,
        borderWidth: 1,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left timeline accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      routeColor,
                      routeColor.withValues(alpha: 0.65),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),

              // Time column
              SizedBox(
                width: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (ampmStr.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border, width: 0.8),
                        ),
                        child: Text(
                          ampmStr,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Subtle vertical separator
              Container(
                width: 1,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),

              // Main route details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Route name, Truck & Status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              schedule.displayRouteName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (schedule.truckNumber.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: routeColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: routeColor.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_shipping_rounded, size: 11, color: routeColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    schedule.truckNumber,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: routeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              liveStatus,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Stop location preview
                      Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded, size: 13, color: AppColors.textTertiary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              hasStops
                                  ? '$stopsCount Stop${stopsCount > 1 ? 's' : ''}: ${schedule.stops.map((s) => s.barangay + (s.street.isNotEmpty ? " (${s.street})" : "")).join(" • ")}'
                                  : schedule.barangay + (schedule.zone.isNotEmpty ? ' - ${schedule.zone}' : ''),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Assigned personnel
                      if (schedule.assignedPersonnel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                schedule.assignedPersonnel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textTertiary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

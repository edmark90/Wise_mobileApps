import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/collection_schedule.dart';
import 'status_timeline.dart';

/// Bottom sheet with full details of a collection route assignment plus its collection stops list.
class ScheduleDetailSheet extends StatelessWidget {
  final CollectionSchedule schedule;
  final List<CollectionSchedule> allSchedules;

  const ScheduleDetailSheet({
    super.key,
    required this.schedule,
    required this.allSchedules,
  });

  @override
  Widget build(BuildContext context) {
    final stopsList = schedule.stops.isNotEmpty
        ? schedule.stops
        : [
            CollectionStop(
              id: 0,
              scheduleId: schedule.id,
              barangay: schedule.barangay,
              street: schedule.zone,
              sequence: 1,
              collectionTime: schedule.collectionTime,
              status: schedule.status,
            )
          ];

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
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: schedule.statusBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: schedule.statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'COLLECTION ASSIGNMENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AppColors.primary,
                            ),
                          ),
                          if (schedule.truckNumber.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                schedule.truckNumber,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule.routeName?.isNotEmpty == true
                            ? schedule.routeName!
                            : '${schedule.barangay} Route',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        schedule.formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Status timeline
                StatusTimeline(schedule: schedule),
                const SizedBox(height: 20),

                // Info Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        icon: Icons.local_shipping_outlined,
                        iconColor: const Color(0xFF2563EB),
                        label: 'TRUCK',
                        value: schedule.truckNumber.isNotEmpty ? schedule.truckNumber : 'Standard Fleet',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                        icon: Icons.person_outline_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        label: 'PERSONNEL',
                        value: schedule.assignedPersonnel.isNotEmpty ? schedule.assignedPersonnel : 'Unassigned',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Collection Stops Ordered List with Individual Times
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.format_list_numbered_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              const Text(
                                'Collection Stops & Schedule',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${stopsList.length} Stop${stopsList.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...stopsList.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final stop = entry.value;
                        final isFirst = idx == 0;
                        final isLast = idx == stopsList.length - 1;
                        final timeDisplay = stop.formattedTime.isNotEmpty ? stop.formattedTime : schedule.formattedTime;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? AppColors.primary
                                      : (isLast ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          stop.barangay,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (isFirst) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('START', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                                          ),
                                        ],
                                        if (isLast && stopsList.length > 1) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDBEAFE),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('END', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (stop.street.isNotEmpty)
                                      Text(
                                        stop.street,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (timeDisplay.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF1D4ED8)),
                                      const SizedBox(width: 4),
                                      Text(
                                        timeDisplay,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                if (schedule.remarks?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            schedule.remarks!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

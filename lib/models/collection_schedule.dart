import 'dart:ui' show Color;

/// A collection route/schedule returned by the API.
class CollectionSchedule {
  final int id;
  final String barangay;
  final String zone;
  final String collectionDate;
  final String collectionTime;
  final String assignedPersonnel;
  final String status;
  final String? remarks;

  const CollectionSchedule({
    required this.id,
    required this.barangay,
    required this.zone,
    required this.collectionDate,
    required this.collectionTime,
    required this.assignedPersonnel,
    required this.status,
    this.remarks,
  });

  factory CollectionSchedule.fromJson(Map<String, dynamic> json) {
    return CollectionSchedule(
      id: json['id'] ?? 0,
      barangay: json['barangay'] ?? '',
      zone: json['zone'] ?? '',
      collectionDate: json['collection_date'] ?? '',
      collectionTime: json['collection_time'] ?? '',
      assignedPersonnel: json['assigned_personnel'] ?? '',
      status: json['status'] ?? 'Upcoming',
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'barangay': barangay,
        'zone': zone,
        'collection_date': collectionDate,
        'collection_time': collectionTime,
        'assigned_personnel': assignedPersonnel,
        'status': status,
        'remarks': remarks,
      };

  String get formattedTime {
    if (collectionTime.isEmpty) return '';
    final parts = collectionTime.split(':');
    if (parts.length < 2) return collectionTime;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m $ampm';
  }

  String get formattedDate {
    if (collectionDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(collectionDate);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return '${days[dt.weekday % 7]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return collectionDate;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'Upcoming': return const Color(0xFF1E40AF);
      case 'Arriving': return const Color(0xFF92400E);
      case 'Arrived': return const Color(0xFF166534);
      case 'Delayed': return const Color(0xFF991B1B);
      case 'Completed': return const Color(0xFF15803D);
      case 'Cancelled': return const Color(0xFF4B5563);
      default: return const Color(0xFF6B7280);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case 'Upcoming': return const Color(0xFFEFF6FF);
      case 'Arriving': return const Color(0xFFFEF3C7);
      case 'Arrived': return const Color(0xFFF0FDF4);
      case 'Delayed': return const Color(0xFFFEF2F2);
      case 'Completed': return const Color(0xFFF0FDF4);
      case 'Cancelled': return const Color(0xFFF3F4F6);
      default: return const Color(0xFFF3F4F6);
    }
  }
}

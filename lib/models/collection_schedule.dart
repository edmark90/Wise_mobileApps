import 'dart:ui' show Color;

/// Normalizes any backend or notification status string into one of the
/// canonical schedule statuses:
/// `'Upcoming'`, `'Arriving'`, `'Arrived'`, `'Delayed'`, `'Completed'`, `'Cancelled'`.
String normalizeScheduleStatus(String raw) {
  final lower = raw.trim().toLowerCase();
  switch (lower) {
    case 'upcoming':
    case 'scheduled':
    case 'pending':
      return 'Upcoming';
    case 'arriving':
    case 'on the way':
    case 'en route':
    case 'approaching':
      return 'Arriving';
    case 'arrived':
    case 'ongoing':
    case 'in progress':
    case 'at stop':
    case 'active':
      return 'Arrived';
    case 'completed':
    case 'complete':
    case 'done':
    case 'finished':
      return 'Completed';
    case 'delayed':
    case 'rescheduled':
      return 'Delayed';
    case 'cancelled':
    case 'canceled':
      return 'Cancelled';
    default:
      return raw.trim().isEmpty ? 'Upcoming' : raw.trim();
  }
}

/// Foreground text/icon color for a schedule or stop status.
Color scheduleStatusColor(String status) {
  switch (normalizeScheduleStatus(status)) {
    case 'Upcoming':
      return const Color(0xFF1E40AF);
    case 'Arriving':
      return const Color(0xFF92400E);
    case 'Arrived':
      return const Color(0xFF0F766E);
    case 'Delayed':
      return const Color(0xFF991B1B);
    case 'Completed':
      return const Color(0xFF15803D);
    case 'Cancelled':
      return const Color(0xFF4B5563);
    default:
      return const Color(0xFF6B7280);
  }
}

/// Background pill color for a schedule or stop status.
Color scheduleStatusBgColor(String status) {
  switch (normalizeScheduleStatus(status)) {
    case 'Upcoming':
      return const Color(0xFFEFF6FF);
    case 'Arriving':
      return const Color(0xFFFEF3C7);
    case 'Arrived':
      return const Color(0xFFCCFBF1);
    case 'Delayed':
      return const Color(0xFFFEF2F2);
    case 'Completed':
      return const Color(0xFFDCFCE7);
    case 'Cancelled':
      return const Color(0xFFF3F4F6);
    default:
      return const Color(0xFFF3F4F6);
  }
}

/// A single collection stop inside a truck's collection assignment with its own collection time.
class CollectionStop {
  final int id;
  final int scheduleId;
  final String barangay;
  final String street;
  final int sequence;
  final String collectionTime;
  final String status;
  final String? remarks;

  const CollectionStop({
    required this.id,
    required this.scheduleId,
    required this.barangay,
    this.street = '',
    this.sequence = 1,
    this.collectionTime = '',
    this.status = 'Upcoming',
    this.remarks,
  });

  factory CollectionStop.fromJson(Map<String, dynamic> json) {
    return CollectionStop(
      id: json['id'] ?? 0,
      scheduleId: json['schedule_id'] ?? 0,
      barangay: json['barangay'] ?? '',
      street: json['street'] ?? '',
      sequence: json['sequence'] ?? 1,
      collectionTime: json['collection_time'] ?? '',
      status: normalizeScheduleStatus((json['status'] ?? 'Upcoming').toString()),
      remarks: json['remarks'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'schedule_id': scheduleId,
        'barangay': barangay,
        'street': street,
        'sequence': sequence,
        'collection_time': collectionTime,
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
}

/// A collection route/schedule assignment returned by the API.
class CollectionSchedule {
  final int id;
  final String barangay;
  final String zone;
  final String collectionDate;
  final String collectionTime;
  final String assignedPersonnel;
  final String truckNumber;
  final String? routeName;
  final String? startingPoint;
  final String status;
  final String? remarks;
  final List<CollectionStop> stops;

  const CollectionSchedule({
    required this.id,
    required this.barangay,
    required this.zone,
    required this.collectionDate,
    required this.collectionTime,
    required this.assignedPersonnel,
    this.truckNumber = '',
    this.routeName,
    this.startingPoint,
    required this.status,
    this.remarks,
    this.stops = const [],
  });

  factory CollectionSchedule.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>?;
    final parsedStops = rawStops != null
        ? rawStops.map((s) => CollectionStop.fromJson(s as Map<String, dynamic>)).toList()
        : <CollectionStop>[];

    return CollectionSchedule(
      id: json['id'] ?? 0,
      barangay: json['barangay'] ?? '',
      zone: json['zone'] ?? '',
      collectionDate: json['collection_date'] ?? '',
      collectionTime: json['collection_time'] ?? '',
      assignedPersonnel: json['assigned_personnel'] ?? '',
      truckNumber: json['truck_number'] ?? json['truck'] ?? '',
      routeName: json['route_name'] ?? json['route'],
      startingPoint: json['starting_point'],
      status: normalizeScheduleStatus((json['status'] ?? 'Upcoming').toString()),
      remarks: json['remarks'],
      stops: parsedStops,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'barangay': barangay,
        'zone': zone,
        'collection_date': collectionDate,
        'collection_time': collectionTime,
        'assigned_personnel': assignedPersonnel,
        'truck_number': truckNumber,
        if (routeName != null) 'route_name': routeName,
        if (startingPoint != null) 'starting_point': startingPoint,
        'status': status,
        'remarks': remarks,
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  /// Clean, concise route name without start/end stop chains.
  String get displayRouteName {
    final fallbackBarangay = barangay.trim().isNotEmpty
        ? barangay.trim()
        : (stops.isNotEmpty && stops.first.barangay.trim().isNotEmpty
            ? stops.first.barangay.trim()
            : 'Collection');
    final fallback = '$fallbackBarangay Route';

    var raw = (routeName ?? '').trim();
    if (raw.isEmpty) return fallback;

    // Remove parenthetical or bracketed start/end descriptions
    raw = raw.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim();
    raw = raw.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*'), ' ').trim();

    // If formatted like "Route 1: Start -> End", keep the route title before ':'
    if (raw.contains(':')) {
      final prefix = raw.split(':').first.trim();
      if (prefix.isNotEmpty &&
          !prefix.toLowerCase().startsWith('start') &&
          !prefix.toLowerCase().startsWith('from')) {
        raw = prefix;
      }
    }

    // If the string is a start-to-end chain (arrows or "to" or multiple dashes)
    final hasChain = raw.contains('→') ||
        raw.contains('->') ||
        raw.contains('—') ||
        RegExp(r'\b(start|end|from|to)\b', caseSensitive: false).hasMatch(raw);

    if (hasChain) {
      final firstPart = raw.split(RegExp(r'→|->|—|\s+-\s+|\s+to\s+', caseSensitive: false)).first.trim();
      if (firstPart.toLowerCase().contains('route')) {
        return firstPart;
      }
      return fallback;
    }

    // Also handle "Barangay A - Barangay B" start-end style when 'route' is not in the string
    if (raw.contains(' - ')) {
      final parts = raw.split(' - ').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        if (parts.first.toLowerCase().contains('route')) {
          return parts.first;
        }
        return fallback;
      }
    }

    return raw.isNotEmpty ? raw : fallback;
  }

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

  Color get statusColor => scheduleStatusColor(status);

  Color get statusBgColor => scheduleStatusBgColor(status);
}

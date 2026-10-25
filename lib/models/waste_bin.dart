import 'package:flutter/material.dart';

/// A standard waste bin with display name, color, and icons.
class WasteBin {
  final String name;
  final String tagalog;
  final Color color;
  final Color container;
  final IconData icon;
  final String emoji;

  const WasteBin({
    required this.name,
    required this.tagalog,
    required this.color,
    required this.container,
    required this.icon,
    required this.emoji,
  });

  static const WasteBin recyclable = WasteBin(
    name: 'Recyclable Waste',
    tagalog: 'Recyclable',
    color: Color(0xFF2563EB),
    container: Color(0xFFDBEAFE),
    icon: Icons.recycling_rounded,
    emoji: '♻️',
  );

  static const WasteBin biodegradable = WasteBin(
    name: 'Biodegradable Waste',
    tagalog: 'Biodegradable',
    color: Color(0xFF16A34A),
    container: Color(0xFFDCFCE7),
    icon: Icons.eco_rounded,
    emoji: '🌱',
  );

  static const WasteBin residual = WasteBin(
    name: 'Residual Waste',
    tagalog: 'Residual (Non-Recyclable)',
    color: Color(0xFF6B7280),
    container: Color(0xFFF3F4F6),
    icon: Icons.delete_outline_rounded,
    emoji: '🗑️',
  );

  static const WasteBin hazardous = WasteBin(
    name: 'Hazardous Waste',
    tagalog: 'Hazardous',
    color: Color(0xFFDC2626),
    container: Color(0xFFFEF2F2),
    icon: Icons.warning_amber_rounded,
    emoji: '☣️',
  );

  static const WasteBin eWaste = WasteBin(
    name: 'Electronic Waste (E-Waste)',
    tagalog: 'E-Waste',
    color: Color(0xFF7C3AED),
    container: Color(0xFFF3E8FF),
    icon: Icons.devices_rounded,
    emoji: '💻',
  );

  static const WasteBin special = WasteBin(
    name: 'Special Waste',
    tagalog: 'Special Waste',
    color: Color(0xFFEA580C),
    container: Color(0xFFFFF7ED),
    icon: Icons.category_rounded,
    emoji: '🟠',
  );

  static const WasteBin unknown = WasteBin(
    name: 'Unknown',
    tagalog: 'Unknown',
    color: Color(0xFF64748B),
    container: Color(0xFFF1F5F9),
    icon: Icons.help_outline_rounded,
    emoji: '⬜',
  );

  /// Matches e-waste keywords as a standalone "e" + "waste" term, e.g.
  /// "e-waste", "e waste", "ewaste". The leading `\b` prevents matching the
  /// trailing "...ble Waste" suffix of normal categories.
  static final RegExp _eWasteMatcher = RegExp(r'\be[\s-]?waste\b');

  /// Map a category label from the AI model to its standard waste bin.
  static WasteBin forCategory(String category) {
    final c = ' ${category.trim().toLowerCase()} ';

    // E-waste first, matched on the whole term so we do not hit
    // "Biodegradable Waste" (which ends in "...ble Waste").
    if (c.contains('electronic') || _eWasteMatcher.hasMatch(c)) {
      return eWaste;
    }
    if (c.contains('hazard') ||
        c.contains('toxic') ||
        c.contains('chemical') ||
        c.contains('danger')) {
      return hazardous;
    }
    // Negative/unrecyclable prefixes must win over the positive terms below.
    if (c.contains('non-bio') ||
        c.contains('non bio') ||
        c.contains('nonbio') ||
        c.contains('non-recycl') ||
        c.contains('non recycl') ||
        c.contains('nonrecycl') ||
        c.contains('resid')) {
      return residual;
    }
    if (c.contains('recycl')) return recyclable;
    if (c.contains('bio') || c.contains('organic') || c.contains('compost')) {
      return biodegradable;
    }
    if (c.contains('special')) return special;
    return unknown;
  }
}


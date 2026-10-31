import 'package:latlong2/latlong.dart';

/// Resolved map position with precision flags.
class GeocodedLocation {
  final LatLng position;
  final bool isExact;
  final bool isApproximate;

  const GeocodedLocation(
    this.position, {
    this.isExact = true,
    this.isApproximate = false,
  });
}

/// Offline geocoding registry for Muntinlupa City.
///
/// Every coordinate below is copied verbatim from the website's `route-map.js`
/// (`BARANGAY_COORDS` / `LANDMARK_COORDS`) and the backend's
/// `apps/services/map_coordinates.py`. Keeping the three registries identical is
/// what makes the mobile route line pass through exactly the stops the website
/// routes through - any drift here bends the requested road route somewhere else.
class MuntinlupaGeocoding {
  MuntinlupaGeocoding._();

  /// Default Truck Dispatch Depot - Arandia Street, Barangay Tunasan.
  static const LatLng depotPosition = LatLng(14.384538, 121.051391);

  /// Official centroid coordinates for the 9 Muntinlupa barangays.
  static const Map<String, LatLng> barangayCoordinates = {
    'Sucat': LatLng(14.45698, 121.05316),
    'Buli': LatLng(14.44330, 121.05058),
    'Cupang': LatLng(14.43788, 121.05032),
    'Alabang': LatLng(14.41903, 121.04434),
    'Ayala Alabang': LatLng(14.42261, 121.02694),
    'New Alabang Village': LatLng(14.42261, 121.02694),
    'Bayanan': LatLng(14.41095, 121.05163),
    'Putatan': LatLng(14.39497, 121.04483),
    'Poblacion': LatLng(14.38923, 121.04491),
    'Tunasan': LatLng(14.38011, 121.05148),
  };

  /// Verified landmark and street coordinates, keyed "Barangay|Street".
  static const Map<String, LatLng> landmarkCoordinates = {
    'Alabang|Alabang Public Market': LatLng(14.41928, 121.04453),
    'Alabang|Alabang Market': LatLng(14.41928, 121.04453),
    'Alabang|Muntinlupa City Public Market': LatLng(14.41928, 121.04453),
    'Alabang|Festival Mall': LatLng(14.41673, 121.04078),
    'Alabang|Asian Hospital and Medical Center': LatLng(14.41317, 121.04356),
    'Alabang|Alabang Town Center': LatLng(14.42423, 121.03209),
    'Alabang|Filinvest City Central Park': LatLng(14.41690, 121.03574),
    'Alabang|Filinvest Covered Court': LatLng(14.41289, 121.04428),
    'Alabang|Northgate Cyberzone': LatLng(14.42508, 121.03895),
    'Alabang|South Station': LatLng(14.42132, 121.04278),
    'Alabang|St. Jerome Emiliani and Sta. Susana Parish': LatLng(14.42208, 121.03162),
    'Alabang|Saint Jerome Emiliani': LatLng(14.42208, 121.03162),
    'Alabang|Zone 1': LatLng(14.42100, 121.04400),
    'Alabang|Zone 2': LatLng(14.41800, 121.04200),
    'New Alabang Village|New Alabang Village (Ayala Alabang)': LatLng(14.42261, 121.02694),
    'New Alabang Village|Ayala Alabang Barangay Hall': LatLng(14.41832, 121.02435),
    'New Alabang Village|Alabang Country Club': LatLng(14.40247, 121.02210),
    'New Alabang Village|The Palms Country Club': LatLng(14.41071, 121.03460),
    'New Alabang Village|San James the Great Parish': LatLng(14.39160, 121.01412),
    'New Alabang Village|Saint James the Great Parish': LatLng(14.39160, 121.01412),
    'New Alabang Village|Molito Lifestyle Center': LatLng(14.42432, 121.02677),
    'New Alabang Village|Madrigal Avenue': LatLng(14.42306, 121.02707),
    'New Alabang Village|Acacia Avenue': LatLng(14.39929, 121.01326),
    'New Alabang Village|Molave Street': LatLng(14.41664, 121.02188),
    'New Alabang Village|Narra Street': LatLng(14.41258, 121.02033),
    'New Alabang Village|Yakal Street': LatLng(14.42178, 121.02569),
    'New Alabang Village|Zone 1': LatLng(14.42300, 121.02700),
    'New Alabang Village|Zone 2': LatLng(14.41800, 121.02400),
    'Ayala Alabang|New Alabang Village (Ayala Alabang)': LatLng(14.42261, 121.02694),
    'Ayala Alabang|Ayala Alabang Barangay Hall': LatLng(14.41832, 121.02435),
    'Ayala Alabang|Alabang Country Club': LatLng(14.40247, 121.02210),
    'Ayala Alabang|The Palms Country Club': LatLng(14.41071, 121.03460),
    'Ayala Alabang|San James the Great Parish': LatLng(14.39160, 121.01412),
    'Ayala Alabang|Saint James the Great Parish': LatLng(14.39160, 121.01412),
    'Ayala Alabang|Molito Lifestyle Center': LatLng(14.42432, 121.02677),
    'Ayala Alabang|Madrigal Avenue': LatLng(14.42306, 121.02707),
    'Ayala Alabang|Acacia Avenue': LatLng(14.39929, 121.01326),
    'Ayala Alabang|Molave Street': LatLng(14.41664, 121.02188),
    'Ayala Alabang|Narra Street': LatLng(14.41258, 121.02033),
    'Ayala Alabang|Yakal Street': LatLng(14.42178, 121.02569),
    'Ayala Alabang|Zone 1': LatLng(14.42300, 121.02700),
    'Ayala Alabang|Zone 2': LatLng(14.41800, 121.02400),
    'Bayanan|Bayanan Barangay Hall': LatLng(14.41141, 121.05130),
    'Bayanan|Bayanan Public Market': LatLng(14.41095, 121.05163),
    'Bayanan|Bayanan Covered Court': LatLng(14.41095, 121.05163),
    'Bayanan|Bayanan Health Center': LatLng(14.41095, 121.05163),
    'Bayanan|Bayanan Elementary School': LatLng(14.40696, 121.04527),
    'Bayanan|Bayanan National High School': LatLng(14.41095, 121.05163),
    'Bayanan|National Road': LatLng(14.40957, 121.04628),
    'Bayanan|Bayanan Road': LatLng(14.41095, 121.05163),
    'Bayanan|San Guillermo Chapel': LatLng(14.40702, 121.05003),
    'Bayanan|Bayanan Multi-Purpose Hall': LatLng(14.41095, 121.05163),
    'Bayanan|Zone 1': LatLng(14.41100, 121.05100),
    'Bayanan|Zone 2': LatLng(14.40900, 121.04800),
    'Buli|Buli': LatLng(14.44330, 121.05058),
    'Buli|Buli Barangay Hall': LatLng(14.44330, 121.05058),
    'Buli|Buli Covered Court': LatLng(14.44335, 121.04804),
    'Buli|Buli Health Center': LatLng(14.44330, 121.05058),
    'Buli|Buli Elementary School': LatLng(14.44335, 121.04804),
    'Buli|Marina Road': LatLng(14.44350, 121.04950),
    'Buli|Buli Road': LatLng(14.44330, 121.05058),
    'Buli|East Service Road': LatLng(14.44555, 121.04548),
    'Buli|Lakefront Area': LatLng(14.45020, 121.05100),
    'Buli|Buli Multi-Purpose Hall': LatLng(14.44330, 121.05058),
    'Buli|Buli Concepcion Road': LatLng(14.44330, 121.05058),
    'Buli|Zone 1': LatLng(14.44400, 121.04900),
    'Buli|Zone 2': LatLng(14.44200, 121.05100),
    'Cupang|Barangay Cupang Hall (NEW)': LatLng(14.43893, 121.05131),
    'Cupang|Old Barangay Cupang Hall': LatLng(14.43788, 121.05032),
    'Cupang|Barangay Cupang Multi-Purpose Hall': LatLng(14.43788, 121.05032),
    'Cupang|Cupang Covered Court': LatLng(14.43788, 121.05032),
    'Cupang|Cupang Elementary School': LatLng(14.43040, 121.04949),
    'Cupang|Cupang Health Center': LatLng(14.43788, 121.05032),
    'Cupang|Soldiers Hills Road': LatLng(14.40011, 121.03921),
    'Cupang|Daang Hari Road': LatLng(14.42340, 121.02256),
    'Cupang|East Service Road': LatLng(14.43577, 121.04557),
    'Cupang|Posadas Open Area': LatLng(14.45940, 121.04869),
    'Cupang|Zone 1': LatLng(14.43800, 121.05000),
    'Cupang|Zone 2': LatLng(14.43500, 121.04800),
    'Poblacion|Barangay Poblacion Hall': LatLng(14.38923, 121.04491),
    'Poblacion|Muntinlupa Central Market': LatLng(14.38992, 121.04808),
    'Poblacion|Southville 3 Covered Court': LatLng(14.37185, 121.02370),
    'Poblacion|KVHAI Covered Court': LatLng(14.38508, 121.02261),
    'Poblacion|Covered Court': LatLng(14.38508, 121.02261),
    'Poblacion|Muntinlupa City Hall': LatLng(14.39511, 121.04419),
    'Poblacion|Medical Center Muntinlupa': LatLng(14.39496, 121.04520),
    'Poblacion|National Road': LatLng(14.38836, 121.04541),
    'Poblacion|Rizal Street': LatLng(14.38992, 121.04808),
    'Poblacion|Katarungan Road': LatLng(14.38508, 121.02261),
    'Poblacion|Zone 1': LatLng(14.39000, 121.04600),
    'Poblacion|Zone 2': LatLng(14.38700, 121.04400),
    'Putatan|Barangay Putatan Barangay Hall': LatLng(14.39500, 121.04832),
    'Putatan|Mutual Homes 1&2 Covered Court': LatLng(14.40099, 121.03288),
    'Putatan|SMB Hills Covered Court': LatLng(14.39497, 121.04483),
    'Putatan|Puregold Putatan': LatLng(14.39831, 121.04637),
    'Putatan|Savemore Putatan': LatLng(14.39681, 121.04418),
    'Putatan|Pedro Diaz Street': LatLng(14.39223, 121.04199),
    'Putatan|Country Homes Avenue': LatLng(14.39125, 121.04463),
    'Putatan|Putatan Health Center': LatLng(14.39497, 121.04483),
    'Putatan|Putatan Elementary School': LatLng(14.39433, 121.05009),
    'Putatan|National Road': LatLng(14.39722, 121.04511),
    'Putatan|Zone 1': LatLng(14.39600, 121.04600),
    'Putatan|Zone 2': LatLng(14.39300, 121.04300),
    'Sucat|Sucat': LatLng(14.45698, 121.05316),
    'Sucat|Sucat Barangay Hall': LatLng(14.45680, 121.05358),
    'Sucat|Sucat Multi-Purpose Covered Court': LatLng(14.45698, 121.05316),
    'Sucat|Bagong Silang Plaza Covered Court': LatLng(14.44482, 121.04257),
    'Sucat|Sitio Pagkakaisa Covered Court': LatLng(14.46608, 121.04709),
    'Sucat|Lakefront Open Area': LatLng(14.46632, 121.05422),
    'Sucat|Dr. A. Santos Avenue': LatLng(14.45361, 121.04565),
    'Sucat|East Service Road': LatLng(14.44977, 121.04547),
    'Sucat|West Service Road': LatLng(14.44790, 121.04516),
    'Sucat|Sucat Health Center': LatLng(14.45698, 121.05316),
    'Sucat|Sucat Elementary School': LatLng(14.45754, 121.05269),
    'Sucat|Zone 1': LatLng(14.45700, 121.05200),
    'Sucat|Zone 2': LatLng(14.45400, 121.04800),
    'Tunasan|Tunasan Barangay Hall': LatLng(14.37684, 121.04791),
    'Tunasan|Tunasan Covered Court': LatLng(14.38011, 121.05148),
    'Tunasan|Covered Court': LatLng(14.38011, 121.05148),
    "Tunasan|Tunasan People's Market": LatLng(14.37567, 121.04759),
    'Tunasan|Tunasan Health Center': LatLng(14.38011, 121.05148),
    'Tunasan|Tunasan Elementary School': LatLng(14.38105, 121.05149),
    'Tunasan|National Road': LatLng(14.38739, 121.04543),
    'Tunasan|Rodriguez Street': LatLng(14.37768, 121.04953),
    'Tunasan|Buendia Street': LatLng(14.37956, 121.05250),
    'Tunasan|Golden Gate Park Homes': LatLng(14.37502, 121.04505),
    'Tunasan|Zone 1': LatLng(14.38000, 121.05000),
    'Tunasan|Zone 2': LatLng(14.37700, 121.04800),
  };

  /// Mirrors the website's `resolveStopCoords` and the backend's
  /// `resolve_stop_coords`, in the same precedence order:
  ///
  ///  1. exact "Barangay|Street" key
  ///  2. case-insensitive partial match, registry order preserved
  ///  3. barangay centroid (flagged approximate)
  ///  4. `null` - unresolved, so no invented waypoint can bend the route
  static GeocodedLocation? resolve({
    required String barangay,
    String street = '',
  }) {
    final bNorm = barangay.trim();
    final sNorm = street.trim();

    var bLookup = bNorm;
    if (RegExp(r'ayala\s*alabang', caseSensitive: false).hasMatch(bLookup)) {
      bLookup = 'New Alabang Village';
    }
    bLookup = bLookup
        .replaceFirst(RegExp(r'^barangay\s+', caseSensitive: false), '')
        .trim();

    // 1. Direct landmark / street match.
    if (bLookup.isNotEmpty && sNorm.isNotEmpty) {
      final direct = landmarkCoordinates['$bLookup|$sNorm'] ??
          landmarkCoordinates['$bNorm|$sNorm'];
      if (direct != null) return GeocodedLocation(direct, isExact: true);
    }

    // 2. Case-insensitive partial match in registry order.
    if (sNorm.isNotEmpty) {
      final sLower = sNorm.toLowerCase();
      final bLowerLookup = bLookup.toLowerCase();
      final bLowerNorm = bNorm.toLowerCase();
      for (final entry in landmarkCoordinates.entries) {
        final separator = entry.key.indexOf('|');
        if (separator < 0) continue;
        final bPart = entry.key.substring(0, separator).toLowerCase();
        final sPart = entry.key.substring(separator + 1).toLowerCase();
        final bMatches = bLookup.isEmpty ||
            bPart == bLowerLookup ||
            bPart == bLowerNorm;
        if (bMatches &&
            (sPart == sLower ||
                sPart.contains(sLower) ||
                sLower.contains(sPart))) {
          return GeocodedLocation(entry.value, isExact: true);
        }
      }
    }

    // 3. Barangay centroid fallback (approximate).
    final centroid = barangayCoordinates[bLookup] ?? barangayCoordinates[bNorm];
    if (centroid != null) {
      return GeocodedLocation(centroid, isExact: false, isApproximate: true);
    }

    // 4. Unresolved - the caller drops this stop from the waypoint chain.
    return null;
  }
}

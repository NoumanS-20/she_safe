enum ZoneType { green, yellow, red }

class CrimeZone {
  final String name;
  final int totalCrime;
  final int districtCount;
  final double avgPerDistrict;
  final String zone;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const CrimeZone({
    required this.name,
    required this.totalCrime,
    required this.districtCount,
    required this.avgPerDistrict,
    required this.zone,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  ZoneType get zoneType => switch (zone.toUpperCase()) {
    'RED' => ZoneType.red,
    'YELLOW' => ZoneType.yellow,
    _ => ZoneType.green,
  };

  String get riskLabel => switch (zoneType) {
    ZoneType.red => 'HIGH RISK',
    ZoneType.yellow => 'MODERATE RISK',
    ZoneType.green => 'LOW RISK',
  };
}

class ZoneThresholds {
  final int yellowMinTotalCrime;
  final int redMinTotalCrime;

  const ZoneThresholds({
    required this.yellowMinTotalCrime,
    required this.redMinTotalCrime,
  });
}

class ZoneData {
  final String source;
  final String metric;
  final String classificationBasis;
  final ZoneThresholds thresholds;
  final List<CrimeZone> states;

  const ZoneData({
    required this.source,
    required this.metric,
    required this.classificationBasis,
    required this.thresholds,
    required this.states,
  });
}

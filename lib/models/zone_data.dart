enum ZoneType { green, yellow, red }

class DistrictZone {
  final String state;
  final String district;
  final double crimeRate;
  final String zone;
  final double latitude;
  final double longitude;

  const DistrictZone({
    required this.state,
    required this.district,
    required this.crimeRate,
    required this.zone,
    required this.latitude,
    required this.longitude,
  });

  ZoneType get zoneType => switch (zone.toUpperCase()) {
    'RED' => ZoneType.red,
    'YELLOW' => ZoneType.yellow,
    _ => ZoneType.green,
  };
}

class ZoneData {
  final List<DistrictZone> districts;

  ZoneData({required this.districts});
}

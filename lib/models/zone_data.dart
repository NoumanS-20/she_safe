enum ZoneType { green, yellow, red }

class StateZone {
  final String name;
  final int totalCrime;
  final int districtCount;
  final double avgPerDistrict;
  final String zone;
  final double latitude;
  final double longitude;

  const StateZone({
    required this.name,
    required this.totalCrime,
    required this.districtCount,
    required this.avgPerDistrict,
    required this.zone,
    required this.latitude,
    required this.longitude,
  });

  ZoneType get zoneType => switch (zone) {
    'RED' => ZoneType.red,
    'YELLOW' => ZoneType.yellow,
    _ => ZoneType.green,
  };
}

class ZoneData {
  final String version;
  final String source;
  final List<StateZone> states;

  ZoneData({required this.version, required this.source, required this.states});

  factory ZoneData.fromJson(Map<String, dynamic> json, List<Map<String, double>> coordinates) {
    final states = (json['states'] as List).asMap().entries.map((entry) {
      final idx = entry.key;
      final s = entry.value as Map<String, dynamic>;
      final coord = idx < coordinates.length ? coordinates[idx] : {'lat': 20.0, 'lng': 78.0};
      return StateZone(
        name: s['name'] as String,
        totalCrime: s['totalCrime'] as int,
        districtCount: s['districtCount'] as int,
        avgPerDistrict: (s['avgPerDistrict'] as num).toDouble(),
        zone: s['zone'] as String,
        latitude: coord['lat']!,
        longitude: coord['lng']!,
      );
    }).toList();
    return ZoneData(version: json['version'], source: json['source'], states: states);
  }
}

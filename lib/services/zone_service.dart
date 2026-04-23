import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/zone_data.dart';

const Map<String, Map<String, double>> _districtCoordinates = {
  'Mumbai': {'lat': 19.0760, 'lng': 72.8777},
  'Pune': {'lat': 18.5204, 'lng': 73.8567},
  'Nagpur': {'lat': 21.1458, 'lng': 79.0882},
  'Sindhudurg': {'lat': 16.0967, 'lng': 73.5786},
  'Bengaluru': {'lat': 12.9716, 'lng': 77.5946},
  'Mysuru': {'lat': 12.2958, 'lng': 76.6394},
  'Udupi': {'lat': 13.3409, 'lng': 74.7421},
  'New Delhi': {'lat': 28.6139, 'lng': 77.2090},
  'South Delhi': {'lat': 28.4817, 'lng': 77.1904},
};

class ZoneService {
  ZoneData? _zoneData;

  ZoneData? get zoneData => _zoneData;

  Future<void> loadZoneData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/crime_data.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final List<DistrictZone> districts = [];
      json.forEach((stateName, districtsMap) {
        if (districtsMap is Map) {
          districtsMap.forEach((districtName, data) {
            final coord = _districtCoordinates[districtName] ?? {'lat': 20.0, 'lng': 78.0};
            districts.add(DistrictZone(
              state: stateName,
              district: districtName,
              crimeRate: (data['crime_rate'] as num).toDouble(),
              zone: data['zone'] as String,
              latitude: coord['lat']!,
              longitude: coord['lng']!,
            ));
          });
        }
      });

      _zoneData = ZoneData(districts: districts);
    } catch (e) {
      _zoneData = null;
    }
  }

  DistrictZone? getZoneForLocation(double lat, double lng) {
    if (_zoneData == null || _zoneData!.districts.isEmpty) return null;
    DistrictZone? nearest;
    double minDist = double.infinity;
    for (final distZone in _zoneData!.districts) {
      final dlat = distZone.latitude - lat;
      final dlng = distZone.longitude - lng;
      final dist = dlat * dlat + dlng * dlng;
      if (dist < minDist) {
        minDist = dist;
        nearest = distZone;
      }
    }
    return nearest;
  }
}

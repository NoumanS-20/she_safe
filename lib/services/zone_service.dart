import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/zone_data.dart';

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
            final lat = (data['lat'] as num?)?.toDouble() ?? 20.0;
            final lng = (data['lng'] as num?)?.toDouble() ?? 78.0;
            districts.add(DistrictZone(
              state: stateName,
              district: districtName,
              crimeRate: (data['crime_rate'] as num).toDouble(),
              zone: data['zone'] as String,
              latitude: lat,
              longitude: lng,
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

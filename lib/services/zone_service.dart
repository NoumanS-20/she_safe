import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/zone_data.dart';

/// Approximate center coordinates for each Indian state/UT.
const Map<String, Map<String, double>> _stateCoordinates = {
  'Andhra Pradesh': {'lat': 15.9129, 'lng': 79.7400},
  'Arunachal Pradesh': {'lat': 28.2180, 'lng': 94.7278},
  'Assam': {'lat': 26.2006, 'lng': 92.9376},
  'Bihar': {'lat': 25.0961, 'lng': 85.3131},
  'Chhattisgarh': {'lat': 21.2787, 'lng': 81.8661},
  'Goa': {'lat': 15.2993, 'lng': 74.1240},
  'Gujarat': {'lat': 22.2587, 'lng': 71.1924},
  'Haryana': {'lat': 29.0588, 'lng': 76.0856},
  'Himachal Pradesh': {'lat': 31.1048, 'lng': 77.1734},
  'Jharkhand': {'lat': 23.6102, 'lng': 85.2799},
  'Karnataka': {'lat': 15.3173, 'lng': 75.7139},
  'Kerala': {'lat': 10.8505, 'lng': 76.2711},
  'Madhya Pradesh': {'lat': 22.9734, 'lng': 78.6569},
  'Maharashtra': {'lat': 19.7515, 'lng': 75.7139},
  'Manipur': {'lat': 24.6637, 'lng': 93.9063},
  'Meghalaya': {'lat': 25.4670, 'lng': 91.3662},
  'Mizoram': {'lat': 23.1645, 'lng': 92.9376},
  'Nagaland': {'lat': 26.1584, 'lng': 94.5624},
  'Odisha': {'lat': 20.9517, 'lng': 85.0985},
  'Punjab': {'lat': 31.1471, 'lng': 75.3412},
  'Rajasthan': {'lat': 27.0238, 'lng': 74.2179},
  'Sikkim': {'lat': 27.5330, 'lng': 88.5122},
  'Tamil Nadu': {'lat': 11.1271, 'lng': 78.6569},
  'Telangana': {'lat': 18.1124, 'lng': 79.0193},
  'Tripura': {'lat': 23.9408, 'lng': 91.9882},
  'Uttar Pradesh': {'lat': 26.8467, 'lng': 80.9462},
  'Uttarakhand': {'lat': 30.0668, 'lng': 79.0193},
  'West Bengal': {'lat': 22.9868, 'lng': 87.8550},
  'A&N Islands': {'lat': 11.7401, 'lng': 92.6586},
  'Chandigarh': {'lat': 30.7333, 'lng': 76.7794},
  'D&N Haveli and Daman & Diu': {'lat': 20.1809, 'lng': 73.0169},
  'Delhi': {'lat': 28.7041, 'lng': 77.1025},
  'Jammu & Kashmir': {'lat': 33.7782, 'lng': 76.5762},
  'Ladakh': {'lat': 34.1526, 'lng': 77.5771},
  'Lakshadweep': {'lat': 10.5667, 'lng': 72.6417},
  'Puducherry': {'lat': 11.9416, 'lng': 79.8083},
};

class ZoneService {
  ZoneData? _zoneData;

  ZoneData? get zoneData => _zoneData;

  Future<void> loadZoneData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/zone_data.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final states = (json['states'] as List).map((s) {
        final name = s['name'] as String;
        final coord = _stateCoordinates[name] ?? {'lat': 20.0, 'lng': 78.0};
        return StateZone(
          name: name,
          totalCrime: s['totalCrime'] as int,
          districtCount: s['districtCount'] as int,
          avgPerDistrict: (s['avgPerDistrict'] as num).toDouble(),
          zone: s['zone'] as String,
          latitude: coord['lat']!,
          longitude: coord['lng']!,
        );
      }).toList();

      _zoneData = ZoneData(
        version: json['version'] as String,
        source: json['source'] as String,
        states: states,
      );
    } catch (e) {
      _zoneData = null;
    }
  }

  StateZone? getZoneForLocation(double lat, double lng) {
    if (_zoneData == null) return null;
    // Simple: find nearest state center
    StateZone? nearest;
    double minDist = double.infinity;
    for (final state in _zoneData!.states) {
      final dlat = state.latitude - lat;
      final dlng = state.longitude - lng;
      final dist = dlat * dlat + dlng * dlng;
      if (dist < minDist) {
        minDist = dist;
        nearest = state;
      }
    }
    return nearest;
  }
}

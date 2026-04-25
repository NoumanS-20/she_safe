import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/zone_data.dart';

class ZoneService {
  ZoneData? _zoneData;

  ZoneData? get zoneData => _zoneData;

  Future<void> loadZoneData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/zone_data.json');
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final thresholdsJson =
          Map<String, dynamic>.from(json['thresholds'] as Map? ?? const {});
      final thresholdData = ZoneThresholds(
        yellowMinTotalCrime:
            (thresholdsJson['yellowMinTotalCrime'] as num?)?.toInt() ?? 0,
        redMinTotalCrime:
            (thresholdsJson['redMinTotalCrime'] as num?)?.toInt() ?? 0,
      );

      final statesJson = json['states'] as List<dynamic>? ?? const [];
      final states = statesJson.whereType<Map>().map((item) {
        final state = Map<String, dynamic>.from(item);
        return CrimeZone(
          name: state['name'] as String? ?? 'Unknown',
          totalCrime: (state['totalCrime'] as num?)?.toInt() ?? 0,
          districtCount: (state['districtCount'] as num?)?.toInt() ?? 0,
          avgPerDistrict:
              (state['avgPerDistrict'] as num?)?.toDouble() ?? 0,
          zone: state['zone'] as String? ?? 'GREEN',
          latitude: (state['lat'] as num?)?.toDouble() ?? 20.0,
          longitude: (state['lng'] as num?)?.toDouble() ?? 78.0,
          radiusMeters: (state['radiusMeters'] as num?)?.toDouble() ?? 70000,
        );
      }).toList();

      _zoneData = ZoneData(
        source: json['source'] as String? ?? 'Unknown',
        metric: json['metric'] as String? ?? 'Crimes Against Women',
        classificationBasis:
            json['classificationBasis'] as String? ?? 'Unknown',
        thresholds: thresholdData,
        states: states,
      );
    } catch (e) {
      _zoneData = null;
    }
  }

  CrimeZone? getZoneForLocation(double lat, double lng) {
    if (_zoneData == null || _zoneData!.states.isEmpty) return null;
    CrimeZone? nearest;
    double minDist = double.infinity;
    for (final zone in _zoneData!.states) {
      final dlat = zone.latitude - lat;
      final dlng = zone.longitude - lng;
      final dist = dlat * dlat + dlng * dlng;
      if (dist < minDist) {
        minDist = dist;
        nearest = zone;
      }
    }
    return nearest;
  }
}

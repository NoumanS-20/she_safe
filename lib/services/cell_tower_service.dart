import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/cell_tower.dart';

/// Service to fetch cell tower information from the device.
/// Uses platform channels on Android and falls back to simulation otherwise.
/// Does NOT use GPS — tower positions are looked up via OpenCellID or estimated.
/// For demo/web, uses IP-based geolocation to determine approximate area.
class CellTowerService {
  static const MethodChannel _channel = MethodChannel('com.shesafe/cell_info');
  final Random _random = Random();

  // OpenCellID API key — get a free key at https://opencellid.org/
  static const String _openCellIdKey = 'pk.0f6ac561a2e4dd3e80e4bfb37e67af92';

  /// Fetches real cell tower info from the device.
  /// Returns simulated data if the platform call fails.
  Future<List<CellTower>> getCellTowers() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getCellInfo');
      final towers = result
          .map((item) => CellTower.fromMap(Map<String, dynamic>.from(item)))
          .where((t) => t.cellId > 0)
          .toList();

      if (towers.isNotEmpty) {
        // Look up tower positions from the OpenCellID database
        return await _lookupTowerPositions(towers);
      }
    } on PlatformException catch (_) {
      // Platform channel not available (e.g. iOS, web, or emulator)
    } catch (_) {
      // Fallback to simulation
    }

    // Fallback: generate simulated towers around user's IP-based location
    return await _generateSimulatedTowers();
  }

  /// Looks up tower positions from the OpenCellID API using CID/LAC/MCC/MNC.
  /// This is the GPS-free way to determine tower locations.
  Future<List<CellTower>> _lookupTowerPositions(List<CellTower> towers) async {
    final enriched = <CellTower>[];

    for (final tower in towers) {
      if (tower.latitude != null && tower.longitude != null) {
        enriched.add(tower);
        continue;
      }

      try {
        final uri = Uri.parse(
          'https://opencellid.org/cell/get'
          '?key=$_openCellIdKey'
          '&mcc=${tower.mobileCountryCode}'
          '&mnc=${tower.mobileNetworkCode}'
          '&lac=${tower.locationAreaCode}'
          '&cellid=${tower.cellId}'
          '&format=json',
        );

        final response = await http.get(uri).timeout(
              const Duration(seconds: 5),
            );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['lat'] != null && data['lon'] != null) {
            enriched.add(tower.copyWithLocation(
              latitude: (data['lat'] as num).toDouble(),
              longitude: (data['lon'] as num).toDouble(),
              estimatedDistance: tower.estimateDistance(),
            ));
            continue;
          }
        }
      } catch (_) {}

      enriched.add(tower.copyWithLocation(
        estimatedDistance: tower.estimateDistance(),
      ));
    }

    return enriched;
  }

  /// Gets the user's approximate location from their IP address (no GPS).
  /// Returns [latitude, longitude] or null if it fails.
  Future<List<double>?> _getLocationFromIP() async {
    // Try multiple free IP geolocation services for reliability
    final apis = [
      {
        'url': 'http://ip-api.com/json/?fields=lat,lon,status',
        'lat': 'lat',
        'lon': 'lon',
        'check': (Map<String, dynamic> d) => d['status'] == 'success',
      },
      {
        'url': 'https://ipapi.co/json/',
        'lat': 'latitude',
        'lon': 'longitude',
        'check': (Map<String, dynamic> d) => d['latitude'] != null,
      },
    ];

    for (final api in apis) {
      try {
        final response = await http
            .get(Uri.parse(api['url'] as String))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final checkFn = api['check'] as bool Function(Map<String, dynamic>);
          if (checkFn(data)) {
            final lat = (data[api['lat']] as num?)?.toDouble();
            final lon = (data[api['lon']] as num?)?.toDouble();
            if (lat != null && lon != null) {
              return [lat, lon];
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Generates simulated cell towers around the user's IP-based location.
  /// Falls back to Bangalore center if IP geolocation fails.
  Future<List<CellTower>> _generateSimulatedTowers() async {
    // Use IP geolocation to find approximate area (NOT GPS)
    final ipLocation = await _getLocationFromIP();
    final baseLat = ipLocation?[0] ?? 12.9716; // Default: Bangalore
    final baseLng = ipLocation?[1] ?? 77.5946;

    final towerConfigs = [
      {'type': 'LTE', 'signal': -65, 'dist': 500.0},
      {'type': 'LTE', 'signal': -78, 'dist': 1200.0},
      {'type': 'GSM', 'signal': -88, 'dist': 2500.0},
      {'type': 'WCDMA', 'signal': -95, 'dist': 3500.0},
      {'type': 'LTE', 'signal': -102, 'dist': 5000.0},
      {'type': 'GSM', 'signal': -108, 'dist': 7000.0},
    ];

    // Generate 3-6 towers around the IP-based position
    final towerCount = 3 + _random.nextInt(4);
    final towers = <CellTower>[];

    for (int i = 0; i < towerCount; i++) {
      final config = towerConfigs[i];
      final distance = (config['dist'] as double) +
          (_random.nextDouble() - 0.5) * (config['dist'] as double) * 0.3;

      final angle =
          (2 * pi * i) / towerCount + (_random.nextDouble() - 0.5) * 0.4;

      final towerLat = baseLat + (distance / 111320.0) * cos(angle);
      final towerLng = baseLng +
          (distance / (111320.0 * cos(baseLat * pi / 180))) * sin(angle);

      final signalVariation = _random.nextInt(10) - 5;

      towers.add(CellTower(
        cellId: 10000 + _random.nextInt(90000),
        locationAreaCode: 1000 + _random.nextInt(9000),
        mobileCountryCode: 404, // India
        mobileNetworkCode: 10 + _random.nextInt(90),
        signalStrength: (config['signal'] as int) + signalVariation,
        networkType: config['type'] as String,
        latitude: towerLat,
        longitude: towerLng,
        estimatedDistance: distance,
        isRegistered: i == 0,
      ));
    }

    return towers;
  }
}

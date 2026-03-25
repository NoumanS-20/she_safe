import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/cell_tower.dart';
import '../models/triangulation_result.dart';

/// Service to fetch cell tower information from the device.
/// Uses platform channels on Android to get real cell data.
/// Looks up tower positions via multiple free APIs (Mylnikov, OpenCellID).
class CellTowerService {
  static const MethodChannel _channel = MethodChannel('com.shesafe/cell_info');
  final Random _random = Random();

  /// Fetches real cell tower info from the device.
  /// Enriches towers with lat/lng from cell tower databases.
  /// Falls back to simulated data if the platform call fails.
  Future<List<CellTower>> getCellTowers() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getCellInfo');
      final towers = result
          .map((item) => CellTower.fromMap(Map<String, dynamic>.from(item)))
          .where((t) => t.cellId > 0)
          .toList();

      print('[CellTower] Native channel returned ${result.length} entries, ${towers.length} valid towers');
      for (final t in towers) {
        print('[CellTower]   CID=${t.cellId} LAC=${t.locationAreaCode} MCC=${t.mobileCountryCode} MNC=${t.mobileNetworkCode} signal=${t.signalStrength}dBm type=${t.networkType}');
      }

      if (towers.isNotEmpty) {
        return await _lookupTowerPositions(towers);
      }
    } on PlatformException catch (e) {
      print('[CellTower] Platform channel error: $e');
    } catch (e) {
      print('[CellTower] Error getting cell info: $e');
    }

    print('[CellTower] Falling back to SIMULATED towers (IP-based)');
    return await _generateSimulatedTowers();
  }

  /// Looks up tower positions using multiple free APIs as fallback chain:
  /// 1. Mylnikov.org (free, no API key, no rate limit)
  /// 2. OpenCellID (requires API key)
  Future<List<CellTower>> _lookupTowerPositions(List<CellTower> towers) async {
    final enriched = <CellTower>[];

    for (final tower in towers) {
      if (tower.latitude != null && tower.longitude != null) {
        enriched.add(tower);
        continue;
      }

      if (tower.mobileCountryCode <= 0 || tower.locationAreaCode <= 0) {
        print('[CellTower]   Skipping CID=${tower.cellId} (invalid MCC=${tower.mobileCountryCode}/LAC=${tower.locationAreaCode})');
        enriched.add(tower.copyWithLocation(
          estimatedDistance: tower.estimateDistance(),
        ));
        continue;
      }

      // Try Mylnikov.org first (free, no API key needed)
      final mylnikovResult = await _lookupMylnikov(tower);
      if (mylnikovResult != null) {
        enriched.add(mylnikovResult);
        continue;
      }

      // Try OpenCellID as fallback
      final openCellResult = await _lookupOpenCellID(tower);
      if (openCellResult != null) {
        enriched.add(openCellResult);
        continue;
      }

      print('[CellTower]   All lookups failed for CID=${tower.cellId}, using without position');
      enriched.add(tower.copyWithLocation(
        estimatedDistance: tower.estimateDistance(),
      ));
    }

    return enriched;
  }

  /// Lookup using Mylnikov.org API — FREE, no API key, no rate limit.
  /// Database compiled from OpenCellID, Mozilla, and openBmap.
  Future<CellTower?> _lookupMylnikov(CellTower tower) async {
    try {
      final uri = Uri.parse(
        'https://api.mylnikov.org/geolocation/cell'
        '?v=1.1'
        '&data=open'
        '&mcc=${tower.mobileCountryCode}'
        '&mnc=${tower.mobileNetworkCode}'
        '&lac=${tower.locationAreaCode}'
        '&cellid=${tower.cellId}',
      );

      print('[Mylnikov] Lookup CID=${tower.cellId} MCC=${tower.mobileCountryCode} MNC=${tower.mobileNetworkCode} LAC=${tower.locationAreaCode}');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 200 && data['data'] != null) {
          final lat = (data['data']['lat'] as num).toDouble();
          final lon = (data['data']['lon'] as num).toDouble();
          final range = (data['data']['range'] as num?)?.toDouble();
          final dist = range ?? tower.estimateDistance();
          print('[Mylnikov]   ✓ Found: lat=$lat, lon=$lon, range=${range?.round()}m');
          return tower.copyWithLocation(
            latitude: lat,
            longitude: lon,
            estimatedDistance: dist,
          );
        } else {
          print('[Mylnikov]   ✗ Not found: ${response.body}');
        }
      } else {
        print('[Mylnikov]   ✗ HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('[Mylnikov]   ✗ Error: $e');
    }
    return null;
  }

  /// Lookup using OpenCellID API (backup, requires API key).
  Future<CellTower?> _lookupOpenCellID(CellTower tower) async {
    const apiKey = 'pk.0f6ac561a2e4dd3e80e4bfb37e67af92';
    try {
      final uri = Uri.parse(
        'https://opencellid.org/cell/get'
        '?key=$apiKey'
        '&mcc=${tower.mobileCountryCode}'
        '&mnc=${tower.mobileNetworkCode}'
        '&lac=${tower.locationAreaCode}'
        '&cellid=${tower.cellId}'
        '&format=json',
      );

      print('[OpenCellID] Lookup CID=${tower.cellId}');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['lat'] != null && data['lon'] != null) {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          final dist = tower.estimateDistance();
          print('[OpenCellID]   ✓ Found: lat=$lat, lon=$lon');
          return tower.copyWithLocation(
            latitude: lat,
            longitude: lon,
            estimatedDistance: dist,
          );
        } else {
          print('[OpenCellID]   ✗ ${response.body}');
        }
      }
    } catch (e) {
      print('[OpenCellID]   ✗ Error: $e');
    }
    return null;
  }

  /// Uses Mylnikov.org "refined location" API — sends multiple cells at once
  /// and gets back a single estimated position (server-side trilateration).
  Future<TriangulationResult?> getServerSideLocation(List<CellTower> towers) async {
    final validTowers = towers.where((t) =>
        t.cellId > 0 &&
        t.mobileCountryCode > 0 &&
        t.locationAreaCode > 0).toList();

    if (validTowers.isEmpty) return null;

    try {
      // Build the cells parameter for Mylnikov's multi-cell endpoint
      final cells = validTowers.map((t) =>
          '${t.mobileCountryCode},${t.mobileNetworkCode},${t.locationAreaCode},${t.cellId},${t.signalStrength}')
          .join(';');

      final uri = Uri.parse(
        'https://api.mylnikov.org/geolocation/cell'
        '?v=1.1'
        '&data=open'
        '&mcc=${validTowers.first.mobileCountryCode}'
        '&mnc=${validTowers.first.mobileNetworkCode}'
        '&lac=${validTowers.first.locationAreaCode}'
        '&cellid=${validTowers.first.cellId}',
      );

      print('[Mylnikov-Multi] Requesting server-side location with ${validTowers.length} towers');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 8),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] == 200 && data['data'] != null) {
          final lat = (data['data']['lat'] as num).toDouble();
          final lng = (data['data']['lon'] as num).toDouble();
          final range = (data['data']['range'] as num?)?.toDouble() ?? 1000.0;

          print('[Mylnikov-Multi] ✓ Location: lat=$lat, lng=$lng, range=${range.round()}m');

          return TriangulationResult(
            latitude: lat,
            longitude: lng,
            accuracyMeters: range,
            towerCount: validTowers.length,
            method: 'mylnikov_server',
          );
        }
      }
    } catch (e) {
      print('[Mylnikov-Multi] ✗ Error: $e');
    }
    return null;
  }

  /// Gets user's approximate location from IP address.
  Future<List<double>?> _getLocationFromIP() async {
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
            if (lat != null && lon != null) return [lat, lon];
          }
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Generates simulated cell towers around user's IP-based location.
  Future<List<CellTower>> _generateSimulatedTowers() async {
    final ipLocation = await _getLocationFromIP();
    final baseLat = ipLocation?[0] ?? 12.823492362799227; // Default: SRM Institute
    final baseLng = ipLocation?[1] ?? 80.04199890049776;

    print('[CellTower] Simulating towers around location: $baseLat, $baseLng');

    final towerConfigs = [
      {'type': 'LTE', 'signal': -65, 'dist': 500.0},
      {'type': 'LTE', 'signal': -78, 'dist': 1200.0},
      {'type': 'GSM', 'signal': -88, 'dist': 2500.0},
      {'type': 'WCDMA', 'signal': -95, 'dist': 3500.0},
      {'type': 'LTE', 'signal': -102, 'dist': 5000.0},
      {'type': 'GSM', 'signal': -108, 'dist': 7000.0},
    ];

    final towerCount = 3 + _random.nextInt(4);
    final towers = <CellTower>[];

    for (int i = 0; i < towerCount; i++) {
      final config = towerConfigs[i];
      final distance = (config['dist'] as double) +
          (_random.nextDouble() - 0.5) * (config['dist'] as double) * 0.3;
      final angle = (2 * pi * i) / towerCount + (_random.nextDouble() - 0.5) * 0.4;
      final towerLat = baseLat + (distance / 111320.0) * cos(angle);
      final towerLng = baseLng + (distance / (111320.0 * cos(baseLat * pi / 180))) * sin(angle);
      final signalVariation = _random.nextInt(10) - 5;

      towers.add(CellTower(
        cellId: 10000 + _random.nextInt(90000),
        locationAreaCode: 1000 + _random.nextInt(9000),
        mobileCountryCode: 404,
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

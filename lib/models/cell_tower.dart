import 'dart:math';

/// Represents a cell tower with its identification, location, and signal data.
class CellTower {
  final int cellId;
  final int locationAreaCode;
  final int mobileCountryCode;
  final int mobileNetworkCode;
  final int signalStrength; // in dBm
  final String networkType; // LTE, GSM, WCDMA, CDMA, NR
  final double? latitude;
  final double? longitude;
  final double? estimatedDistance; // in meters
  final bool isRegistered;

  CellTower({
    required this.cellId,
    required this.locationAreaCode,
    required this.mobileCountryCode,
    required this.mobileNetworkCode,
    required this.signalStrength,
    required this.networkType,
    this.latitude,
    this.longitude,
    this.estimatedDistance,
    this.isRegistered = false,
  });

  /// Creates a CellTower from a map (platform channel data).
  factory CellTower.fromMap(Map<String, dynamic> map) {
    return CellTower(
      cellId: map['cellId'] as int? ?? -1,
      locationAreaCode: map['lac'] as int? ?? -1,
      mobileCountryCode: map['mcc'] as int? ?? -1,
      mobileNetworkCode: map['mnc'] as int? ?? -1,
      signalStrength: map['signalStrength'] as int? ?? -120,
      networkType: map['networkType'] as String? ?? 'Unknown',
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      isRegistered: map['isRegistered'] as bool? ?? false,
    );
  }

  /// Estimates distance from signal strength using the Log-Distance Path Loss Model
  /// with network-type-specific parameters.
  ///
  /// Uses a reference-distance model: d = d0 * 10^((P0 - RSSI) / (10 * n))
  /// where d0 = reference distance, P0 = expected RSSI at d0, n = path loss exponent.
  double estimateDistance() {
    if (estimatedDistance != null) return estimatedDistance!;

    // Network-type-specific propagation parameters
    // d0 = reference distance (meters), P0 = expected RSSI at d0 (dBm),
    // n = path loss exponent (urban environment)
    double referenceRSSI;
    double referenceDistance;
    double pathLossExponent;

    switch (networkType) {
      case 'LTE':
        referenceRSSI = -45.0;    // dBm expected at ~100m from LTE tower
        referenceDistance = 100.0; // meters
        pathLossExponent = 3.5;   // urban LTE propagation
        break;
      case 'GSM':
        referenceRSSI = -50.0;
        referenceDistance = 100.0;
        pathLossExponent = 3.2;
        break;
      case 'WCDMA':
        referenceRSSI = -48.0;
        referenceDistance = 100.0;
        pathLossExponent = 3.4;
        break;
      case 'NR':
        referenceRSSI = -44.0;
        referenceDistance = 50.0;
        pathLossExponent = 3.8;   // 5G higher frequency = faster attenuation
        break;
      case 'CDMA':
        referenceRSSI = -50.0;
        referenceDistance = 100.0;
        pathLossExponent = 3.3;
        break;
      default:
        referenceRSSI = -50.0;
        referenceDistance = 100.0;
        pathLossExponent = 3.5;
    }

    // Log-distance path loss model: d = d0 * 10^((P0 - RSSI) / (10 * n))
    double distance = referenceDistance * pow(
      10.0,
      (referenceRSSI - signalStrength) / (10.0 * pathLossExponent),
    ).toDouble();

    // Clamp to reasonable cell tower range (100m - 35km)
    return distance.clamp(100.0, 35000.0);
  }

  /// Returns a copy with location data.
  CellTower copyWithLocation({
    double? latitude,
    double? longitude,
    double? estimatedDistance,
  }) {
    return CellTower(
      cellId: cellId,
      locationAreaCode: locationAreaCode,
      mobileCountryCode: mobileCountryCode,
      mobileNetworkCode: mobileNetworkCode,
      signalStrength: signalStrength,
      networkType: networkType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      isRegistered: isRegistered,
    );
  }

  /// Returns signal quality as a percentage (0-100).
  int get signalQuality {
    // Map dBm to percentage: -50 dBm = 100%, -120 dBm = 0%
    return ((signalStrength + 120) / 70 * 100).clamp(0, 100).round();
  }

  /// Returns a human-readable signal level description.
  String get signalLevel {
    if (signalStrength >= -70) return 'Excellent';
    if (signalStrength >= -85) return 'Good';
    if (signalStrength >= -100) return 'Fair';
    if (signalStrength >= -110) return 'Poor';
    return 'Very Poor';
  }

  @override
  String toString() {
    return 'CellTower(id: $cellId, type: $networkType, signal: ${signalStrength}dBm, '
        'quality: $signalQuality%, lat: $latitude, lng: $longitude)';
  }
}

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

  /// Estimates distance from signal strength using the Log-Distance Path Loss Model.
  /// RSSI = TxPower - 10 * n * log10(d / d0) + noise
  /// Where n = path loss exponent (2-4 for urban), d0 = reference distance (1m)
  double estimateDistance() {
    if (estimatedDistance != null) return estimatedDistance!;

    // Reference power at 1 meter (typical for cell towers)
    const double txPower = -30.0; // dBm at 1 meter reference
    // Path loss exponent (2 = free space, 2.7-3.5 urban, 4-6 indoor)
    const double pathLossExponent = 3.0;

    double distance = pow(
      10.0,
      (txPower - signalStrength) / (10.0 * pathLossExponent),
    ).toDouble();

    // Clamp to reasonable range (50m - 35km)
    return distance.clamp(50.0, 35000.0);
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

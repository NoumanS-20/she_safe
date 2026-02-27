/// The result of a triangulation computation.
class TriangulationResult {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int towerCount;
  final DateTime timestamp;
  final String method; // 'trilateration', 'centroid', 'single_tower'

  TriangulationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.towerCount,
    required this.method,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Accuracy level description.
  String get accuracyLevel {
    if (accuracyMeters < 200) return 'High';
    if (accuracyMeters < 500) return 'Medium';
    if (accuracyMeters < 1500) return 'Low';
    return 'Very Low';
  }

  @override
  String toString() {
    return 'TriangulationResult(lat: $latitude, lng: $longitude, '
        'accuracy: ${accuracyMeters.round()}m, towers: $towerCount, method: $method)';
  }
}

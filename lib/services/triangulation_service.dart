import 'dart:math';
import '../models/cell_tower.dart';
import '../models/triangulation_result.dart';

/// Service that performs cell tower triangulation using various algorithms.
class TriangulationService {
  static const double _earthRadius = 6371000.0; // meters

  /// Performs triangulation using available towers.
  /// Automatically selects the best algorithm based on tower count.
  TriangulationResult? triangulate(List<CellTower> towers) {
    // Filter towers that have location data
    final towersWithLocation =
        towers.where((t) => t.latitude != null && t.longitude != null).toList();

    if (towersWithLocation.isEmpty) return null;

    if (towersWithLocation.length == 1) {
      return _singleTowerEstimate(towersWithLocation.first);
    }

    if (towersWithLocation.length == 2) {
      return _twoTowerEstimate(towersWithLocation);
    }

    // 3 or more towers — use trilateration
    return _trilaterate(towersWithLocation);
  }

  /// Single tower: position is at the tower with large uncertainty.
  TriangulationResult _singleTowerEstimate(CellTower tower) {
    final distance = tower.estimateDistance();
    return TriangulationResult(
      latitude: tower.latitude!,
      longitude: tower.longitude!,
      accuracyMeters: distance,
      towerCount: 1,
      method: 'single_tower',
    );
  }

  /// Two towers: weighted midpoint based on signal strength.
  TriangulationResult _twoTowerEstimate(List<CellTower> towers) {
    final d1 = towers[0].estimateDistance();
    final d2 = towers[1].estimateDistance();
    final totalD = d1 + d2;

    // Weight inversely proportional to distance
    final w1 = 1.0 - (d1 / totalD);
    final w2 = 1.0 - (d2 / totalD);
    final totalW = w1 + w2;

    final lat =
        (towers[0].latitude! * w1 + towers[1].latitude! * w2) / totalW;
    final lng =
        (towers[0].longitude! * w1 + towers[1].longitude! * w2) / totalW;

    return TriangulationResult(
      latitude: lat,
      longitude: lng,
      accuracyMeters: (d1 + d2) / 2,
      towerCount: 2,
      method: 'weighted_midpoint',
    );
  }

  /// Trilateration using 3+ towers.
  /// Uses a nonlinear least squares approach projected to a local Cartesian plane.
  TriangulationResult _trilaterate(List<CellTower> towers) {
    // Use the first tower as the origin for local coordinate conversion
    final originLat = towers[0].latitude!;
    final originLng = towers[0].longitude!;

    // Convert tower positions to local XY (meters) relative to origin
    List<_Point> towerPositions = [];
    List<double> distances = [];

    for (final tower in towers) {
      final xy = _latLngToXY(tower.latitude!, tower.longitude!, originLat, originLng);
      towerPositions.add(xy);
      distances.add(tower.estimateDistance());
    }

    // Use least squares trilateration
    // For n circles, we linearize by subtracting the first equation from the rest:
    //   2*(x_i - x_1)*x + 2*(y_i - y_1)*y = d_1^2 - d_i^2 + x_i^2 - x_1^2 + y_i^2 - y_1^2
    
    if (towers.length >= 3) {
      final result = _leastSquaresTrilateration(towerPositions, distances);
      if (result != null) {
        final latLng = _xyToLatLng(result.x, result.y, originLat, originLng);

        // Estimate accuracy from residuals
        double residualSum = 0;
        for (int i = 0; i < towerPositions.length; i++) {
          final dx = result.x - towerPositions[i].x;
          final dy = result.y - towerPositions[i].y;
          final actualDist = sqrt(dx * dx + dy * dy);
          residualSum += (actualDist - distances[i]).abs();
        }
        final avgResidual = residualSum / towerPositions.length;

        return TriangulationResult(
          latitude: latLng.x, // lat stored in x
          longitude: latLng.y, // lng stored in y
          accuracyMeters: avgResidual.clamp(50.0, 10000.0),
          towerCount: towers.length,
          method: 'trilateration',
        );
      }
    }

    // Fallback to weighted centroid
    return _weightedCentroid(towers);
  }

  /// Least squares trilateration solver.
  _Point? _leastSquaresTrilateration(List<_Point> points, List<double> distances) {
    final n = points.length;
    if (n < 3) return null;

    // Build the system Ax = b using linearization
    // Subtract first equation from all others
    final x1 = points[0].x;
    final y1 = points[0].y;
    final d1 = distances[0];

    // We'll build an overdetermined system and solve using normal equations
    double ata00 = 0, ata01 = 0, ata11 = 0;
    double atb0 = 0, atb1 = 0;

    for (int i = 1; i < n; i++) {
      final xi = points[i].x;
      final yi = points[i].y;
      final di = distances[i];

      final a = 2.0 * (xi - x1);
      final b = 2.0 * (yi - y1);
      final c = d1 * d1 - di * di + xi * xi - x1 * x1 + yi * yi - y1 * y1;

      ata00 += a * a;
      ata01 += a * b;
      ata11 += b * b;
      atb0 += a * c;
      atb1 += b * c;
    }

    // Solve 2x2 system using Cramer's rule
    final det = ata00 * ata11 - ata01 * ata01;
    if (det.abs() < 1e-10) return null; // Singular matrix

    final x = (ata11 * atb0 - ata01 * atb1) / det;
    final y = (ata00 * atb1 - ata01 * atb0) / det;

    return _Point(x, y);
  }

  /// Weighted centroid fallback.
  TriangulationResult _weightedCentroid(List<CellTower> towers) {
    double totalWeight = 0;
    double weightedLat = 0;
    double weightedLng = 0;

    for (final tower in towers) {
      // Weight = 1 / distance^2
      final d = tower.estimateDistance();
      final weight = 1.0 / (d * d);
      weightedLat += tower.latitude! * weight;
      weightedLng += tower.longitude! * weight;
      totalWeight += weight;
    }

    return TriangulationResult(
      latitude: weightedLat / totalWeight,
      longitude: weightedLng / totalWeight,
      accuracyMeters: towers.map((t) => t.estimateDistance()).reduce(min) * 0.8,
      towerCount: towers.length,
      method: 'weighted_centroid',
    );
  }

  /// Convert lat/lng to local XY coordinates (meters) relative to an origin.
  _Point _latLngToXY(double lat, double lng, double originLat, double originLng) {
    final originLatRad = originLat * pi / 180;

    final x = (lng - originLng) * pi / 180 * _earthRadius * cos(originLatRad);
    final y = (lat - originLat) * pi / 180 * _earthRadius;

    return _Point(x, y);
  }

  /// Convert local XY back to lat/lng.
  _Point _xyToLatLng(double x, double y, double originLat, double originLng) {
    final originLatRad = originLat * pi / 180;

    final lat = originLat + (y / _earthRadius) * 180 / pi;
    final lng = originLng + (x / (_earthRadius * cos(originLatRad))) * 180 / pi;

    return _Point(lat, lng);
  }

  /// Calculate distance between two lat/lng points using Haversine formula.
  static double haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadius * c;
  }
}

/// Simple 2D point helper.
class _Point {
  final double x;
  final double y;

  _Point(this.x, this.y);
}

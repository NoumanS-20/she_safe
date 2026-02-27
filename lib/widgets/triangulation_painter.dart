import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cell_tower.dart';
import '../models/triangulation_result.dart';

/// Custom painter that draws the triangulation visualization.
/// Shows tower positions, signal radius circles, intersection area, and estimated position.
class TriangulationPainter extends CustomPainter {
  final List<CellTower> towers;
  final TriangulationResult? result;
  final double animationValue;

  TriangulationPainter({
    required this.towers,
    this.result,
    this.animationValue = 1.0,
  });

  static const List<Color> towerColors = [
    Color(0xFFE53935), // Red
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFFFB8C00), // Orange
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (towers.isEmpty) return;

    final towersWithLoc =
        towers.where((t) => t.latitude != null && t.longitude != null).toList();
    if (towersWithLoc.isEmpty) return;

    // Calculate bounds
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;

    for (final tower in towersWithLoc) {
      minLat = min(minLat, tower.latitude!);
      maxLat = max(maxLat, tower.latitude!);
      minLng = min(minLng, tower.longitude!);
      maxLng = max(maxLng, tower.longitude!);
    }

    if (result != null) {
      minLat = min(minLat, result!.latitude);
      maxLat = max(maxLat, result!.latitude);
      minLng = min(minLng, result!.longitude);
      maxLng = max(maxLng, result!.longitude);
    }

    // Add padding
    final latPad = (maxLat - minLat) * 0.25 + 0.001;
    final lngPad = (maxLng - minLng) * 0.25 + 0.001;
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;

    // Convert lat/lng to screen coordinates
    Offset toScreen(double lat, double lng) {
      final x = (lng - minLng) / (maxLng - minLng) * size.width;
      final y = (1 - (lat - minLat) / (maxLat - minLat)) * size.height;
      return Offset(x, y);
    }

    // Scale factor: meters to pixels (approximate)
    final metersPerDegLat = 111320.0;
    final centerLat = (minLat + maxLat) / 2;
    final metersPerDegLng = 111320.0 * cos(centerLat * pi / 180);
    final pixelsPerMeterX = size.width / ((maxLng - minLng) * metersPerDegLng);
    final pixelsPerMeterY =
        size.height / ((maxLat - minLat) * metersPerDegLat);
    final pixelsPerMeter = min(pixelsPerMeterX, pixelsPerMeterY);

    // Draw grid
    _drawGrid(canvas, size);

    // Draw signal radius circles
    for (int i = 0; i < towersWithLoc.length; i++) {
      final tower = towersWithLoc[i];
      final center = toScreen(tower.latitude!, tower.longitude!);
      final radiusPixels = tower.estimateDistance() * pixelsPerMeter * animationValue;
      final color = towerColors[i % towerColors.length];

      // Circle fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radiusPixels, fillPaint);

      // Dashed circle border
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radiusPixels, borderPaint);
    }

    // Draw lines from towers to estimated position
    if (result != null) {
      final estPos = toScreen(result!.latitude, result!.longitude);
      for (int i = 0; i < towersWithLoc.length; i++) {
        final tower = towersWithLoc[i];
        final towerPos = toScreen(tower.latitude!, tower.longitude!);
        final color = towerColors[i % towerColors.length];

        final linePaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round;

        _drawDashedLine(canvas, towerPos, estPos, linePaint);
      }
    }

    // Draw tower markers
    for (int i = 0; i < towersWithLoc.length; i++) {
      final tower = towersWithLoc[i];
      final pos = toScreen(tower.latitude!, tower.longitude!);
      final color = towerColors[i % towerColors.length];
      _drawTowerMarker(canvas, pos, color, i + 1);
    }

    // Draw estimated position
    if (result != null) {
      final estPos = toScreen(result!.latitude, result!.longitude);
      _drawEstimatedPosition(canvas, estPos);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 10; i++) {
      final x = size.width * i / 10;
      final y = size.height * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawTowerMarker(Canvas canvas, Offset pos, Color color, int index) {
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 18, glowPaint);

    // Main circle
    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 12, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, 12, borderPaint);

    // Number
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$index',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  void _drawEstimatedPosition(Canvas canvas, Offset pos) {
    // Pulsing outer ring
    final pulseSize = 20 + sin(animationValue * 2 * pi) * 5;
    final pulsePaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, pulseSize, pulsePaint);

    // Crosshair
    final crossPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
        Offset(pos.dx - 12, pos.dy), Offset(pos.dx + 12, pos.dy), crossPaint);
    canvas.drawLine(
        Offset(pos.dx, pos.dy - 12), Offset(pos.dx, pos.dy + 12), crossPaint);

    // Center dot
    final centerPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos, 5, centerPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, 5, borderPaint);

    // Label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'EST',
        style: TextStyle(
          color: Colors.deepPurple,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy + 16));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final length = sqrt(dx * dx + dy * dy);
    final dashLength = 6.0;
    final gapLength = 4.0;
    final totalDash = dashLength + gapLength;
    final dashes = (length / totalDash).floor();

    for (int i = 0; i < dashes; i++) {
      final startFraction = i * totalDash / length;
      final endFraction = (i * totalDash + dashLength) / length;
      canvas.drawLine(
        Offset(p1.dx + dx * startFraction, p1.dy + dy * startFraction),
        Offset(p1.dx + dx * endFraction, p1.dy + dy * endFraction),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TriangulationPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.towers != towers ||
        oldDelegate.result != result;
  }
}

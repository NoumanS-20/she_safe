import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/cell_tower.dart';
import '../models/triangulation_result.dart';
import '../models/zone_data.dart';
import '../services/cell_tower_service.dart';
import '../services/triangulation_service.dart';
import '../services/location_service.dart';
import '../services/zone_service.dart';
import '../widgets/tower_info_card.dart';
import '../widgets/triangulation_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final CellTowerService _cellTowerService = CellTowerService();
  final TriangulationService _triangulationService = TriangulationService();
  final LocationService _locationService = LocationService();
  final ZoneService _zoneService = ZoneService();
  final MapController _mapController = MapController();

  List<CellTower> _towers = [];
  TriangulationResult? _triangulationResult;
  final bool _useGPS = true;
  bool _isLoading = false;
  bool _showMap = true;
  bool _mapNetworkAvailable = true;
  bool _showZones = true;
  String _statusMessage = 'Tap "Scan" to find your location';
  StateZone? _currentZone;

  late AnimationController _pulseController;
  late AnimationController _scanController;

  Timer? _autoRefreshTimer;

  static const List<Color> towerColors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _requestPermissions();
    _checkMapNetwork();
    _loadZoneData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.phone,
      Permission.location,
      Permission.locationWhenInUse,
    ].request();
    // Also request GPS permission via geolocator
    await _locationService.requestPermissions();
  }

  Future<void> _checkMapNetwork() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    final hasNetwork =
      connectivityResults.any((c) => c != ConnectivityResult.none);

    if (!mounted) return;
    setState(() {
      _mapNetworkAvailable = hasNetwork;
    });
  }

  Future<void> _loadZoneData() async {
    await _zoneService.loadZoneData();
    if (mounted && _zoneService.zoneData != null) {
      setState(() {});
    }
  }

  Future<void> _scanTowers() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Finding your location...';
    });

    _scanController.forward(from: 0);

    try {
      // Get cell tower data from the device (enriched with OpenCellID positions)
      final towers = await _cellTowerService.getCellTowers();
      await _checkMapNetwork();

      // Try server-side geolocation via Mylnikov.org (free, no API key)
      TriangulationResult? serverResult;
      if (towers.isNotEmpty) {
        serverResult = await _cellTowerService.getServerSideLocation(towers);
      }

      // Also try GPS
      if (_useGPS) {
        await _locationService.getCurrentPosition();
      }

      // Run local trilateration as fallback (uses OpenCellID tower positions)
      final localResult = _triangulationService.triangulate(towers);

      // Use the best available result: server-side > local triangulation > custom override
      TriangulationResult? bestResult = serverResult ?? localResult;

      setState(() {
        _towers = towers;
        _isLoading = false;

        // Use actual triangulation result if available, otherwise custom override
        _triangulationResult = bestResult ?? TriangulationResult(
          latitude: 12.825331244496796,
          longitude: 80.04569852394921,
          accuracyMeters: 100.0,
          towerCount: towers.length,
          method: 'default_location',
        );

        _currentZone = _zoneService.getZoneForLocation(
          _triangulationResult!.latitude,
          _triangulationResult!.longitude,
        );

        _statusMessage = bestResult != null
            ? 'Location estimated from ${bestResult.towerCount} towers'
            : 'Default Location';
        if (towers.isNotEmpty && bestResult == null) {
          _statusMessage += '\n${towers.length} cell towers detected nearby';
        }
        if (_currentZone != null) {
          _statusMessage +=
              '\nZone: ${_currentZone!.zone} — ${_currentZone!.name}';
        }
      });

      // Pan map to the estimated position
      if (_triangulationResult != null) {
        _mapController.move(
          LatLng(_triangulationResult!.latitude, _triangulationResult!.longitude),
          15.0,
        );
      }

      _scanController.forward(from: 0).then((_) => _scanController.reverse());
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  void _toggleAutoRefresh() {
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-refresh stopped'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      _autoRefreshTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _scanTowers(),
      );
      _scanTowers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-refreshing every 10 seconds'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildLocationCard(theme),
            _buildStatusBar(theme),
            Expanded(
              child: _showMap ? _buildMapView() : _buildVisualizationView(),
            ),
            _buildTowerList(theme, screenHeight),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Center on my location
          if (_triangulationResult != null)
            FloatingActionButton.small(
              heroTag: 'center_location',
              onPressed: () {
                _mapController.move(
                  LatLng(_triangulationResult!.latitude,
                      _triangulationResult!.longitude),
                  15.0,
                );
              },
              backgroundColor: Colors.deepPurple,
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
              ),
            ),
          if (_triangulationResult != null) const SizedBox(height: 8),
          // Auto-refresh toggle
          FloatingActionButton.small(
            heroTag: 'auto_refresh',
            onPressed: _toggleAutoRefresh,
            backgroundColor: _autoRefreshTimer != null
                ? Colors.orange
                : theme.colorScheme.secondaryContainer,
            child: Icon(
              _autoRefreshTimer != null ? Icons.stop : Icons.autorenew,
              color: _autoRefreshTimer != null
                  ? Colors.white
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          // Scan button
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: _isLoading ? null : _scanTowers,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location),
            label: Text(_isLoading ? 'Locating...' : 'Find My Location'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/Gemini_Generated_Image_vtoy16vtoy16vtoy.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SheSafe',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _useGPS
                      ? 'GPS + Cell Tower Location'
                      : 'Cell Tower Triangulation',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          // Toggle map / visualization view
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.map, size: 18),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.radar, size: 18),
              ),
            ],
            selected: {_showMap},
            onSelectionChanged: (value) {
              setState(() => _showMap = value.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 8),
          // Toggle zones layer
          IconButton(
            onPressed: () => setState(() => _showZones = !_showZones),
            icon: Icon(
              _showZones ? Icons.layers : Icons.layers_outlined,
              size: 20,
            ),
            tooltip: _showZones ? 'Hide crime zones' : 'Show crime zones',
            style: IconButton.styleFrom(
              backgroundColor: _showZones
                  ? Colors.red.shade100
                  : theme.colorScheme.surfaceContainerHighest,
              foregroundColor: _showZones ? Colors.red : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Prominent card showing 'Your Estimated Location'
  Widget _buildLocationCard(ThemeData theme) {
    if (_triangulationResult == null) return const SizedBox.shrink();

    final r = _triangulationResult!;
    return GestureDetector(
      onTap: () {
        if (_showMap) {
          _mapController.move(
            LatLng(r.latitude, r.longitude),
            15.0,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade600,
              Colors.deepPurple.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.my_location,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Estimated Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.latitude.toStringAsFixed(6)}, ${r.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Accuracy: ±${r.accuracyMeters.round()}m  •  ${r.towerCount} towers used',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _getAccuracyColor(r.accuracyLevel).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                r.accuracyLevel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            if (_currentZone != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _currentZone!.zone == 'RED'
                      ? Colors.red.shade600
                      : _currentZone!.zone == 'YELLOW'
                          ? Colors.amber.shade600
                          : Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentZone!.zone,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _triangulationResult != null
            ? Colors.green.shade50
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _triangulationResult != null
              ? Colors.green.shade200
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isLoading
                ? Icons.radar
                : _triangulationResult != null
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
            size: 20,
            color: _triangulationResult != null
                ? Colors.green.shade700
                : Colors.grey.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _triangulationResult != null
                    ? Colors.green.shade800
                    : Colors.grey.shade700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_triangulationResult != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getAccuracyColor(
                        _triangulationResult!.accuracyLevel)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _triangulationResult!.accuracyLevel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: _getAccuracyColor(
                      _triangulationResult!.accuracyLevel),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (!_mapNetworkAvailable) {
      return Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 40,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 10),
                Text(
                  'Map needs internet access',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect your phone to Wi-Fi or mobile data, then tap Retry.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _checkMapNetwork,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = _triangulationResult != null
        ? LatLng(_triangulationResult!.latitude, _triangulationResult!.longitude)
        : const LatLng(12.825331244496796, 80.04569852394921);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.she_safe',
          ),
          // Signal radius circles
          CircleLayer(
            circles: _buildMapCircles(),
          ),
          // Crime zone overlay circles
          if (_showZones && _zoneService.zoneData != null)
            CircleLayer(
              circles: _buildZoneCircles(),
            ),
          // Crime zone labels
          if (_showZones && _zoneService.zoneData != null)
            MarkerLayer(
              markers: _buildZoneMarkers(),
            ),
          // Lines from towers to estimated position
          PolylineLayer(
            polylines: _buildMapLines(),
          ),
          // Markers
          MarkerLayer(
            markers: _buildMapMarkers(),
          ),
        ],
      ),
    );
  }

  List<CircleMarker> _buildMapCircles() {
    final circles = <CircleMarker>[];
    final towersWithLoc =
        _towers.where((t) => t.latitude != null && t.longitude != null).toList();

    for (int i = 0; i < towersWithLoc.length; i++) {
      final tower = towersWithLoc[i];
      final color = towerColors[i % towerColors.length];

      circles.add(CircleMarker(
        point: LatLng(tower.latitude!, tower.longitude!),
        radius: tower.estimateDistance(),
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.08),
        borderColor: color.withValues(alpha: 0.3),
        borderStrokeWidth: 1.5,
      ));
    }

    // Accuracy circle for the estimated position
    if (_triangulationResult != null) {
      circles.add(CircleMarker(
        point: LatLng(
            _triangulationResult!.latitude, _triangulationResult!.longitude),
        radius: _triangulationResult!.accuracyMeters,
        useRadiusInMeter: true,
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderColor: Colors.deepPurple.withValues(alpha: 0.5),
        borderStrokeWidth: 2,
      ));
    }

    return circles;
  }

  List<CircleMarker> _buildZoneCircles() {
    final zoneColorMap = {
      'RED': Colors.red,
      'YELLOW': Colors.amber,
      'GREEN': Colors.green,
    };

    return _zoneService.zoneData!.states.map((state) {
      final color = zoneColorMap[state.zone] ?? Colors.grey;
      return CircleMarker(
        point: LatLng(state.latitude, state.longitude),
        radius: 60000, // ~60km radius circles
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.12),
        borderColor: color.withValues(alpha: 0.5),
        borderStrokeWidth: 1.5,
      );
    }).toList();
  }

  List<Polyline> _buildMapLines() {
    if (_triangulationResult == null) return [];

    final lines = <Polyline>[];
    final towersWithLoc =
        _towers.where((t) => t.latitude != null && t.longitude != null).toList();
    final estPoint = LatLng(
        _triangulationResult!.latitude, _triangulationResult!.longitude);

    for (int i = 0; i < towersWithLoc.length; i++) {
      final tower = towersWithLoc[i];
      final color = towerColors[i % towerColors.length];

      lines.add(Polyline(
        points: [
          LatLng(tower.latitude!, tower.longitude!),
          estPoint,
        ],
        color: color.withValues(alpha: 0.4),
        strokeWidth: 1.5,
        pattern: const StrokePattern.dotted(),
      ));
    }

    return lines;
  }

  List<Marker> _buildMapMarkers() {
    final markers = <Marker>[];
    final towersWithLoc =
        _towers.where((t) => t.latitude != null && t.longitude != null).toList();

    // Tower markers
    for (int i = 0; i < towersWithLoc.length; i++) {
      final tower = towersWithLoc[i];
      final color = towerColors[i % towerColors.length];

      markers.add(Marker(
        point: LatLng(tower.latitude!, tower.longitude!),
        width: 40,
        height: 40,
        child: _TowerMapMarker(
          index: i + 1,
          color: color,
          networkType: tower.networkType,
        ),
      ));
    }

    // YOUR LOCATION marker — the main result
    if (_triangulationResult != null) {
      markers.add(Marker(
        point: LatLng(
            _triangulationResult!.latitude, _triangulationResult!.longitude),
        width: 120,
        height: 80,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "You are here" label
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Text(
                    'You are here',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Pulsing location dot
                Container(
                  width: 36 + 8 * _pulseController.value,
                  height: 36 + 8 * _pulseController.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.withValues(
                        alpha: 0.12 + 0.08 * _pulseController.value),
                  ),
                  child: Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.deepPurple,
                        border:
                            Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.deepPurple.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ));
    }

    return markers;
  }

  List<Marker> _buildZoneMarkers() {
    final zoneColorMap = {
      'RED': Colors.red.shade700,
      'YELLOW': Colors.amber.shade700,
      'GREEN': Colors.green.shade700,
    };

    return _zoneService.zoneData!.states.map((state) {
      final color = zoneColorMap[state.zone] ?? Colors.grey;
      return Marker(
        point: LatLng(state.latitude, state.longitude),
        width: 140,
        height: 50,
        child: GestureDetector(
          onTap: () => _showZoneInfo(state),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
                  ],
                ),
                child: Text(
                  state.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _showZoneInfo(StateZone state) {
    final colorMap = {
      'RED': Colors.red,
      'YELLOW': Colors.amber,
      'GREEN': Colors.green,
    };
    final color = colorMap[state.zone] ?? Colors.grey;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    state.zone == 'RED'
                        ? 'HIGH RISK'
                        : state.zone == 'YELLOW'
                            ? 'MODERATE RISK'
                            : 'LOW RISK',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.name,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _zoneInfoRow('Total Crimes', '${state.totalCrime}'),
            _zoneInfoRow('Districts', '${state.districtCount}'),
            _zoneInfoRow(
                'Avg Crime/District', state.avgPerDistrict.toStringAsFixed(1)),
            const SizedBox(height: 8),
            Text(
              'Data: NCRB 2020 — Crime against Women',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoneInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildVisualizationView() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _towers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.radar,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No tower data yet',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Scan Towers" to begin',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: TriangulationPainter(
                    towers: _towers,
                    result: _triangulationResult,
                    animationValue: _pulseController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
    );
  }

  Widget _buildTowerList(ThemeData theme, double screenHeight) {
    if (_towers.isEmpty) return const SizedBox.shrink();

    final listHeight = screenHeight < 700 ? 92.0 : 120.0;
    final bottomSpacing = screenHeight < 700 ? 0.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                'Detected Towers',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_towers.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              if (_triangulationResult != null)
                TextButton.icon(
                  onPressed: _showTriangulationDetails,
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _towers.length,
            itemBuilder: (context, index) {
              final tower = _towers[index];
              final color = towerColors[index % towerColors.length];
              return SizedBox(
                width: 280,
                child: TowerInfoCard(
                  tower: tower,
                  index: index,
                  markerColor: color,
                  onTap: () {
                    if (tower.latitude != null &&
                        tower.longitude != null &&
                        _showMap) {
                      _mapController.move(
                        LatLng(tower.latitude!, tower.longitude!),
                        15.0,
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
        SizedBox(height: bottomSpacing),
      ],
    );
  }

  void _showTriangulationDetails() {
    if (_triangulationResult == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final r = _triangulationResult!;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your Location Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _detailRow('Your Latitude', r.latitude.toStringAsFixed(6)),
              _detailRow('Your Longitude', r.longitude.toStringAsFixed(6)),
              _detailRow('Accuracy', '±${r.accuracyMeters.round()} meters'),
              _detailRow('Accuracy Level', r.accuracyLevel),
              _detailRow('Method', r.method.replaceAll('_', ' ').toUpperCase()),
              _detailRow('Towers Used', '${r.towerCount}'),
              _detailRow('Last Updated', r.timestamp.toString().substring(0, 19)),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(String level) {
    return switch (level) {
      'High' => Colors.green,
      'Medium' => Colors.orange,
      'Low' => Colors.deepOrange,
      _ => Colors.red,
    };
  }
}

/// Tower marker widget for the map.
class _TowerMapMarker extends StatelessWidget {
  final int index;
  final Color color;
  final String networkType;

  const _TowerMapMarker({
    required this.index,
    required this.color,
    required this.networkType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.cell_tower,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

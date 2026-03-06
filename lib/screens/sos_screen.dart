import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/sos_service.dart';
import '../services/contacts_service.dart';
import '../services/location_service.dart';
import '../models/emergency_contact.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  final SosService _sosService = SosService();
  final ContactsService _contactsService = ContactsService();
  final LocationService _locationService = LocationService();

  late AnimationController _pulseController;
  bool _isSending = false;
  String? _statusMessage;
  Position? _currentPosition;
  List<EmergencyContact> _contacts = [];
  int _sosCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _contacts = await _contactsService.getContacts();
    _currentPosition = await _locationService.getCurrentPosition();
    if (mounted) setState(() {});
  }

  void _startSOSCountdown() {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please add emergency contacts first from the Contacts tab'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _sosCountdown = 3);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _sosCountdown--);
      HapticFeedback.mediumImpact();

      if (_sosCountdown <= 0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    setState(() {
      _sosCountdown = 0;
      _statusMessage = null;
    });
  }

  Future<void> _triggerSOS() async {
    setState(() {
      _isSending = true;
      _statusMessage = 'Sending emergency alert...';
    });

    HapticFeedback.heavyImpact();

    final result = await _sosService.triggerSOS();

    setState(() {
      _isSending = false;
      _statusMessage = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Header
              Text(
                'Emergency SOS',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Press and hold the button to send an emergency alert',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // SOS Button
              _buildSOSButton(theme),
              const SizedBox(height: 24),

              // Status
              if (_statusMessage != null) _buildStatusCard(theme),
              const SizedBox(height: 16),

              // Location Info
              _buildLocationCard(theme),
              const SizedBox(height: 16),

              // Quick Actions
              _buildQuickActions(theme),
              const SizedBox(height: 16),

              // Contacts summary
              _buildContactsSummary(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton(ThemeData theme) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = _sosCountdown > 0
            ? 1.0 + 0.08 * _pulseController.value
            : 1.0 + 0.03 * _pulseController.value;

        return GestureDetector(
          onLongPress: _isSending ? null : _startSOSCountdown,
          onLongPressUp: _sosCountdown > 0 ? _cancelSOS : null,
          onTap: () {
            if (_sosCountdown == 0 && !_isSending) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Long press the SOS button to activate emergency alert'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: Transform.scale(
            scale: pulseScale,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _sosCountdown > 0
                      ? [Colors.red.shade400, Colors.red.shade900]
                      : [Colors.red.shade300, Colors.red.shade700],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(
                        alpha: _sosCountdown > 0 ? 0.6 : 0.3),
                    blurRadius: _sosCountdown > 0 ? 40 : 20,
                    spreadRadius: _sosCountdown > 0 ? 10 : 2,
                  ),
                ],
              ),
              child: Center(
                child: _isSending
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3)
                    : _sosCountdown > 0
                        ? Text(
                            '$_sosCountdown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sos, color: Colors.white, size: 48),
                              SizedBox(height: 4),
                              Text(
                                'HOLD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final isSuccess = _statusMessage?.contains('sent') ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuccess ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.warning,
            color: isSuccess ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: isSuccess
                    ? Colors.green.shade800
                    : Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _currentPosition != null
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on,
              color: _currentPosition != null
                  ? Colors.green.shade700
                  : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Location',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentPosition != null
                      ? '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}'
                      : 'Fetching location...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh location',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                icon: Icons.local_police,
                label: 'Call Police\n112',
                color: Colors.blue,
                onTap: _sosService.callPolice,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: Icons.support_agent,
                label: 'Women Helpline\n1091',
                color: Colors.purple,
                onTap: _sosService.callWomenHelpline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: Icons.share_location,
                label: 'Share\nLocation',
                color: Colors.teal,
                onTap: _sosService.shareLocation,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _contacts.isEmpty
            ? Colors.orange.shade50
            : Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _contacts.isEmpty
              ? Colors.orange.shade200
              : Colors.green.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _contacts.isEmpty ? Icons.warning_amber : Icons.people,
            color: _contacts.isEmpty ? Colors.orange : Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _contacts.isEmpty
                  ? 'No emergency contacts added yet. Go to Contacts tab to add.'
                  : '${_contacts.length} emergency contact(s) will receive your SOS alert.',
              style: TextStyle(
                color: _contacts.isEmpty
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

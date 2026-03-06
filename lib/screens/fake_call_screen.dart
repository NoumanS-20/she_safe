import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  final _nameController = TextEditingController(text: 'Mom');
  final _delayController = TextEditingController(text: '5');

  final List<Map<String, dynamic>> _presets = [
    {'name': 'Mom', 'icon': Icons.favorite, 'color': Colors.pink},
    {'name': 'Dad', 'icon': Icons.person, 'color': Colors.blue},
    {'name': 'Boss', 'icon': Icons.work, 'color': Colors.brown},
    {'name': 'Friend', 'icon': Icons.people, 'color': Colors.teal},
    {'name': 'Police', 'icon': Icons.local_police, 'color': Colors.indigo},
    {'name': 'Custom', 'icon': Icons.edit, 'color': Colors.grey},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _delayController.dispose();
    super.dispose();
  }

  void _scheduleFakeCall() {
    final delay = int.tryParse(_delayController.text) ?? 5;
    final callerName = _nameController.text.trim().isEmpty
        ? 'Unknown'
        : _nameController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fake call from "$callerName" in $delay seconds'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.deepPurple,
      ),
    );

    Timer(Duration(seconds: delay), () {
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _IncomingCallUI(callerName: callerName),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fake Call',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Schedule a fake incoming call to help you escape an uncomfortable or unsafe situation.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Caller presets
            Text(
              'Choose Caller',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final isSelected =
                    _nameController.text == preset['name'] as String;
                final color = preset['color'] as Color;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(preset['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : color),
                      const SizedBox(width: 4),
                      Text(preset['name'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: color,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _nameController.text = preset['name'] as String;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Custom caller name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Caller Name',
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Delay
            TextField(
              controller: _delayController,
              decoration: InputDecoration(
                labelText: 'Delay (seconds)',
                prefixIcon: const Icon(Icons.timer),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Seconds before call starts',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Quick delay buttons
            Row(
              children: [
                _delayButton('5s', 5),
                const SizedBox(width: 8),
                _delayButton('10s', 10),
                const SizedBox(width: 8),
                _delayButton('15s', 15),
                const SizedBox(width: 8),
                _delayButton('30s', 30),
                const SizedBox(width: 8),
                _delayButton('60s', 60),
              ],
            ),
            const SizedBox(height: 32),

            // Start button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _scheduleFakeCall,
                icon: const Icon(Icons.phone, size: 24),
                label: const Text(
                  'Schedule Fake Call',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _delayButton(String label, int seconds) {
    final isSelected = _delayController.text == seconds.toString();
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => _delayController.text = seconds.toString());
        },
        style: OutlinedButton.styleFrom(
          backgroundColor:
              isSelected ? Colors.deepPurple.shade50 : null,
          side: BorderSide(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

/// Simulated incoming call UI.
class _IncomingCallUI extends StatefulWidget {
  final String callerName;

  const _IncomingCallUI({required this.callerName});

  @override
  State<_IncomingCallUI> createState() => _IncomingCallUIState();
}

class _IncomingCallUIState extends State<_IncomingCallUI>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringController;
  bool _answered = false;
  Timer? _callTimer;
  int _callDuration = 0;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _callTimer?.cancel();
    super.dispose();
  }

  void _answerCall() {
    HapticFeedback.mediumImpact();
    setState(() => _answered = true);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _callDuration++);
    });
  }

  void _endCall() {
    _callTimer?.cancel();
    Navigator.of(context).pop();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Caller info
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, child) {
                return Container(
                  width: 120 + (_answered ? 0 : 10 * _ringController.value),
                  height: 120 + (_answered ? 0 : 10 * _ringController.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.shade300.withValues(alpha: 0.3),
                  ),
                  child: Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.deepPurple.shade300,
                            Colors.deepPurple.shade600,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.callerName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _answered
                  ? _formatDuration(_callDuration)
                  : 'Incoming call...',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
            ),
            const Spacer(flex: 3),

            // Action buttons
            if (_answered)
              // End call button
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: GestureDetector(
                  onTap: _endCall,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              )
            else
              // Accept / Decline buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    GestureDetector(
                      onTap: _endCall,
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Decline',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Accept
                    GestureDetector(
                      onTap: _answerCall,
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                            child: const Icon(
                              Icons.call,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Accept',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/cell_tower.dart';

/// A visual indicator for signal strength with animated bars.
class SignalStrengthIndicator extends StatelessWidget {
  final int signalStrength;
  final double size;

  const SignalStrengthIndicator({
    super.key,
    required this.signalStrength,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final quality = ((signalStrength + 120) / 70 * 100).clamp(0, 100).round();
    final bars = (quality / 25).ceil().clamp(1, 4);
    final color = _getColor(quality);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final isActive = index < bars;
        final barHeight = size * (0.3 + 0.175 * index);
        return Container(
          width: size * 0.18,
          height: barHeight,
          margin: EdgeInsets.only(right: size * 0.05),
          decoration: BoxDecoration(
            color: isActive ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Color _getColor(int quality) {
    if (quality >= 75) return Colors.green;
    if (quality >= 50) return Colors.orange;
    if (quality >= 25) return Colors.deepOrange;
    return Colors.red;
  }
}

/// Card widget showing details for a single cell tower.
class TowerInfoCard extends StatelessWidget {
  final CellTower tower;
  final int index;
  final Color markerColor;
  final VoidCallback? onTap;

  const TowerInfoCard({
    super.key,
    required this.tower,
    required this.index,
    required this.markerColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Tower icon with index
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: markerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    Icons.cell_tower,
                    color: markerColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tower info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Tower ${index + 1}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildNetworkBadge(theme),
                        if (tower.isRegistered) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Connected',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CID: ${tower.cellId}  •  LAC: ${tower.locationAreaCode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Est. Distance: ${_formatDistance(tower.estimateDistance())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Signal strength
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SignalStrengthIndicator(
                    signalStrength: tower.signalStrength,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tower.signalStrength} dBm',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    tower.signalLevel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _signalColor(tower.signalQuality),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkBadge(ThemeData theme) {
    final color = switch (tower.networkType) {
      'LTE' => Colors.blue,
      'NR' => Colors.purple,
      'WCDMA' => Colors.teal,
      'GSM' => Colors.orange,
      'CDMA' => Colors.brown,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        tower.networkType,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _signalColor(int quality) {
    if (quality >= 75) return Colors.green;
    if (quality >= 50) return Colors.orange;
    if (quality >= 25) return Colors.deepOrange;
    return Colors.red;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}

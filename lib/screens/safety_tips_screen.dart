import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safety Guide',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency numbers card
          _buildEmergencyNumbersCard(context, theme),
          const SizedBox(height: 16),

          // Safety tips sections
          ..._safetySections.map(
            (section) => _buildSection(context, theme, section),
          ),
          const SizedBox(height: 16),

          // Useful links
          _buildUsefulLinks(context, theme),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumbersCard(BuildContext context, ThemeData theme) {
    final numbers = [
      {'name': 'Police', 'number': '100', 'icon': Icons.local_police, 'color': Colors.blue},
      {'name': 'Emergency', 'number': '112', 'icon': Icons.emergency, 'color': Colors.red},
      {'name': 'Women Helpline', 'number': '1091', 'icon': Icons.support_agent, 'color': Colors.purple},
      {'name': 'Ambulance', 'number': '108', 'icon': Icons.local_hospital, 'color': Colors.green},
      {'name': 'Child Helpline', 'number': '1098', 'icon': Icons.child_care, 'color': Colors.orange},
      {'name': 'NCW', 'number': '7827-170-170', 'icon': Icons.shield, 'color': Colors.teal},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_in_talk, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Emergency Numbers',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: numbers.map((n) {
              return InkWell(
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: n['number'] as String);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                child: Container(
                  width: MediaQuery.of(context).size.width / 2 - 32,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(n['icon'] as IconData,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              n['number'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, ThemeData theme, Map<String, dynamic> section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (section['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              section['icon'] as IconData,
              color: section['color'] as Color,
              size: 22,
            ),
          ),
          title: Text(
            section['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          children: (section['tips'] as List<String>).map((tip) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: (section['color'] as Color)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUsefulLinks(BuildContext context, ThemeData theme) {
    final links = [
      {
        'title': 'National Commission for Women',
        'url': 'http://ncw.nic.in/',
        'icon': Icons.language,
      },
      {
        'title': 'Cyber Crime Portal',
        'url': 'https://cybercrime.gov.in/',
        'icon': Icons.security,
      },
      {
        'title': 'Self Defense Videos',
        'url': 'https://www.youtube.com/results?search_query=self+defense+for+women',
        'icon': Icons.play_circle,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Useful Resources',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...links.map((link) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Icon(link['icon'] as IconData,
                  color: Colors.deepPurple),
              title: Text(
                link['title'] as String,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final uri = Uri.parse(link['url'] as String);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

final List<Map<String, dynamic>> _safetySections = [
  {
    'title': 'When Walking Alone',
    'icon': Icons.directions_walk,
    'color': Colors.deepPurple,
    'tips': [
      'Stay alert and aware of your surroundings at all times.',
      'Walk confidently and with purpose — avoid looking lost.',
      'Keep your phone charged and easily accessible.',
      'Avoid wearing earphones in both ears — keep one ear free.',
      'Stay in well-lit and populated areas, especially at night.',
      'Share your live location with a trusted contact.',
      'Trust your instincts — if something feels wrong, move away.',
      'Plan your route in advance and let someone know.',
    ],
  },
  {
    'title': 'Using Public Transport',
    'icon': Icons.directions_bus,
    'color': Colors.blue,
    'tips': [
      'Try to sit near the driver or in a well-populated area.',
      'Avoid empty bus or train compartments late at night.',
      'Keep your belongings close and be aware of pickpockets.',
      'Note the vehicle number and share it with someone.',
      'If using a cab, share the ride details with a trusted person.',
      'Verify the driver and vehicle details for ride-sharing apps.',
      'Prefer verified and tracked transportation services.',
    ],
  },
  {
    'title': 'At Home Safety',
    'icon': Icons.home,
    'color': Colors.green,
    'tips': [
      'Always lock your doors and windows, even when at home.',
      'Don\'t open the door for strangers — use a peephole or camera.',
      'Keep emergency numbers on speed dial.',
      'Have an emergency exit plan for your house.',
      'Install security cameras or a video doorbell if possible.',
      'Keep a whistle or personal alarm accessible near the door.',
    ],
  },
  {
    'title': 'Online Safety',
    'icon': Icons.phone_android,
    'color': Colors.orange,
    'tips': [
      'Never share your live location publicly on social media.',
      'Be cautious about sharing personal details online.',
      'Use strong passwords and enable two-factor authentication.',
      'Report cyber harassment to cybercrime.gov.in.',
      'Be careful about meeting online acquaintances in person.',
      'Check privacy settings on all social media accounts.',
    ],
  },
  {
    'title': 'Self Defense Basics',
    'icon': Icons.sports_martial_arts,
    'color': Colors.red,
    'tips': [
      'Target vulnerable areas: eyes, nose, throat, groin, knees.',
      'Use your elbows and knees — they are your strongest weapons.',
      'Yell "FIRE" instead of "HELP" — it attracts more attention.',
      'Carry legal self-defense items like pepper spray.',
      'Practice basic self-defense moves regularly.',
      'If grabbed from behind, stomp on the attacker\'s foot hard.',
      'Use everyday items (keys, bag, umbrella) as defense tools.',
      'Take a self-defense class when possible.',
    ],
  },
  {
    'title': 'Workplace Safety',
    'icon': Icons.business,
    'color': Colors.teal,
    'tips': [
      'Know your rights under workplace harassment laws.',
      'Document any inappropriate behavior or communication.',
      'Report harassment to your company\'s Internal Complaints Committee.',
      'The POSH Act protects women against workplace sexual harassment.',
      'Keep records of any incidents with dates and witnesses.',
      'Seek support from trusted colleagues or employee assistance programs.',
    ],
  },
];

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/meeras_theme.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List _broadcasts = [];
  List _helpRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final br = await ApiService.getBroadcasts();
    final hr = await ApiService.getHelpRequests();
    setState(() {
      _broadcasts = br['data']['results'] ?? br['data'] ?? [];
      _helpRequests = hr['data']['results'] ?? hr['data'] ?? [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: MeerasTheme.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: MeerasTheme.accent,
          backgroundColor: MeerasTheme.surface,
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_ios, color: MeerasTheme.textPrimary, size: 18),
                      const Spacer(),
                      Text('homepage',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: MeerasTheme.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: MeerasTheme.textSecondary, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Location card ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LocationCard(user: user),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Quick action pills ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickAction(icon: Icons.campaign_outlined, label: 'Alerts',
                          onTap: () => Navigator.pushNamed(context, '/broadcasts')),
                      _QuickAction(icon: Icons.handshake_outlined, label: 'Help',
                          onTap: () => Navigator.pushNamed(context, '/help-requests')),
                      _QuickAction(icon: Icons.warning_amber_outlined, label: 'Emergency',
                          onTap: () => _showEmergencyDialog(context)),
                      _QuickAction(icon: Icons.inventory_2_outlined, label: 'Inventory',
                          onTap: () {
                            if (auth.isNgoAdmin || auth.isSystemAdmin) {
                              Navigator.pushNamed(context, '/inventory');
                            } else {
                              _showAccessDenied(context);
                            }
                          }),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Weather forecast ─────────────────────────────────
              const SliverToBoxAdapter(child: _WeatherCard()),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Admin panel shortcut (role-gated) ───────────────
              if (auth.isNgoAdmin || auth.isSystemAdmin)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AdminBanner(auth: auth),
                  ),
                ),

              if (auth.isNgoAdmin || auth.isSystemAdmin)
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Community posts ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text('Community posts',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ),

              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: MeerasTheme.accent)),
                  ),
                )
              else if (_broadcasts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(children: [
                        const Icon(Icons.inbox_outlined, color: MeerasTheme.textMuted, size: 40),
                        const SizedBox(height: 8),
                        Text('No broadcasts yet',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ]),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _BroadcastTile(post: _broadcasts[i]),
                    childCount: _broadcasts.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MeerasTheme.surface,
        title: const Text('Emergency Alert', style: TextStyle(color: MeerasTheme.danger)),
        content: const Text('Send emergency broadcast to all personnel?',
            style: TextStyle(color: MeerasTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: call broadcasts API with priority=emergency
            },
            child: const Text('Send', style: TextStyle(color: MeerasTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showAccessDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access restricted to NGO admins'),
        backgroundColor: MeerasTheme.danger,
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final Map<String, dynamic>? user;
  const _LocationCard({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MeerasTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(
                  color: MeerasTheme.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_outlined,
                    color: MeerasTheme.textSecondary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current location',
                      style: TextStyle(color: MeerasTheme.textMuted, fontSize: 11)),
                  Text(user?['location'] ?? 'Unknown location',
                      style: const TextStyle(color: MeerasTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Map placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: MeerasTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, color: MeerasTheme.textMuted, size: 20),
                  SizedBox(width: 8),
                  Text('Map view', style: TextStyle(color: MeerasTheme.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: MeerasTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: MeerasTheme.textSecondary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: MeerasTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    final hours = ['11am', '12pm', '1pm', '2pm', '3pm', '4pm', '5pm'];
    final temps = [22, 24, 25, 26, 25, 24, 22];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MeerasTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('weather forecast',
                        style: TextStyle(color: MeerasTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('Cloudy conditions expected around 11am.',
                        style: TextStyle(color: MeerasTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Text('29',
                  style: TextStyle(color: MeerasTheme.textPrimary,
                      fontSize: 36, fontWeight: FontWeight.w700)),
              const Text('°',
                  style: TextStyle(color: MeerasTheme.accent, fontSize: 24)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(hours.length, (i) => Column(
              children: [
                Text(hours[i],
                    style: const TextStyle(color: MeerasTheme.textMuted, fontSize: 10)),
                const SizedBox(height: 4),
                Text('${temps[i]}°',
                    style: TextStyle(
                      color: i == 2 ? MeerasTheme.accent : MeerasTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: i == 2 ? FontWeight.w600 : FontWeight.normal,
                    )),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _AdminBanner extends StatelessWidget {
  final AuthProvider auth;
  const _AdminBanner({required this.auth});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/admin'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MeerasTheme.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MeerasTheme.accent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings_outlined,
                color: MeerasTheme.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Admin Panel',
                      style: TextStyle(color: MeerasTheme.accentLight,
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('Logged in as ${auth.role}',
                      style: const TextStyle(color: MeerasTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MeerasTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BroadcastTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _BroadcastTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MeerasTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
              color: MeerasTheme.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline,
                color: MeerasTheme.textMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(post['posted_by_username'] ?? 'Unknown',
                        style: const TextStyle(color: MeerasTheme.textPrimary,
                            fontWeight: FontWeight.w500, fontSize: 13)),
                    const Spacer(),
                    Text(post['created_at'] ?? '',
                        style: const TextStyle(color: MeerasTheme.textMuted, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(post['message'] ?? '',
                    style: const TextStyle(color: MeerasTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
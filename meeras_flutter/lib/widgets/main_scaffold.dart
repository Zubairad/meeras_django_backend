import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/help_requests_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/chat_screen.dart';
import '../theme/meeras_theme.dart';
import '../widgets/animations.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    HelpRequestsScreen(),
    InventoryScreen(),
    ChatScreen(),
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: MeerasTheme.bg.withValues(alpha: 0.82),
              border: const Border(
                top: BorderSide(color: MeerasTheme.divider, width: 0.8),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      index: 0,
                      current: _index,
                      onTap: (i) => setState(() => _index = i),
                    ),
                    _NavItem(
                      icon: Icons.volunteer_activism_outlined,
                      activeIcon: Icons.volunteer_activism_rounded,
                      label: 'Help',
                      index: 1,
                      current: _index,
                      onTap: (i) => setState(() => _index = i),
                    ),
                    if (auth.isNgoAdmin || auth.isSystemAdmin)
                      _NavItem(
                        icon: Icons.inventory_2_outlined,
                        activeIcon: Icons.inventory_2_rounded,
                        label: 'Stock',
                        index: 2,
                        current: _index,
                        onTap: (i) => setState(() => _index = i),
                      ),
                    _NavItem(
                      icon: Icons.forum_outlined,
                      activeIcon: Icons.forum_rounded,
                      label: 'Feed',
                      index: 3,
                      current: _index,
                      onTap: (i) => setState(() => _index = i),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                      index: 4,
                      current: _index,
                      onTap: (i) => setState(() => _index = i),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;

    return TapScale(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? MeerasTheme.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                active ? activeIcon : icon,
                color: active ? MeerasTheme.accentLight : MeerasTheme.textMuted,
                size: 21,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: active ? MeerasTheme.accentLight : MeerasTheme.textMuted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatelessWidget {
  const _ProfileScreen();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: MeerasTheme.accent.withValues(alpha: 0.18),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 42,
                  backgroundColor: MeerasTheme.surfaceElevated,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MeerasTheme.accent.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (user?['username'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: MeerasTheme.accentLight,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user?['username'] ?? 'User',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (auth.isNgoAdmin || auth.isSystemAdmin) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF5B8DEF),
                  size: 19,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MeerasTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MeerasTheme.accent.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Text(
                auth.role.toUpperCase(),
                style: const TextStyle(
                  color: MeerasTheme.accentLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // User details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MeerasTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MeerasTheme.cardBorder, width: 0.8),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: MeerasTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.alternate_email_rounded,
                    color: MeerasTheme.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          color: MeerasTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?['email'] ?? 'No email configured',
                        style: const TextStyle(
                          color: MeerasTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Admin tools section
          if (auth.isNgoAdmin || auth.isSystemAdmin) ...[
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: MeerasTheme.accentLight,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Administration',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MeerasTheme.accentLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: MeerasTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MeerasTheme.cardBorder, width: 0.8),
              ),
              child: Column(
                children: [
                  _AdminTile(
                    icon: Icons.flag_outlined,
                    label: 'Post Moderation',
                    subtitle: 'Review flagged & verify posts',
                    color: MeerasTheme.danger,
                    onTap: () =>
                        Navigator.pushNamed(context, '/admin/moderation'),
                  ),
                  const Divider(
                    height: 1,
                    indent: 64,
                    color: MeerasTheme.divider,
                  ),
                  _AdminTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Inventory',
                    subtitle: 'Manage NGO resources',
                    color: MeerasTheme.accentLight,
                    onTap: () => Navigator.pushNamed(context, '/inventory'),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          TapScale(
            onTap: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (_) => false,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: MeerasTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MeerasTheme.danger.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: MeerasTheme.danger,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Sign out',
                    style: TextStyle(
                      color: MeerasTheme.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: MeerasTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: MeerasTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: MeerasTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

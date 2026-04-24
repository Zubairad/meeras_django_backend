import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';
import '../screens/help_requests_screen.dart';
import '../screens/inventory_screen.dart';
import '../theme/meeras_theme.dart';

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
    _ChatPlaceholder(),
    _ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: MeerasTheme.surface,
          border: Border(top: BorderSide(color: MeerasTheme.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home,
                    label: 'Home', index: 0, current: _index, onTap: (i) => setState(() => _index = i)),
                _NavItem(icon: Icons.handshake_outlined, activeIcon: Icons.handshake,
                    label: 'Help', index: 1, current: _index, onTap: (i) => setState(() => _index = i)),
                if (auth.isNgoAdmin || auth.isSystemAdmin)
                  _NavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2,
                      label: 'Stock', index: 2, current: _index, onTap: (i) => setState(() => _index = i)),
                _NavItem(icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble,
                    label: 'Chat', index: 3, current: _index, onTap: (i) => setState(() => _index = i)),
                _NavItem(icon: Icons.person_outline, activeIcon: Icons.person,
                    label: 'Profile', index: 4, current: _index, onTap: (i) => setState(() => _index = i)),
              ],
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
    required this.icon, required this.activeIcon,
    required this.label, required this.index,
    required this.current, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? MeerasTheme.accent : MeerasTheme.textMuted, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  color: active ? MeerasTheme.accent : MeerasTheme.textMuted,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

class _ChatPlaceholder extends StatelessWidget {
  const _ChatPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Chat')),
      body: const Center(
        child: Text('Chat coming soon', style: TextStyle(color: MeerasTheme.textMuted)),
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
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: MeerasTheme.accent.withOpacity(0.15),
              child: Text(
                (user?['username'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: MeerasTheme.accent, fontSize: 32, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Text(user?['username'] ?? 'User',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MeerasTheme.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(auth.role,
                  style: const TextStyle(color: MeerasTheme.accentLight, fontSize: 12)),
            ),
            const SizedBox(height: 32),
            const Divider(color: MeerasTheme.divider),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: MeerasTheme.textSecondary),
              title: Text(user?['email'] ?? 'No email',
                  style: const TextStyle(color: MeerasTheme.textSecondary)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeerasTheme.danger,
                  side: const BorderSide(color: MeerasTheme.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await auth.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
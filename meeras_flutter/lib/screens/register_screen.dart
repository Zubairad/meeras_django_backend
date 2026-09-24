import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/meeras_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String _selectedRole = 'helper';
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  final _roles = const [
    _RoleOption(
      value: 'helper',
      label: 'Helper',
      subtitle: 'Volunteer or NGO field worker',
      icon: Icons.handshake_outlined,
    ),
    _RoleOption(
      value: 'ngo_admin',
      label: 'NGO Admin',
      subtitle: 'Manages personnel and resources',
      icon: Icons.admin_panel_settings_outlined,
    ),
  ];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() {
        _error = 'Passwords do not match';
        _loading = false;
      });
      return;
    }

    if (_passwordCtrl.text.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters';
        _loading = false;
      });
      return;
    }

    final result = await ApiService.register({
      'username': _usernameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'role': _selectedRole,
    });

    if (!mounted) return;

    if (result['status'] == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created! Please sign in.'),
          backgroundColor: MeerasTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } else {
      final data = result['data'] as Map<String, dynamic>;
      final msg = data.values.first;
      setState(() {
        _error = msg is List ? msg.first.toString() : msg.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join Meeras',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Create your account to get started',
                style: Theme.of(context).textTheme.bodyMedium),

            const SizedBox(height: 32),

            // ── Role selector ──────────────────────────────────
            Text('I am a...',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...(_roles.map((r) => _RoleTile(
              option: r,
              selected: _selectedRole == r.value,
              onTap: () =>
                  setState(() => _selectedRole = r.value),
            ))),

            const SizedBox(height: 28),

            // ── Name row ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameCtrl,
                    style: const TextStyle(
                        color: MeerasTheme.textPrimary),
                    decoration: const InputDecoration(
                        hintText: 'First name'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastNameCtrl,
                    style: const TextStyle(
                        color: MeerasTheme.textPrimary),
                    decoration: const InputDecoration(
                        hintText: 'Last name'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _usernameCtrl,
              style:
              const TextStyle(color: MeerasTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Username',
                prefixIcon: Icon(Icons.person_outline,
                    color: MeerasTheme.textMuted, size: 20),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style:
              const TextStyle(color: MeerasTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined,
                    color: MeerasTheme.textMuted, size: 20),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              style:
              const TextStyle(color: MeerasTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Password (min 8 characters)',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: MeerasTheme.textMuted, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: MeerasTheme.textMuted, size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscure = !_obscure),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              style:
              const TextStyle(color: MeerasTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Confirm password',
                prefixIcon: Icon(Icons.lock_outline,
                    color: MeerasTheme.textMuted, size: 20),
              ),
              onSubmitted: (_) => _submit(),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                    MeerasTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: MeerasTheme.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: MeerasTheme.danger,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white))
                    : const Text('Create Account'),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ',
                    style: TextStyle(
                        color: MeerasTheme.textMuted,
                        fontSize: 13)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Sign in',
                      style: TextStyle(
                          color: MeerasTheme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Role option data ──────────────────────────────────────────────────────────

class _RoleOption {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  const _RoleOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

// ── Role tile widget ──────────────────────────────────────────────────────────

class _RoleTile extends StatelessWidget {
  final _RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? MeerasTheme.accent.withValues(alpha: 0.1)
              : MeerasTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? MeerasTheme.accent
                : MeerasTheme.divider,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? MeerasTheme.accent.withValues(alpha: 0.15)
                    : MeerasTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(option.icon,
                  color: selected
                      ? MeerasTheme.accent
                      : MeerasTheme.textMuted,
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label,
                      style: TextStyle(
                        color: selected
                            ? MeerasTheme.accentLight
                            : MeerasTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  Text(option.subtitle,
                      style: const TextStyle(
                          color: MeerasTheme.textMuted,
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? MeerasTheme.accent
                      : MeerasTheme.textMuted,
                  width: 2,
                ),
                color: selected
                    ? MeerasTheme.accent
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                  color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
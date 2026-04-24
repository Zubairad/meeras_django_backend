import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/meeras_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (ok && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo / Brand
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: MeerasTheme.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.volunteer_activism, color: MeerasTheme.accent, size: 28),
              ),
              const SizedBox(height: 28),
              Text('Meeras', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text('NGO Coordination Platform',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 48),

              // Username
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: MeerasTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Username',
                  prefixIcon: Icon(Icons.person_outline, color: MeerasTheme.textMuted, size: 20),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: MeerasTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: MeerasTheme.textMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: MeerasTheme.textMuted, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),

              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(auth.error!,
                      style: const TextStyle(color: MeerasTheme.danger, fontSize: 13)),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sign in'),
                ),
              ),

              const Spacer(),
              Center(
                child: Text('Role-based access · ngo_admin · helper · system_admin',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mesh_envelope.dart';
import '../services/api_service.dart';
import '../services/mesh_service.dart';
import '../theme/meeras_theme.dart';
import '../widgets/animations.dart';

class NewHelpRequestScreen extends StatefulWidget {
  const NewHelpRequestScreen({super.key});

  @override
  State<NewHelpRequestScreen> createState() => _NewHelpRequestScreenState();
}

class _NewHelpRequestScreenState extends State<NewHelpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  int _urgency = 3;
  bool _submitting = false;

  static const _urgencyLabels = {
    1: 'Low: no immediate risk',
    2: 'Minor: can wait a few hours',
    3: 'Moderate: needs attention today',
    4: 'High: needs help soon',
    5: 'Critical: immediate danger to life',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Color _urgencyColor(int level) {
    if (level >= 5) return MeerasTheme.danger;
    if (level >= 3) return MeerasTheme.warning;
    return MeerasTheme.success;
  }

  String _extractError(dynamic data) {
    if (data is Map && data.isNotEmpty) {
      final key = data.keys.first;
      final val = data[key];
      final msg = val is List && val.isNotEmpty
          ? val.first.toString()
          : val.toString();
      return '$key: $msg';
    }
    return 'Something went wrong. Please try again.';
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? MeerasTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final mesh = context.read<NearbyMeshService>();
    setState(() => _submitting = true);

    final payload = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'urgency': _urgency,
    };

    String? error;
    bool viaMesh = false;

    try {
      final result = await ApiService.createHelpRequest(
        payload,
      ).timeout(const Duration(seconds: 6));
      final status = result['status'];
      if (status != 200 && status != 201) {
        error = _extractError(result['data']);
      }
    } catch (_) {
      // Server unreachable: fall back to the offline mesh.
      try {
        await mesh.createAndBroadcast(
          type: RecordType.helpRequest,
          payload: payload,
        );
        viaMesh = true;
      } catch (_) {
        error =
            "Can't reach the server and the offline mesh isn't active. "
            'Check Bluetooth, Wi-Fi and location permissions.';
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _snack(error, color: MeerasTheme.danger);
      return;
    }

    _snack(
      viaMesh
          ? 'No internet. Request sent over the offline mesh.'
          : 'Help request submitted.',
      color: viaMesh ? MeerasTheme.surfaceElevated : MeerasTheme.success,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Help Request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'What do you need help with?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Works offline too. If there is no signal, nearby devices relay it for you.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _titleCtrl,
              style: const TextStyle(color: MeerasTheme.textPrimary),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Title (e.g. Family trapped on rooftop)',
                prefixIcon: Icon(
                  Icons.title,
                  color: MeerasTheme.textMuted,
                  size: 20,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: MeerasTheme.textPrimary),
              maxLines: 4,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Describe the situation',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _locationCtrl,
              style: const TextStyle(color: MeerasTheme.textPrimary),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Location',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: MeerasTheme.textMuted,
                  size: 20,
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Location is required'
                  : null,
            ),
            const SizedBox(height: 24),

            Text('Urgency', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final level = i + 1;
                final selected = _urgency == level;
                final color = _urgencyColor(level);
                return Expanded(
                  child: TapScale(
                    onTap: () => setState(() => _urgency = level),
                    child: AnimatedScale(
                      scale: selected ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.only(right: level == 5 ? 0 : 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.18)
                              : MeerasTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? color : MeerasTheme.divider,
                            width: selected ? 1.5 : 0.5,
                          ),
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: selected ? color : MeerasTheme.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: selected ? 18 : 16,
                          ),
                          child: Text('$level'),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Align(
                key: ValueKey(_urgency),
                alignment: Alignment.centerLeft,
                child: Text(
                  _urgencyLabels[_urgency]!,
                  style: TextStyle(
                    color: _urgencyColor(_urgency),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/meeras_theme.dart';

class HelpRequestsScreen extends StatefulWidget {
  const HelpRequestsScreen({super.key});
  @override
  State<HelpRequestsScreen> createState() => _HelpRequestsScreenState();
}

class _HelpRequestsScreenState extends State<HelpRequestsScreen> {
  List _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.getHelpRequests();
    setState(() {
      _requests = result['data']['results'] ?? result['data'] ?? [];
      _loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return MeerasTheme.warning;
      case 'assigned': return MeerasTheme.accent;
      case 'completed': return MeerasTheme.success;
      default: return MeerasTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Requests'),
        actions: [
          if (auth.isNgoAdmin || auth.isSystemAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.pushNamed(context, '/help-requests/new')
                  .then((_) => _load()),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: MeerasTheme.accent))
          : RefreshIndicator(
              onRefresh: _load,
              color: MeerasTheme.accent,
              backgroundColor: MeerasTheme.surface,
              child: _requests.isEmpty
                  ? const Center(
                      child: Text('No help requests', style: TextStyle(color: MeerasTheme.textMuted)),
                    )
                  : ListView.builder(
                      itemCount: _requests.length,
                      padding: const EdgeInsets.only(top: 8, bottom: 80),
                      itemBuilder: (ctx, i) {
                        final req = _requests[i];
                        final status = req['status'] ?? 'pending';
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MeerasTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(req['title'] ?? 'Request #${req['id']}',
                                        style: Theme.of(context).textTheme.titleMedium),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status,
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                                ],
                              ),
                              if (req['description'] != null) ...[
                                const SizedBox(height: 6),
                                Text(req['description'],
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                              if (auth.isNgoAdmin && status == 'pending') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _showAssignDialog(context, req['id']),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    child: const Text('Assign Helper'),
                                  ),
                                ),
                              ],
                              if ((auth.isNgoAdmin || auth.isHelper) && status == 'assigned') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await ApiService.completeHelpRequest(req['id']);
                                      _load();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: MeerasTheme.success),
                                      foregroundColor: MeerasTheme.success,
                                    ),
                                    child: const Text('Mark Complete'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  void _showAssignDialog(BuildContext context, int requestId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MeerasTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignSheet(requestId: requestId, onAssigned: _load),
    );
  }
}

class _AssignSheet extends StatefulWidget {
  final int requestId;
  final VoidCallback onAssigned;
  const _AssignSheet({required this.requestId, required this.onAssigned});

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  List _personnel = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // The assign endpoint expects a User id with role='helper'
    // So we fetch /api/users/?search= and filter by role, not /api/personnel/
    ApiService.getHelpers().then((r) {
      setState(() {
        _personnel = r['data']['results'] ?? r['data'] ?? [];
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assign to helper',
              style: TextStyle(color: MeerasTheme.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: MeerasTheme.accent))
          else
            ..._personnel.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: MeerasTheme.surfaceElevated,
                child: Icon(Icons.person_outline, color: MeerasTheme.textMuted),
              ),
              title: Text(
                // UserSerializer returns username, first_name, last_name
                '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim().isNotEmpty
                    ? '${p['first_name']} ${p['last_name']}'.trim()
                    : p['username'] ?? 'Helper',
                style: const TextStyle(color: MeerasTheme.textPrimary),
              ),
              subtitle: Text(p['username'] ?? '',
                  style: const TextStyle(color: MeerasTheme.textMuted, fontSize: 12)),
              onTap: () async {
                await ApiService.assignHelpRequest(widget.requestId, p['id']);
                Navigator.pop(context);
                widget.onAssigned();
              },
            )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
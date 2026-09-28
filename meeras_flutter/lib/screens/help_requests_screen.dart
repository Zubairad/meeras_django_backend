import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/meeras_theme.dart';
import '../widgets/animations.dart';

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return MeerasTheme.warning;
    case 'assigned':
      return MeerasTheme.accent;
    case 'completed':
      return MeerasTheme.success;
    default:
      return MeerasTheme.textMuted;
  }
}

Color _urgencyColor(int u) {
  if (u >= 5) return MeerasTheme.danger;
  if (u >= 3) return MeerasTheme.warning;
  return MeerasTheme.success;
}

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

  /// `silent` reloads in the background without flashing the skeleton.
  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final result = await ApiService.getHelpRequests();
    if (!mounted) return;
    final data = result['data'];
    setState(() {
      _requests = data is Map
          ? ((data['results'] as List?) ?? [])
          : ((data as List?) ?? []);
      _loading = false;
    });
  }

  void _showAssignSheet(int requestId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MeerasTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignSheet(
        requestId: requestId,
        onAssigned: () => _load(silent: true),
      ),
    );
  }

  Future<void> _confirmComplete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MeerasTheme.surface,
        title: const Text(
          'Mark as complete?',
          style: TextStyle(color: MeerasTheme.textPrimary),
        ),
        content: const Text(
          'This request will be closed.',
          style: TextStyle(color: MeerasTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Complete',
              style: TextStyle(color: MeerasTheme.success),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.completeHelpRequest(id);
    HapticFeedback.lightImpact();
    await _load(silent: true);
  }

  Widget _item(BuildContext context, AuthProvider auth, int i) {
    final req = _requests[i] as Map;
    final id = (req['id'] as num).toInt();
    final status = (req['status'] ?? 'pending').toString();
    final canAssign = auth.isNgoAdmin && status == 'pending';
    final canComplete =
        (auth.isNgoAdmin || auth.isHelper) && status == 'assigned';

    final card = _RequestCard(
      req: req,
      canAssign: canAssign,
      canComplete: canComplete,
      onAssign: () => _showAssignSheet(id),
      onComplete: () => _confirmComplete(id),
    );

    return FadeSlideIn(
      key: ValueKey('req-$id'),
      index: i,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: (canAssign || canComplete)
              ? Dismissible(
                  key: ValueKey('swipe-$id-$status'),
                  direction: DismissDirection.startToEnd,
                  dismissThresholds: const {DismissDirection.startToEnd: 0.35},
                  confirmDismiss: (_) async {
                    HapticFeedback.mediumImpact();
                    if (canAssign) {
                      _showAssignSheet(id);
                    } else {
                      _confirmComplete(id);
                    }
                    return false; // spring back; the action opens its own UI
                  },
                  background: _SwipeBackground(
                    color: canAssign ? MeerasTheme.accent : MeerasTheme.success,
                    icon: canAssign
                        ? Icons.person_add_alt_1
                        : Icons.check_circle_outline,
                    label: canAssign ? 'Assign helper' : 'Mark complete',
                  ),
                  child: card,
                )
              : card,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            tooltip: 'Offline mesh status',
            onPressed: () => Navigator.pushNamed(context, '/mesh-status'),
          ),
          if (auth.isNgoAdmin || auth.isSystemAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.pushNamed(
                context,
                '/help-requests/new',
              ).then((_) => _load(silent: true)),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _loading
            ? const _RequestSkeletonList(key: ValueKey('skeleton'))
            : RefreshIndicator(
                key: const ValueKey('list'),
                onRefresh: () => _load(silent: true),
                color: MeerasTheme.accent,
                backgroundColor: MeerasTheme.surface,
                child: _requests.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [SizedBox(height: 140), _EmptyState()],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _requests.length,
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemBuilder: (ctx, i) => _item(ctx, auth, i),
                      ),
              ),
      ),
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  final Map req;
  final bool canAssign;
  final bool canComplete;
  final VoidCallback onAssign;
  final VoidCallback onComplete;

  const _RequestCard({
    required this.req,
    required this.canAssign,
    required this.canComplete,
    required this.onAssign,
    required this.onComplete,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final status = (req['status'] ?? 'pending').toString();
    final urgency = (req['urgency'] as num?)?.toInt() ?? 0;
    final desc = req['description']?.toString();
    final location = (req['location'] ?? '').toString();
    final hasDesc = desc != null && desc.isNotEmpty;
    final sColor = _statusColor(status);
    final uColor = _urgencyColor(urgency);

    return TapScale(
      scale: 0.98,
      onTap: hasDesc ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        decoration: BoxDecoration(
          color: MeerasTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: uColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          req['title']?.toString() ?? 'Request #${req['id']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey(status),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: sColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: sColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (urgency > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: uColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Urgency $urgency',
                            style: TextStyle(
                              color: uColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: location.isEmpty
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: MeerasTheme.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: MeerasTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      if (hasDesc)
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: MeerasTheme.textMuted,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  if (hasDesc) ...[
                    const SizedBox(height: 10),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          desc,
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                  if (widget.canAssign) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onAssign,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Assign Helper'),
                      ),
                    ),
                  ],
                  if (widget.canComplete) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: widget.onComplete,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.18),
      padding: const EdgeInsets.only(left: 20),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Loading + empty states ────────────────────────────────────────────────────

class _RequestSkeletonList extends StatelessWidget {
  const _RequestSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MeerasTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: PulseBox(height: 16, radius: 6)),
                SizedBox(width: 60),
                PulseBox(width: 64, height: 22, radius: 11),
              ],
            ),
            SizedBox(height: 12),
            PulseBox(width: 140, height: 12, radius: 6),
            SizedBox(height: 12),
            PulseBox(height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MeerasTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: MeerasTheme.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No help requests',
            style: TextStyle(
              color: MeerasTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pull down to refresh',
            style: TextStyle(color: MeerasTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Assign sheet ──────────────────────────────────────────────────────────────

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
    ApiService.getHelpers().then((r) {
      if (!mounted) return;
      final d = r['data'];
      setState(() {
        _personnel = d is Map
            ? ((d['results'] as List?) ?? [])
            : ((d as List?) ?? []);
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
          const Text(
            'Assign to helper',
            style: TextStyle(
              color: MeerasTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: MeerasTheme.accent),
            )
          else if (_personnel.isEmpty)
            const Text(
              'No helpers available',
              style: TextStyle(color: MeerasTheme.textMuted),
            )
          else
            ..._personnel.asMap().entries.map((e) {
              final p = e.value;
              final fullName =
                  '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
              return FadeSlideIn(
                index: e.key,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: MeerasTheme.surfaceElevated,
                    child: Icon(
                      Icons.person_outline,
                      color: MeerasTheme.textMuted,
                    ),
                  ),
                  title: Text(
                    fullName.isNotEmpty
                        ? fullName
                        : (p['username'] ?? 'Helper'),
                    style: const TextStyle(color: MeerasTheme.textPrimary),
                  ),
                  subtitle: Text(
                    p['username'] ?? '',
                    style: const TextStyle(
                      color: MeerasTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await ApiService.assignHelpRequest(
                      widget.requestId,
                      p['id'],
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    widget.onAssigned();
                  },
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

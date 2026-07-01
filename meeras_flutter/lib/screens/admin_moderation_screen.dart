import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/meeras_theme.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({super.key});
  @override
  State<AdminModerationScreen> createState() =>
      _AdminModerationScreenState();
}

class _AdminModerationScreenState
    extends State<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _flaggedPosts = [];
  List _verifiedPosts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ApiService.getChat();
    if (!mounted) return;
    final all =
    (result['data']['results'] ?? result['data'] ?? []) as List;
    setState(() {
      _flaggedPosts =
          all.where((p) => p['is_flagged'] == true).toList();
      _verifiedPosts =
          all.where((p) => p['is_verified'] == true).toList();
      _loading = false;
    });
  }

  String _timeAgo(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF5B8DEF),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
      const Color(0xFFE67E22),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Access guard
    if (!auth.isNgoAdmin && !auth.isSystemAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Moderation')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  color: MeerasTheme.textMuted, size: 48),
              SizedBox(height: 12),
              Text('Admin access only',
                  style: TextStyle(color: MeerasTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: MeerasTheme.accent,
          labelColor: MeerasTheme.accent,
          unselectedLabelColor: MeerasTheme.textMuted,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Flagged (${_flaggedPosts.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Verified (${_verifiedPosts.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(
              color: MeerasTheme.accent))
          : TabBarView(
        controller: _tabs,
        children: [
          // ── Flagged tab ──────────────────────────────
          _flaggedPosts.isEmpty
              ? _empty(
            'No flagged posts',
            'All clear — nothing needs review',
            Icons.check_circle_outline,
            MeerasTheme.success,
          )
              : RefreshIndicator(
            onRefresh: _load,
            color: MeerasTheme.accent,
            backgroundColor: MeerasTheme.surface,
            child: ListView.separated(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 80),
              itemCount: _flaggedPosts.length,
              separatorBuilder: (_, __) =>
              const Divider(
                  color: MeerasTheme.divider,
                  height: 0.5,
                  indent: 16,
                  endIndent: 16),
              itemBuilder: (ctx, i) {
                final post = _flaggedPosts[i];
                return _ModerationTile(
                  post: post,
                  timeAgo: _timeAgo(
                      post['timestamp']),
                  avatarColor: _avatarColor(
                      post['sender_username'] ??
                          'U'),
                  mode: _TileMode.flagged,
                  onVerify: () async {
                    await ApiService.verifyChat(
                        post['id']);
                    _load();
                    if (!context.mounted) return;
                    _showSnack(context,
                        '✓ Post verified and moved to Verified feed',
                        MeerasTheme.success);
                  },
                  onUnflag: () async {
                    await ApiService.unflagChat(
                        post['id']);
                    _load();
                    if (!context.mounted) return;
                    _showSnack(context,
                        'Flag removed from post',
                        MeerasTheme.surface);
                  },
                  onDelete: () =>
                      _confirmDelete(context, post['id']),
                );
              },
            ),
          ),

          // ── Verified tab ─────────────────────────────
          _verifiedPosts.isEmpty
              ? _empty(
            'No verified posts',
            'Verified posts will appear here',
            Icons.verified_outlined,
            const Color(0xFF5B8DEF),
          )
              : RefreshIndicator(
            onRefresh: _load,
            color: MeerasTheme.accent,
            backgroundColor: MeerasTheme.surface,
            child: ListView.separated(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 80),
              itemCount: _verifiedPosts.length,
              separatorBuilder: (_, __) =>
              const Divider(
                  color: MeerasTheme.divider,
                  height: 0.5,
                  indent: 16,
                  endIndent: 16),
              itemBuilder: (ctx, i) {
                final post = _verifiedPosts[i];
                return _ModerationTile(
                  post: post,
                  timeAgo: _timeAgo(
                      post['timestamp']),
                  avatarColor: _avatarColor(
                      post['sender_username'] ??
                          'U'),
                  mode: _TileMode.verified,
                  onDelete: () =>
                      _confirmDelete(context, post['id']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext ctx, String msg, Color color) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MeerasTheme.surface,
        title: const Text('Delete post?',
            style:
            TextStyle(color: MeerasTheme.textPrimary)),
        content: const Text(
            'This will permanently remove the post.',
            style: TextStyle(
                color: MeerasTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.deleteChat(id);
              _load();
            },
            child: const Text('Delete',
                style:
                TextStyle(color: MeerasTheme.danger)),
          ),
        ],
      ),
    );
  }

  Widget _empty(
      String title, String sub, IconData icon, Color color) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  color: MeerasTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(sub,
              style: const TextStyle(
                  color: MeerasTheme.textMuted,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

enum _TileMode { flagged, verified }

class _ModerationTile extends StatelessWidget {
  final Map post;
  final String timeAgo;
  final Color avatarColor;
  final _TileMode mode;
  final VoidCallback? onVerify;
  final VoidCallback? onUnflag;
  final VoidCallback onDelete;

  const _ModerationTile({
    required this.post,
    required this.timeAgo,
    required this.avatarColor,
    required this.mode,
    required this.onDelete,
    this.onVerify,
    this.onUnflag,
  });

  @override
  Widget build(BuildContext context) {
    final username = post['sender_username'] ?? 'User';
    final reason = post['flag_reason'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User row
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle),
                child: Center(
                  child: Text(username[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(username,
                          style: const TextStyle(
                              color: MeerasTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      if (mode == _TileMode.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            color: Color(0xFF5B8DEF),
                            size: 14),
                      ],
                    ]),
                    Text(timeAgo,
                        style: const TextStyle(
                            color: MeerasTheme.textMuted,
                            fontSize: 11)),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (mode == _TileMode.flagged
                      ? MeerasTheme.danger
                      : const Color(0xFF5B8DEF))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  mode == _TileMode.flagged
                      ? 'Flagged'
                      : 'Verified',
                  style: TextStyle(
                    color: mode == _TileMode.flagged
                        ? MeerasTheme.danger
                        : const Color(0xFF5B8DEF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Message
          Text(post['message'] ?? '',
              style: const TextStyle(
                  color: MeerasTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4)),

          // Flag reason
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                MeerasTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: MeerasTheme.danger
                        .withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: MeerasTheme.danger, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Reason: $reason',
                        style: const TextStyle(
                            color: MeerasTheme.danger,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              if (mode == _TileMode.flagged) ...[
                // Verify button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.verified_outlined,
                        size: 15),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF5B8DEF),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Unflag button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUnflag,
                    icon: const Icon(
                        Icons.flag_outlined, size: 15),
                    label: const Text('Unflag'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                      MeerasTheme.textSecondary,
                      side: const BorderSide(
                          color: MeerasTheme.divider),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Delete button
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 15),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeerasTheme.danger,
                  side: const BorderSide(
                      color: MeerasTheme.danger,
                      width: 0.5),
                  padding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: mode == _TileMode.flagged
                          ? 12
                          : 20),
                  textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
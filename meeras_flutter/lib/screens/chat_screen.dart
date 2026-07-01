import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/meeras_theme.dart';

enum FeedFilter { all, verified, flagged }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List _allPosts = [];
  bool _loading = true;
  FeedFilter _filter = FeedFilter.all;
  Timer? _pollTimer;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = context.read<AuthProvider>().user?['id'];
    _loadPosts();
    // Poll every 3 seconds for near real-time feel
    _pollTimer = Timer.periodic(
        const Duration(seconds: 3), (_) => _loadPosts(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final result = await ApiService.getChat();
    if (!mounted) return;
    final posts =
    (result['data']['results'] ?? result['data'] ?? []) as List;
    setState(() {
      _allPosts = posts.reversed.toList();
      _loading = false;
    });
  }

  List get _filteredPosts {
    switch (_filter) {
      case FeedFilter.verified:
        return _allPosts.where((p) => p['is_verified'] == true).toList();
      case FeedFilter.flagged:
        return _allPosts.where((p) => p['is_flagged'] == true).toList();
      case FeedFilter.all:
      default:
        return _allPosts.where((p) => p['is_flagged'] != true).toList();
    }
  }

  int get _verifiedCount =>
      _allPosts.where((p) => p['is_verified'] == true).length;
  int get _flaggedCount =>
      _allPosts.where((p) => p['is_flagged'] == true).length;
  int get _allCount =>
      _allPosts.where((p) => p['is_flagged'] != true).length;

  String _timeAgo(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${dt.day}/${dt.month}';
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
      const Color(0xFFE74C3C),
      const Color(0xFF2ECC71),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final posts = _filteredPosts;

    return Scaffold(
      backgroundColor: MeerasTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Community',
                          style:
                          Theme.of(context).textTheme.titleLarge),
                      Text('${_allPosts.length} posts',
                          style:
                          Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  const Spacer(),
                  // Live indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MeerasTheme.success
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                            color: MeerasTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('Live',
                            style: TextStyle(
                                color: MeerasTheme.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Compose button
                  GestureDetector(
                    onTap: () => _showComposeSheet(context, auth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: MeerasTheme.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('Post',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter tabs ──────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: MeerasTheme.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  _FilterTab(
                    label: 'All',
                    icon: Icons.dynamic_feed_outlined,
                    active: _filter == FeedFilter.all,
                    count: _allCount,
                    onTap: () =>
                        setState(() => _filter = FeedFilter.all),
                  ),
                  _FilterTab(
                    label: 'Verified',
                    icon: Icons.verified_outlined,
                    active: _filter == FeedFilter.verified,
                    count: _verifiedCount,
                    onTap: () => setState(
                            () => _filter = FeedFilter.verified),
                    accentColor: const Color(0xFF5B8DEF),
                  ),
                  _FilterTab(
                    label: 'Flagged',
                    icon: Icons.flag_outlined,
                    active: _filter == FeedFilter.flagged,
                    count: _flaggedCount,
                    onTap: () => setState(
                            () => _filter = FeedFilter.flagged),
                    accentColor: MeerasTheme.danger,
                  ),
                ],
              ),
            ),

            // ── Feed ─────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: MeerasTheme.accent))
                  : posts.isEmpty
                  ? _EmptyState(filter: _filter)
                  : RefreshIndicator(
                onRefresh: _loadPosts,
                color: MeerasTheme.accent,
                backgroundColor: MeerasTheme.surface,
                child: ListView.separated(
                  padding:
                  const EdgeInsets.only(bottom: 80),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) =>
                  const Divider(
                      color: MeerasTheme.divider,
                      height: 0.5,
                      indent: 16,
                      endIndent: 16),
                  itemBuilder: (ctx, i) {
                    final post = posts[i];
                    final id = post['id'] as int? ?? i;
                    final username =
                        post['sender_username'] ?? 'User';
                    final isMine =
                        post['sender'] == _myUserId;
                    final isVerified =
                        post['is_verified'] == true;
                    final isFlagged =
                        post['is_flagged'] == true;

                    return _PostTile(
                      post: post,
                      username: username,
                      isMine: isMine,
                      isVerified: isVerified,
                      isFlagged: isFlagged,
                      avatarColor:
                      _avatarColor(username),
                      timeAgo: _timeAgo(
                          post['timestamp']),
                      onFlag: () =>
                          _showFlagDialog(context, id),
                      onDelete: isMine
                          ? () => _confirmDelete(
                          context, id)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Flag dialog ────────────────────────────────────────────────
  void _showFlagDialog(BuildContext context, int id) {
    final reasons = [
      'False or misleading information',
      'Spreading panic unnecessarily',
      'Unverified disaster claim',
      'Spam or irrelevant content',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: MeerasTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: MeerasTheme.danger
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag,
                      color: MeerasTheme.danger, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Flag this post',
                    style: TextStyle(
                        color: MeerasTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
                'Flag this post as potentially false or misleading.',
                style: TextStyle(
                    color: MeerasTheme.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 16),
            ...reasons.map((reason) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                  Icons.radio_button_unchecked,
                  color: MeerasTheme.textMuted, size: 18),
              title: Text(reason,
                  style: const TextStyle(
                      color: MeerasTheme.textPrimary,
                      fontSize: 14)),
              onTap: () async {
                Navigator.pop(context);
                await ApiService.flagChat(id, reason);
                _loadPosts();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(children: [
                      Icon(Icons.flag,
                          color: MeerasTheme.danger,
                          size: 16),
                      SizedBox(width: 8),
                      Text('Post flagged for review'),
                    ]),
                    backgroundColor:
                    MeerasTheme.surfaceElevated,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                  ),
                );
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────
  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MeerasTheme.surface,
        title: const Text('Delete post?',
            style: TextStyle(color: MeerasTheme.textPrimary)),
        content: const Text(
            'This post will be permanently removed.',
            style:
            TextStyle(color: MeerasTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final code = await ApiService.deleteChat(id);
              if (code == 204) {
                _loadPosts();
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: MeerasTheme.danger)),
          ),
        ],
      ),
    );
  }

  // ── Compose sheet ──────────────────────────────────────────────
  void _showComposeSheet(BuildContext context, AuthProvider auth) {
    final ctrl = TextEditingController();
    bool sending = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: MeerasTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _avatarColor(
                          auth.user?['username'] ?? 'U'),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (auth.user?['username'] ?? 'U')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                            auth.user?['username'] ?? 'You',
                            style: const TextStyle(
                                color: MeerasTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        if (auth.isNgoAdmin ||
                            auth.isSystemAdmin) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Color(0xFF5B8DEF),
                              size: 15),
                        ],
                      ]),
                      Text(auth.role,
                          style: const TextStyle(
                              color: MeerasTheme.textMuted,
                              fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: MeerasTheme.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 5,
                minLines: 3,
                autofocus: true,
                maxLength: 280,
                style: const TextStyle(
                    color: MeerasTheme.textPrimary,
                    fontSize: 15),
                decoration: const InputDecoration(
                  hintText:
                  "What's happening in your area?",
                  hintStyle: TextStyle(
                      color: MeerasTheme.textMuted,
                      fontSize: 15),
                  border: InputBorder.none,
                  filled: false,
                  counterStyle: TextStyle(
                      color: MeerasTheme.textMuted),
                ),
              ),
              const Divider(color: MeerasTheme.divider),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    setSheetState(
                            () => sending = true);
                    final result =
                    await ApiService.sendChat(text);
                    if (!context.mounted) return;
                    if (result['status'] == 201) {
                      Navigator.pop(ctx);
                      _loadPosts();
                    } else {
                      setSheetState(
                              () => sending = false);
                    }
                  },
                  child: sending
                      ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                      : const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter tab ────────────────────────────────────────────────────────────────

class _FilterTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final int count;
  final VoidCallback onTap;
  final Color accentColor;

  const _FilterTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.count,
    required this.onTap,
    this.accentColor = MeerasTheme.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? accentColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: active
                      ? accentColor
                      : MeerasTheme.textMuted),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                    color: active
                        ? accentColor
                        : MeerasTheme.textMuted,
                    fontSize: 13,
                    fontWeight: active
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? accentColor.withValues(alpha: 0.15)
                        : MeerasTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count',
                      style: TextStyle(
                        color: active
                            ? accentColor
                            : MeerasTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Post tile ─────────────────────────────────────────────────────────────────

class _PostTile extends StatelessWidget {
  final Map post;
  final String username;
  final bool isMine;
  final bool isVerified;
  final bool isFlagged;
  final Color avatarColor;
  final String timeAgo;
  final VoidCallback onFlag;
  final VoidCallback? onDelete;

  const _PostTile({
    required this.post,
    required this.username,
    required this.isMine,
    required this.isVerified,
    required this.isFlagged,
    required this.avatarColor,
    required this.timeAgo,
    required this.onFlag,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isFlagged
          ? MeerasTheme.danger.withValues(alpha: 0.04)
          : Colors.transparent,
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration:
            BoxDecoration(color: avatarColor, shape: BoxShape.circle),
            child: Center(
              child: Text(username[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + badges + time
                Row(
                  children: [
                    Text(username,
                        style: const TextStyle(
                            color: MeerasTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          color: Color(0xFF5B8DEF), size: 15),
                    ],
                    if (isFlagged) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MeerasTheme.danger
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Flagged',
                            style: TextStyle(
                                color: MeerasTheme.danger,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const Spacer(),
                    Text(timeAgo,
                        style: const TextStyle(
                            color: MeerasTheme.textMuted,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 5),

                // Message
                Text(post['message'] ?? '',
                    style: const TextStyle(
                        color: MeerasTheme.textPrimary,
                        fontSize: 14,
                        height: 1.45)),

                const SizedBox(height: 12),

                // Actions row
                Row(
                  children: [
                    // Flag button
                    if (!isFlagged)
                      GestureDetector(
                        onTap: onFlag,
                        child: const Row(children: [
                          Icon(Icons.flag_outlined,
                              size: 16,
                              color: MeerasTheme.textMuted),
                          SizedBox(width: 4),
                          Text('Flag',
                              style: TextStyle(
                                  color: MeerasTheme.textMuted,
                                  fontSize: 12)),
                        ]),
                      ),

                    if (isMine && onDelete != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: const Row(children: [
                          Icon(Icons.delete_outline,
                              size: 16,
                              color: MeerasTheme.danger),
                          SizedBox(width: 4),
                          Text('Delete',
                              style: TextStyle(
                                  color: MeerasTheme.danger,
                                  fontSize: 12)),
                        ]),
                      ),
                    ],

                    const Spacer(),
                    Text(_fullDate(post['timestamp']),
                        style: const TextStyle(
                            color: MeerasTheme.textMuted,
                            fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fullDate(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} · ${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final FeedFilter filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final data = {
      FeedFilter.all: (
      'No posts yet',
      'Be the first to post something',
      Icons.dynamic_feed_outlined
      ),
      FeedFilter.verified: (
      'No verified posts',
      'Posts verified by admins appear here',
      Icons.verified_outlined
      ),
      FeedFilter.flagged: (
      'No flagged posts',
      'Posts flagged for review appear here',
      Icons.flag_outlined
      ),
    }[filter]!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: MeerasTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(data.$3,
                color: MeerasTheme.accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(data.$1,
              style: const TextStyle(
                  color: MeerasTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(data.$2,
              style: const TextStyle(
                  color: MeerasTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
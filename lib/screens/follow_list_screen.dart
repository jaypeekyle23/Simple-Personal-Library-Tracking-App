import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'view_profile_screen.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent = Color(0xFF00C030);
}

class _P {
  final Color bg, surface, surfaceEl, border, divider,
      textPrimary, textSecondary, textMuted;
  const _P({required this.bg, required this.surface, required this.surfaceEl,
    required this.border, required this.divider, required this.textPrimary,
    required this.textSecondary, required this.textMuted});
  factory _P.dark() => const _P(
    bg: Color(0xFF0F1117), surface: Color(0xFF1A1D27),
    surfaceEl: Color(0xFF22263A), border: Color(0xFF2A2F45),
    divider: Color(0xFF252A3D), textPrimary: Color(0xFFEEEEEE),
    textSecondary: Color(0xFF8A8FA8), textMuted: Color(0xFF4A5068));
  factory _P.light() => const _P(
    bg: Color(0xFFF4F5F7), surface: Color(0xFFFFFFFF),
    surfaceEl: Color(0xFFEEF0F4), border: Color(0xFFDDE0E8),
    divider: Color(0xFFE8EAF0), textPrimary: Color(0xFF0F1117),
    textSecondary: Color(0xFF5A6070), textMuted: Color(0xFF9AA0B0));
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class FollowListScreen extends StatefulWidget {
  final String userId;
  final int initialIndex;

  const FollowListScreen(
      {super.key, required this.userId, this.initialIndex = 0});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _followersIds = [];
  List<String> _followingIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialIndex);
    _fetchConnections();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchConnections() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _followersIds = List<String>.from(data['followers'] ?? []);
          _followingIds = List<String>.from(data['following'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching connections: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getUsersData(
      List<String> ids) async {
    List<Map<String, dynamic>> users = [];
    for (String id in ids) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      if (doc.exists) users.add({'id': id, ...doc.data()!});
    }
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: p.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context)),
            centerTitle: true,
            title: Text('Connections',
              style: TextStyle(color: p.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: -0.3)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.border))),
                child: TabBar(
                  controller: _tabController,
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(
                        color: Color(0xFF00C030), width: 2),
                    insets: EdgeInsets.symmetric(horizontal: 24)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: _K.accent,
                  unselectedLabelColor: p.textMuted,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w400),
                  tabs: [
                    Tab(text: 'Followers ${_isLoading ? '' : '(${_followersIds.length})'}'),
                    Tab(text: 'Following ${_isLoading ? '' : '(${_followingIds.length})'}'),
                  ],
                ),
              ),
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: _K.accent, strokeWidth: 2.5))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUserList(_followersIds, p),
                    _buildUserList(_followingIds, p),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildUserList(List<String> ids, _P p) {
    if (ids.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline_rounded, size: 44, color: p.textMuted),
          const SizedBox(height: 14),
          Text('No users here yet',
            style: TextStyle(color: p.textSecondary,
              fontSize: 15, fontWeight: FontWeight.w300)),
        ]));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getUsersData(ids),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: _K.accent, strokeWidth: 2.5));
        }
        final users = snapshot.data ?? [];
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: users.length,
          separatorBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(left: 76),
            height: 1,
            color: p.divider),
          itemBuilder: (context, index) {
            final user = users[index];
            final picUrl   = user['profileImageUrl'] ?? '';
            final username = user['username'] ?? 'Reader';
            final bio      = user['bio'] ?? '';

            return _UserTile(
              p: p,
              picUrl: picUrl,
              username: username,
              bio: bio,
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) =>
                    ViewProfileScreen(userId: user['id']))),
            );
          },
        );
      },
    );
  }
}

// ─── User tile ────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final _P p;
  final String picUrl, username, bio;
  final VoidCallback onTap;

  const _UserTile({
    required this.p, required this.picUrl, required this.username,
    required this.bio, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: p.surfaceEl,
            backgroundImage:
                picUrl.isNotEmpty ? NetworkImage(picUrl) : null,
            child: picUrl.isEmpty
                ? Icon(Icons.person_rounded,
                    color: p.textMuted, size: 22)
                : null,
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(username,
                style: TextStyle(color: p.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(bio,
                  style: TextStyle(color: p.textSecondary, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ])),

          // Chevron
          Icon(Icons.chevron_right_rounded,
              color: p.textMuted, size: 18),
        ]),
      ),
    );
  }
}
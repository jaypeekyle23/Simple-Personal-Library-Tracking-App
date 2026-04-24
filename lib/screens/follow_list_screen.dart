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

  const FollowListScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(widget.userId).get();
          
      if (!userDoc.exists) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = userDoc.data()!;
      final rawFollowers = List<dynamic>.from(data['followers'] ?? []);
      final rawFollowing = List<dynamic>.from(data['following'] ?? []);

      // Helper to fetch only accounts that still exist in the database
      Future<List<Map<String, dynamic>>> fetchValidUsers(List<dynamic> ids) async {
        if (ids.isEmpty) return [];
        final docs = await Future.wait(
          ids.map((id) => FirebaseFirestore.instance.collection('users').doc(id.toString()).get())
        );
        
        // Filter out deleted accounts by checking doc.exists
        return docs
            .where((doc) => doc.exists)
            .map((doc) => {
                  'uid': doc.id,
                  ...?doc.data(),
                })
            .toList();
      }

      // We wait for the clean data before we build the lists
      final validFollowers = await fetchValidUsers(rawFollowers);
      final validFollowing = await fetchValidUsers(rawFollowing);

      if (mounted) {
        setState(() {
          _followers = validFollowers; // This is the clean, 100% accurate list
          _following = validFollowing; // This is the clean, 100% accurate list
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading follow list: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();
        
        return DefaultTabController(
          length: 2,
          initialIndex: widget.initialIndex,
          child: Scaffold(
            backgroundColor: p.bg,
            appBar: AppBar(
              backgroundColor: p.bg,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.textSecondary, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              bottom: TabBar(
                indicatorColor: _K.accent,
                indicatorWeight: 3,
                labelColor: p.textPrimary,
                unselectedLabelColor: p.textMuted,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                dividerColor: p.divider,
                tabs: [
                  // Now it uses the length of the valid list, not the raw array
                  Tab(text: _isLoading ? 'Followers' : 'Followers (${_followers.length})'),
                  Tab(text: _isLoading ? 'Following' : 'Following (${_following.length})'),
                ],
              ),
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _K.accent))
                : TabBarView(
                    children: [
                      _buildList(_followers, p, 'No followers yet.'),
                      _buildList(_following, p, 'Not following anyone yet.'),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<Map<String, dynamic>> users, _P p, String emptyMsg) {
    if (users.isEmpty) {
      return Center(
        child: Text(emptyMsg,
          style: TextStyle(color: p.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
      );
    }

    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: 70),
        child: Container(height: 1, color: p.divider),
      ),
      itemBuilder: (context, index) {
        final user = users[index];
        return _UserTile(
          p: p,
          uid: user['uid'],
          username: user['username'] ?? 'Unknown User',
          picUrl: user['profileImageUrl'] ?? '',
          bio: user['bio'] ?? '',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ViewProfileScreen(userId: user['uid'])
            ));
          },
        );
      },
    );
  }
}

// ─── User Tile ────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final _P p;
  final String uid, username, picUrl, bio;
  final VoidCallback onTap;

  const _UserTile({
    required this.p, required this.uid, required this.username,
    required this.picUrl, required this.bio, required this.onTap,
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
          Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 18),
        ]),
      ),
    );
  }
}
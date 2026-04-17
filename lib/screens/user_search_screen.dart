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
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: p.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context)),
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border)),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: p.textPrimary, fontSize: 14),
                  cursorColor: _K.accent,
                  decoration: InputDecoration(
                    hintText: 'Search usernames…',
                    hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: p.textMuted, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.close_rounded,
                                color: p.textMuted, size: 16))
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 11)),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim()),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: p.border, height: 1)),
          ),
          body: _searchQuery.isEmpty
              ? _buildEmptyPrompt(p)
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('username',
                          isGreaterThanOrEqualTo: _searchQuery)
                      .where('username',
                          isLessThan: '${_searchQuery}z')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: _K.accent, strokeWidth: 2.5));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 44, color: p.textMuted),
                          const SizedBox(height: 14),
                          Text('No users found',
                            style: TextStyle(color: p.textSecondary,
                              fontSize: 15, fontWeight: FontWeight.w300)),
                          const SizedBox(height: 4),
                          Text('Try a different username',
                            style: TextStyle(
                                color: p.textMuted, fontSize: 12)),
                        ],
                      ));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Container(
                          margin: const EdgeInsets.only(left: 72),
                          height: 1,
                          color: p.divider),
                      itemBuilder: (context, index) {
                        final data =
                            docs[index].data() as Map<String, dynamic>;
                        final userId  = docs[index].id;
                        final username = data['username'] ?? 'User';
                        final pic = data['profileImageUrl'] ?? '';
                        final bio = data['bio'] ?? '';

                        return _UserTile(
                          p: p,
                          username: username,
                          bio: bio,
                          pic: pic,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) =>
                                ViewProfileScreen(userId: userId))),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyPrompt(_P p) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: p.surfaceEl,
              shape: BoxShape.circle,
              border: Border.all(color: p.border)),
            child: Icon(Icons.people_outline_rounded,
                size: 30, color: p.textMuted)),
          const SizedBox(height: 16),
          Text('Find readers to follow',
            style: TextStyle(color: p.textSecondary,
              fontSize: 15, fontWeight: FontWeight.w300)),
          const SizedBox(height: 4),
          Text('Type a username to start searching',
            style: TextStyle(color: p.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── User tile ────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final _P p;
  final String username, bio, pic;
  final VoidCallback onTap;

  const _UserTile({
    required this.p, required this.username, required this.bio,
    required this.pic, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: p.surfaceEl,
            backgroundImage:
                pic.isNotEmpty ? NetworkImage(pic) : null,
            child: pic.isEmpty
                ? Icon(Icons.person_rounded,
                    color: p.textMuted, size: 22)
                : null),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(username,
                style: TextStyle(color: p.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(bio,
                  style: TextStyle(
                      color: p.textSecondary, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ])),
          Icon(Icons.chevron_right_rounded,
              color: p.textMuted, size: 18),
        ]),
      ),
    );
  }
}
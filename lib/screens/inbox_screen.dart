import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'chat_screen.dart';

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
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
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
            title: Text('Messages',
              style: TextStyle(color: p.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          ),
          body: currentUser == null
            ? const SizedBox()
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: currentUser!.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading messages.',
                      style: TextStyle(color: p.textSecondary)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: _K.accent, strokeWidth: 2.5));
                  }

                  var docs = snapshot.data?.docs ?? [];

                  // Sort newest first
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aTime = aData['lastMessageTime'] as Timestamp?;
                    final bTime = bData['lastMessageTime'] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                  if (docs.isEmpty) {
                    return Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: p.surfaceEl,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.border)),
                          child: Icon(Icons.chat_bubble_outline_rounded,
                              size: 30, color: p.textMuted)),
                        const SizedBox(height: 16),
                        Text('No messages yet',
                          style: TextStyle(color: p.textSecondary,
                            fontSize: 15, fontWeight: FontWeight.w300)),
                        const SizedBox(height: 4),
                        Text('Start a conversation from someone\'s profile',
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      ]));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => Container(
                      margin: const EdgeInsets.only(left: 76),
                      height: 1, color: p.divider),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final participants =
                          List<String>.from(data['participants'] ?? []);
                      final targetUserId = participants.firstWhere(
                          (id) => id != currentUser!.uid, orElse: () => '');
                      if (targetUserId.isEmpty) return const SizedBox.shrink();

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(targetUserId)
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox.shrink();
                          final userData = userSnap.data!.data()
                              as Map<String, dynamic>?;
                          if (userData == null) return const SizedBox.shrink();

                          final name    = userData['username'] ?? 'User';
                          final pic     = userData['profileImageUrl'] ?? '';
                          final lastMsg = data['lastMessage'] ?? '';
                          final time    = _timeAgo(
                              data['lastMessageTime'] as Timestamp?);

                          return _ConversationTile(
                            p: p,
                            name: name,
                            pic: pic,
                            lastMsg: lastMsg,
                            time: time,
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ChatScreen(
                                targetUserId: targetUserId,
                                targetUserName: name,
                                targetUserPic: pic,
                              ))),
                          );
                        },
                      );
                    },
                  );
                },
              ),
        );
      },
    );
  }
}

// ─── Conversation tile ────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final _P p;
  final String name, pic, lastMsg, time;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.p, required this.name, required this.pic,
    required this.lastMsg, required this.time, required this.onTap,
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
            radius: 24,
            backgroundColor: p.surfaceEl,
            backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
            child: pic.isEmpty
                ? Icon(Icons.person_rounded, color: p.textMuted, size: 24)
                : null,
          ),
          const SizedBox(width: 14),

          // Name + preview
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                style: TextStyle(color: p.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text(lastMsg,
                style: TextStyle(color: p.textSecondary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),

          const SizedBox(width: 10),

          // Timestamp
          Text(time,
            style: TextStyle(color: p.textMuted, fontSize: 11,
              fontWeight: FontWeight.w400)),
        ]),
      ),
    );
  }
}
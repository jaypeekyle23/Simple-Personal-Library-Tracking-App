import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'view_profile_screen.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent = Color(0xFF00C030);
  static const red    = Color(0xFFFF5555);
  static const blue   = Color(0xFF4A9EFF);
}

class _P {
  final Color bg, surface, surfaceEl, border, textPrimary, textSecondary, textMuted;
  const _P({required this.bg, required this.surface, required this.surfaceEl, required this.border, required this.textPrimary, required this.textSecondary, required this.textMuted});
  factory _P.dark() => const _P(bg: Color(0xFF0F1117), surface: Color(0xFF1A1D27), surfaceEl: Color(0xFF22263A), border: Color(0xFF2A2F45), textPrimary: Color(0xFFEEEEEE), textSecondary: Color(0xFF8A8FA8), textMuted: Color(0xFF4A5068));
  factory _P.light() => const _P(bg: Color(0xFFF4F5F7), surface: Color(0xFFFFFFFF), surfaceEl: Color(0xFFEEF0F4), border: Color(0xFFDDE0E8), textPrimary: Color(0xFF0F1117), textSecondary: Color(0xFF5A6070), textMuted: Color(0xFF9AA0B0));
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

  // ─── NEW: Pre-define streams to prevent constant reloading ───
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _notifStream;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots();
          
      _notifStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Just now';
  }

  Future<void> _handleRequest(String requesterId, bool accept) async {
    if (currentUser == null) return;
    final myRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
    final requesterRef = FirebaseFirestore.instance.collection('users').doc(requesterId);

    if (accept) {
      await myRef.update({
        'followRequests': FieldValue.arrayRemove([requesterId]),
        'followers': FieldValue.arrayUnion([requesterId])
      });
      await requesterRef.update({
        'following': FieldValue.arrayUnion([currentUser!.uid])
      });
    } else {
      await myRef.update({
        'followRequests': FieldValue.arrayRemove([requesterId])
      });
    }
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
            backgroundColor: p.bg, surfaceTintColor: Colors.transparent, elevation: 0,
            leading: Navigator.canPop(context) 
                ? IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.textPrimary, size: 20), 
                    onPressed: () => Navigator.pop(context)
                  )
                : null,
            title: Text('Activity', style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            centerTitle: true,
          ),
          body: currentUser == null 
            ? const Center(child: Text('Not logged in'))
            : StreamBuilder<DocumentSnapshot>(
                stream: _userStream, // ─── USE PRE-DEFINED STREAM ───
                builder: (context, reqSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _notifStream, // ─── USE PRE-DEFINED STREAM ───
                    builder: (context, notifSnapshot) {
                      
                      List requests = [];
                      if (reqSnapshot.hasData && reqSnapshot.data!.exists) {
                        final data = reqSnapshot.data!.data() as Map<String, dynamic>?;
                        if (data != null) requests = data['followRequests'] ?? [];
                      }

                      List<QueryDocumentSnapshot> notifs = [];
                      if (notifSnapshot.hasData) {
                        notifs = notifSnapshot.data!.docs;
                      }
                      
                      bool isLoading = notifSnapshot.connectionState == ConnectionState.waiting;

                      return CustomScrollView(
                        slivers: [
                          // 1. TOP SECTION: Follow Requests
                          if (requests.isNotEmpty)
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final requesterId = requests[index];
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('users').doc(requesterId).get(),
                                    builder: (context, reqSnap) {
                                      if (!reqSnap.hasData) return const SizedBox.shrink();
                                      final reqData = reqSnap.data!.data() as Map<String, dynamic>?;
                                      if (reqData == null) return const SizedBox.shrink();

                                      final username = reqData['username'] ?? 'Someone';
                                      final picUrl = reqData['profileImageUrl'] ?? '';

                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(userId: requesterId))),
                                              child: CircleAvatar(radius: 20, backgroundColor: p.surfaceEl, backgroundImage: picUrl.isNotEmpty ? NetworkImage(picUrl) : null, child: picUrl.isEmpty ? Icon(Icons.person, color: p.textMuted) : null),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(username, style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                                  Text('Requested to follow you', style: TextStyle(color: p.textSecondary, fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                GestureDetector(onTap: () => _handleRequest(requesterId, true), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: _K.accent, borderRadius: BorderRadius.circular(6)), child: const Text('Confirm', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)))),
                                                const SizedBox(width: 8),
                                                GestureDetector(onTap: () => _handleRequest(requesterId, false), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: p.surfaceEl, borderRadius: BorderRadius.circular(6), border: Border.all(color: p.border)), child: Text('Delete', style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)))),
                                              ],
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                                childCount: requests.length,
                              ),
                            ),

                          // 2. BOTTOM SECTION: Standard Notifications
                          if (isLoading)
                            SliverToBoxAdapter(child: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: CircularProgressIndicator(color: _K.accent))))
                          else if (notifs.isEmpty)
                            SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 80),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications_off_outlined, size: 48, color: p.textMuted),
                                      const SizedBox(height: 16),
                                      Text('No new activity', style: TextStyle(color: p.textSecondary, fontSize: 15)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final data = notifs[index].data() as Map<String, dynamic>;
                                  final type = data['type'] ?? 'like';
                                  final senderName = data['senderName'] ?? 'Someone';
                                  final senderPic = data['senderPic'] ?? '';
                                  final text = data['text'] ?? '';
                                  final senderId = data['senderId'] ?? '';
                                  
                                  IconData icon;
                                  Color iconColor;
                                  String actionText;

                                  if (type == 'like') {
                                    icon = Icons.favorite_rounded;
                                    iconColor = _K.red;
                                    actionText = ' liked your post.';
                                  } else if (type == 'comment_like') {
                                    // NEW: Handle comment likes
                                    icon = Icons.favorite_rounded;
                                    iconColor = _K.red;
                                    actionText = ' liked your comment.';
                                  } else if (type == 'comment') {
                                    icon = Icons.chat_bubble_rounded;
                                    iconColor = _K.accent;
                                    actionText = ' commented on your post.';
                                  } else {
                                    icon = Icons.person_add_rounded;
                                    iconColor = _K.blue;
                                    actionText = ' started following you.';
                                  }

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.border)),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () { if (senderId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => ViewProfileScreen(userId: senderId))); },
                                          child: Stack(
                                            children: [
                                              CircleAvatar(radius: 20, backgroundColor: p.surfaceEl, backgroundImage: senderPic.isNotEmpty ? NetworkImage(senderPic) : null, child: senderPic.isEmpty ? Icon(Icons.person, color: p.textMuted) : null),
                                              Positioned(
                                                bottom: 0, right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
                                                  child: Icon(icon, size: 12, color: iconColor),
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.4),
                                                  children: [
                                                    TextSpan(text: senderName, style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.bold)),
                                                    TextSpan(text: actionText),
                                                  ]
                                                )
                                              ),
                                              if (type == 'comment' && text.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text('"$text"', style: TextStyle(color: p.textPrimary, fontSize: 13, fontStyle: FontStyle.italic)),
                                              ],
                                              const SizedBox(height: 4),
                                              Text(_timeAgo(data['createdAt'] as Timestamp?), style: TextStyle(color: p.textMuted, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                childCount: notifs.length,
                              ),
                            ),
                        ],
                      );
                    }
                  );
                }
              ),
        );
      },
    );
  }
}
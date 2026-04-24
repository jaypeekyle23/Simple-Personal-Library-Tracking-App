import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // NEW IMPORT
import '../main.dart';
import 'view_profile_screen.dart';
import 'notifications_screen.dart';
import 'inbox_screen.dart';
import 'user_search_screen.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent = Color(0xFF00C030);
  static const danger = Color(0xFFFF3B30);
  static const amber  = Color(0xFFFFB800);
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
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  List<String> _followingIds = [];
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _listenToFollowingList();
    _setupPushNotifications(); // NEW FUNCTION CALL
  }

  // NEW FUNCTION: Request push notification permission and save token
  Future<void> _setupPushNotifications() async {
    if (currentUser == null) return;
    
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission (Shows the popup on iOS/Android)
    NotificationSettings settings = await messaging.requestPermission();
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the unique token for this specific physical phone
      String? token = await messaging.getToken();
      
      // Save it to their user document in Firestore
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .update({'fcmToken': token});
      }
    }
  }

  // ─── UPDATED: Filter out deleted accounts so their posts don't appear ───
  void _listenToFollowingList() {
    if (currentUser == null) return;
    _userSubscription = FirebaseFirestore.instance
        .collection('users').doc(currentUser!.uid).snapshots().listen((doc) async {
      if (doc.exists && mounted) {
        final rawFollowing = List<String>.from(doc.data()?['following'] ?? []);
        
        if (rawFollowing.isEmpty) {
          setState(() => _followingIds = []);
          return;
        }
        
        try {
          // Cross-reference to find only users that still exist
          final validDocs = await Future.wait(
            rawFollowing.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get())
          );
          
          final validIds = validDocs
              .where((d) => d.exists)
              .map((d) => d.id)
              .toList();
              
          // Update the list with ONLY valid IDs. Ghost accounts are dropped.
          if (mounted) {
            setState(() => _followingIds = validIds);
          }
        } catch (e) {
          debugPrint('Error validating following list: $e');
          // Fallback in case of a network error
          if (mounted) setState(() => _followingIds = rawFollowing);
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inDays > 365) return '${(d.inDays / 365).floor()}y';
    if (d.inDays > 30)  return '${(d.inDays / 30).floor()}mo';
    if (d.inDays > 0)   return '${d.inDays}d';
    if (d.inHours > 0)  return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return 'Just now';
  }

  Future<void> _clearNotifications() async {
    if (currentUser == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final unread = await FirebaseFirestore.instance
          .collection('users').doc(currentUser!.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false).get();
      for (var doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) { debugPrint('Error clearing notifications: $e'); }
  }

  Future<void> _toggleLike(String postId, List likes, String ownerId) async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('feed').doc(postId);
    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
      if (ownerId.isNotEmpty && ownerId != uid) {
        try {
          await FirebaseFirestore.instance.collection('users')
              .doc(ownerId).collection('notifications')
              .doc('${postId}_${uid}_like').delete();
        } catch (e) { debugPrint('Notif: $e'); }
      }
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
      if (ownerId.isNotEmpty && ownerId != uid) {
        try {
          final me = await FirebaseFirestore.instance
              .collection('users').doc(uid).get();
          await FirebaseFirestore.instance.collection('users')
              .doc(ownerId).collection('notifications')
              .doc('${postId}_${uid}_like').set({
            'type': 'like', 'senderId': uid,
            'senderName': me.data()?['username'] ?? 'Someone',
            'senderPic': me.data()?['profileImageUrl'] ?? '',
            'postId': postId, 'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) { debugPrint('Notif: $e'); }
      }
    }
  }

  // --- Toggle Comment Like ---
  Future<void> _toggleCommentLike(String postId, String commentId, List likes, String commentOwnerId) async {
    if (currentUser == null) return;
    final uid = currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('feed').doc(postId).collection('comments').doc(commentId);
    
    if (likes.contains(uid)) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
      if (commentOwnerId.isNotEmpty && commentOwnerId != uid) {
        try {
          await FirebaseFirestore.instance.collection('users')
              .doc(commentOwnerId).collection('notifications')
              .doc('${commentId}_${uid}_commentlike').delete();
        } catch (e) { debugPrint('Notif: $e'); }
      }
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
      if (commentOwnerId.isNotEmpty && commentOwnerId != uid) {
        try {
          final me = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          await FirebaseFirestore.instance.collection('users')
              .doc(commentOwnerId).collection('notifications')
              .doc('${commentId}_${uid}_commentlike').set({
            'type': 'comment_like', 'senderId': uid,
            'senderName': me.data()?['username'] ?? 'Someone',
            'senderPic': me.data()?['profileImageUrl'] ?? '',
            'postId': postId, 'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) { debugPrint('Notif: $e'); }
      }
    }
  }

  void _showCommentsSheet(BuildContext ctx, String postId,
      String postOwnerId, _P p) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: p.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.75,
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
              decoration: BoxDecoration(color: p.border,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 14),
            Text('Comments', style: TextStyle(color: p.textPrimary,
                fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Container(height: 1, color: p.border),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('feed')
                  .doc(postId).collection('comments')
                  .orderBy('createdAt').snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(
                      color: _K.accent, strokeWidth: 2.5));
                }
                final comments = snap.data?.docs ?? [];
                if (comments.isEmpty) {
                  return Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 36, color: p.textMuted),
                      const SizedBox(height: 10),
                      Text('No comments yet', style: TextStyle(
                          color: p.textSecondary, fontSize: 14,
                          fontWeight: FontWeight.w300)),
                    ]));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i].data() as Map<String, dynamic>;
                    final commentId = comments[i].id; // Needed for like/delete
                    final pic = c['userPicUrl'] ?? '';
                    final commentOwnerId = c['uid'] ?? '';
                    
                    // Comment Like data
                    final List commentLikes = c['likes'] ?? [];
                    final bool isCommentLiked = currentUser != null && commentLikes.contains(currentUser!.uid);
                    
                    // Can delete if they own the post OR they own the comment
                    final bool canDelete = currentUser != null && (postOwnerId == currentUser!.uid || commentOwnerId == currentUser!.uid);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Clickable Avatar
                          GestureDetector(
                            onTap: () {
                              if (commentOwnerId.isNotEmpty) {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ViewProfileScreen(userId: commentOwnerId)));
                              }
                            },
                            child: CircleAvatar(radius: 13,
                              backgroundColor: p.surfaceEl,
                              backgroundImage: pic.isNotEmpty ? NetworkImage(pic) : null,
                              child: pic.isEmpty ? Icon(Icons.person, size: 13, color: p.textMuted) : null),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                // Clickable Username
                                GestureDetector(
                                  onTap: () {
                                    if (commentOwnerId.isNotEmpty) {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => ViewProfileScreen(userId: commentOwnerId)));
                                    }
                                  },
                                  child: Text(c['username'] ?? 'User',
                                    style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                                ),
                                const SizedBox(width: 6),
                                Text(_timeAgo(c['createdAt'] as Timestamp?),
                                  style: TextStyle(color: p.textMuted, fontSize: 11)),
                                const Spacer(),
                                // Delete button
                                if (canDelete)
                                  GestureDetector(
                                    onTap: () => _showDeleteCommentDialog(context, postId, commentId, p),
                                    child: Icon(Icons.delete_outline_rounded, size: 14, color: p.textMuted),
                                  )
                              ]),
                              const SizedBox(height: 3),
                              Text(c['text'] ?? '',
                                style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.4)),
                              
                              const SizedBox(height: 6),
                              // Like Comment Button
                              GestureDetector(
                                onTap: () => _toggleCommentLike(postId, commentId, commentLikes, commentOwnerId),
                                child: Row(
                                  children: [
                                    Icon(isCommentLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                                        size: 12, color: isCommentLiked ? _K.danger : p.textMuted),
                                    const SizedBox(width: 4),
                                    Text(commentLikes.isNotEmpty ? '${commentLikes.length}' : 'Like', 
                                        style: TextStyle(color: isCommentLiked ? _K.danger : p.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            ])),
                        ]),
                    );
                  });
              })),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: p.surface,
                  border: Border(top: BorderSide(color: p.border))),
              child: Row(children: [
                Expanded(child: TextField(controller: ctrl,
                  style: TextStyle(color: p.textPrimary, fontSize: 14),
                  cursorColor: _K.accent,
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    hintStyle: TextStyle(color: p.textMuted),
                    border: InputBorder.none, isDense: true))),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () async {
                    if (ctrl.text.trim().isEmpty ||
                        currentUser == null) return;
                    final text = ctrl.text.trim();
                    ctrl.clear();
                    final me = await FirebaseFirestore.instance
                        .collection('users').doc(currentUser!.uid).get();
                    await FirebaseFirestore.instance.collection('feed')
                        .doc(postId).collection('comments').add({
                      'uid': currentUser!.uid,
                      'username': me.data()?['username'] ?? 'User',
                      'userPicUrl': me.data()?['profileImageUrl'] ?? '',
                      'text': text,
                      'likes': [], // Initialize likes array
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    await FirebaseFirestore.instance.collection('feed')
                        .doc(postId).update(
                            {'commentCount': FieldValue.increment(1)});
                    if (postOwnerId.isNotEmpty &&
                        postOwnerId != currentUser!.uid) {
                      try {
                        await FirebaseFirestore.instance.collection('users')
                            .doc(postOwnerId).collection('notifications')
                            .add({
                          'type': 'comment', 'senderId': currentUser!.uid,
                          'senderName': me.data()?['username'] ?? 'Someone',
                          'senderPic': me.data()?['profileImageUrl'] ?? '',
                          'postId': postId, 'text': text, 'isRead': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      } catch (e) { debugPrint('Notif: $e'); }
                    }
                  },
                  child: Container(width: 34, height: 34,
                    decoration: const BoxDecoration(
                        color: _K.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.black, size: 18))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext ctx, String postId, _P p) {
    showDialog(context: ctx, builder: (dCtx) => Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Delete Post', style: TextStyle(color: p.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Are you sure you want to delete this activity?',
            style: TextStyle(color: p.textSecondary,
                fontSize: 13, height: 1.5)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(dCtx),
              child: Container(height: 40,
                decoration: BoxDecoration(color: p.surfaceEl,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border)),
                child: Center(child: Text('Cancel', style: TextStyle(
                    color: p.textSecondary, fontSize: 13,
                    fontWeight: FontWeight.w500)))))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(dCtx);
                await FirebaseFirestore.instance
                    .collection('feed').doc(postId).delete();
              },
              child: Container(height: 40,
                decoration: BoxDecoration(
                  color: _K.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _K.danger.withOpacity(0.35))),
                child: const Center(child: Text('Delete',
                  style: TextStyle(color: _K.danger, fontSize: 13,
                      fontWeight: FontWeight.w600)))))),
          ]),
        ]),
      ),
    ));
  }

  // --- NEW: Delete Comment Dialog ---
  void _showDeleteCommentDialog(BuildContext ctx, String postId, String commentId, _P p) {
    showDialog(context: ctx, builder: (dCtx) => Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Delete Comment', style: TextStyle(color: p.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Are you sure you want to delete this comment?',
            style: TextStyle(color: p.textSecondary,
                fontSize: 13, height: 1.5)),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(dCtx),
              child: Container(height: 40,
                decoration: BoxDecoration(color: p.surfaceEl,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border)),
                child: Center(child: Text('Cancel', style: TextStyle(
                    color: p.textSecondary, fontSize: 13,
                    fontWeight: FontWeight.w500)))))),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () async {
                Navigator.pop(dCtx);
                await FirebaseFirestore.instance.collection('feed').doc(postId).collection('comments').doc(commentId).delete();
                await FirebaseFirestore.instance.collection('feed').doc(postId).update({'commentCount': FieldValue.increment(-1)});
              },
              child: Container(height: 40,
                decoration: BoxDecoration(
                  color: _K.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _K.danger.withOpacity(0.35))),
                child: const Center(child: Text('Delete',
                  style: TextStyle(color: _K.danger, fontSize: 13,
                      fontWeight: FontWeight.w600)))))),
          ]),
        ]),
      ),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg, elevation: 0,
            surfaceTintColor: Colors.transparent, titleSpacing: 20,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Folio', style: TextStyle(color: p.textPrimary,
                    fontSize: 24, fontWeight: FontWeight.w300,
                    letterSpacing: -1.0)),
                const Text('.', style: TextStyle(color: _K.accent,
                    fontSize: 24, fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.search_rounded,
                    color: p.textSecondary, size: 22),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const UserSearchScreen()))),
              StreamBuilder<QuerySnapshot>(
                stream: currentUser == null ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('users').doc(currentUser!.uid)
                        .collection('notifications')
                        .where('isRead', isEqualTo: false).snapshots(),
                builder: (_, snap) {
                  final unread = snap.data?.docs.length ?? 0;
                  return Badge(
                    label: Text('$unread'),
                    isLabelVisible: unread > 0,
                    backgroundColor: _K.danger,
                    offset: const Offset(-4, 4),
                    child: IconButton(
                      icon: Icon(Icons.notifications_none_rounded,
                          color: p.textSecondary, size: 22),
                      onPressed: () {
                        _clearNotifications();
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()));
                      }));
                }),
              IconButton(
                icon: Icon(Icons.send_rounded,
                    color: p.textSecondary, size: 20),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const InboxScreen()))),
              const SizedBox(width: 4),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('feed')
                .orderBy('createdAt', descending: true)
                .limit(100).snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                    color: _K.accent, strokeWidth: 2.5));
              }
              final all = snap.data?.docs ?? [];
              final docs = all.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final oid = d['userId'] ?? '';
                // Since _followingIds only contains active users, 
                // posts from deleted accounts will naturally fail this check and hide!
                return oid == currentUser?.uid ||
                    _followingIds.contains(oid);
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: p.surfaceEl,
                        shape: BoxShape.circle,
                        border: Border.all(color: p.border)),
                      child: Icon(Icons.people_alt_outlined,
                          size: 30, color: p.textMuted)),
                    const SizedBox(height: 20),
                    Text('Your Feed', style: TextStyle(color: p.textPrimary,
                        fontSize: 18, fontWeight: FontWeight.w600,
                        letterSpacing: -0.4)),
                    const SizedBox(height: 6),
                    Text(
                      'Follow more people to see their reading activity here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textSecondary,
                          fontSize: 13, height: 1.6)),
                  ])));
              }

              return ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final docId = docs[i].id;
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _FeedCard(
                    p: p, postId: docId, data: data,
                    currentUserId: currentUser?.uid ?? '',
                    timeAgo: _timeAgo,
                    onLike: (likes) => _toggleLike(
                        docId, likes, data['userId'] ?? ''),
                    onComment: () => _showCommentsSheet(
                        context, docId, data['userId'] ?? '', p),
                    onDelete: () => _showDeleteDialog(context, docId, p),
                  );
                });
            }),
        );
      });
  }
}

// ─── Feed card ────────────────────────────────────────────────────────────────
class _FeedCard extends StatelessWidget {
  final _P p;
  final String postId, currentUserId;
  final Map<String, dynamic> data;
  final String Function(Timestamp?) timeAgo;
  final void Function(List) onLike;
  final VoidCallback onComment, onDelete;

  const _FeedCard({
    required this.p, required this.postId, required this.currentUserId,
    required this.data, required this.timeAgo, required this.onLike,
    required this.onComment, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ownerId    = data['userId'] ?? '';
    final username   = data['username'] ?? 'Someone';
    final userPic    = data['userPicUrl'] ?? '';
    final action     = data['action'] ?? 'added a book';
    final bookTitle  = data['bookTitle'] ?? 'Unknown Book';
    final bookAuthor = data['bookAuthor'] ?? 'Unknown Author';
    final coverUrl   = data['coverUrl'] ?? '';
    final createdAt  = data['createdAt'] as Timestamp?;
    final rating     = data['rating'] as int?;
    final review     = data['reviewText'] as String?;
    final List likes = data['likes'] ?? [];
    final int cmts   = data['commentCount'] ?? 0;
    final bool liked =
        currentUserId.isNotEmpty && likes.contains(currentUserId);
    final bool mine  =
        currentUserId.isNotEmpty && ownerId == currentUserId;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () {
                  if (ownerId.isNotEmpty) Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                          ViewProfileScreen(userId: ownerId)));
                },
                child: Container(width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: p.surfaceEl,
                    border: Border.all(color: p.border),
                    image: userPic.isNotEmpty ? DecorationImage(
                        image: NetworkImage(userPic),
                        fit: BoxFit.cover) : null),
                  child: userPic.isEmpty ? Icon(Icons.person_rounded,
                      size: 18, color: p.textMuted) : null)),
              const SizedBox(width: 10),
              Expanded(child: RichText(text: TextSpan(
                style: TextStyle(color: p.textSecondary, fontSize: 13),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () {
                        if (ownerId.isNotEmpty) Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                ViewProfileScreen(userId: ownerId)));
                      },
                      child: Text(username, style: TextStyle(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600, fontSize: 13)))),
                  TextSpan(text: '  $action'),
                ]))),
              const SizedBox(width: 8),
              Text(timeAgo(createdAt),
                  style: TextStyle(color: p.textMuted, fontSize: 11)),
              if (mine) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: onDelete,
                  child: Padding(padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 16, color: p.textMuted))),
              ],
            ])),

          // ── Book ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(7),
                  child: coverUrl.isNotEmpty
                    ? Image.network(coverUrl, width: 52, height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _cover(p))
                    : _cover(p)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bookTitle, style: TextStyle(
                        color: p.textPrimary, fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(bookAuthor, style: TextStyle(
                        color: p.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (rating != null && rating > 0) ...[
                      const SizedBox(height: 8),
                      Row(mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < rating ? _K.amber : p.textMuted,
                            size: 14)))),
                    ],
                  ])),
              ])),

          // ── Review ──────────────────────────────────────────────
          if (review != null && review.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.surfaceEl,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: p.border)),
                child: Text(review, style: TextStyle(
                  color: p.textSecondary, fontSize: 13,
                  height: 1.55, fontWeight: FontWeight.w400)))),

          // ── Actions ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              GestureDetector(
                onTap: () => onLike(likes),
                child: Container(color: Colors.transparent,
                  child: Row(children: [
                    Icon(liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                      size: 18,
                      color: liked ? _K.danger : p.textMuted),
                    const SizedBox(width: 5),
                    Text(likes.isNotEmpty ? '${likes.length}' : 'Like',
                      style: TextStyle(
                        color: liked ? _K.danger : p.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ]))),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onComment,
                child: Container(color: Colors.transparent,
                  child: Row(children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 16, color: p.textMuted),
                    const SizedBox(width: 5),
                    Text(cmts > 0 ? '$cmts' : 'Comment',
                      style: TextStyle(color: p.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                  ]))),
            ])),
        ]),
    );
  }

  Widget _cover(_P p) => Container(width: 52, height: 76,
    decoration: BoxDecoration(color: p.surfaceEl,
        borderRadius: BorderRadius.circular(7)),
    child: Icon(Icons.book_outlined, color: p.textMuted, size: 22));
}
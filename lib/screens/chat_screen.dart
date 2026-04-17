import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final String targetUserPic;

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserPic,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String get _chatId {
    if (currentUser == null) return '';
    List<String> ids = [currentUser!.uid, widget.targetUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty || currentUser == null) return;
    final text = _msgController.text.trim();
    _msgController.clear();

    final chatRef =
        FirebaseFirestore.instance.collection('chats').doc(_chatId);

    // 1. Save message to chat history
    await chatRef.collection('messages').add({
      'senderId': currentUser!.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update the chat document with the latest message
    await chatRef.set({
      'participants': [currentUser!.uid, widget.targetUserId],
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ─── NOTIFICATION TRIGGER CODE START ───
    
    // First, get your own username so the notification knows who it is from
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    final myUsername = myDoc.data()?['username'] ?? 'Someone';

    // Second, drop the trigger document into the Target User's notifications folder!
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.targetUserId) // The person receiving the message
        .collection('notifications')
        .add({
      'type': 'message', // This matches case "message": in your index.ts!
      'senderName': myUsername,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'chatId': _chatId,
    });
    
    // ─── NOTIFICATION TRIGGER CODE END ───
  }

  @override
  void dispose() {
    _msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final isDark = mode == ThemeMode.dark;

        final bg            = isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F5F7);
        final surface       = isDark ? const Color(0xFF1A1D27) : const Color(0xFFFFFFFF);
        final surfaceEl     = isDark ? const Color(0xFF22263A) : const Color(0xFFEEF0F4);
        final border        = isDark ? const Color(0xFF2A2F45) : const Color(0xFFDDE0E8);
        final textPrimary   = isDark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1117);
        final textSecondary = isDark ? const Color(0xFF8A8FA8) : const Color(0xFF5A6070);
        final textMuted     = isDark ? const Color(0xFF4A5068) : const Color(0xFF9AA0B0);
        const accent        = Color(0xFF00C030);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: textSecondary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                // Avatar
                _Avatar(
                  picUrl: widget.targetUserPic,
                  name: widget.targetUserName,
                  surface: surfaceEl,
                  textMuted: textMuted,
                  radius: 17,
                ),
                const SizedBox(width: 10),
                // Name + online hint
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.targetUserName,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Folio reader',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          body: Column(
            children: [

              // ── Thin top border ──────────────────────────────────────
              Container(height: 1, color: border),

              // ── Message list ─────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(_chatId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: accent, strokeWidth: 2.5));
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(
                                color: surfaceEl,
                                shape: BoxShape.circle,
                                border: Border.all(color: border),
                              ),
                              child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: textMuted, size: 26),
                            ),
                            const SizedBox(height: 14),
                            Text('No messages yet',
                              style: TextStyle(color: textSecondary,
                                fontSize: 15, fontWeight: FontWeight.w300)),
                            const SizedBox(height: 4),
                            Text('Say hello to ${widget.targetUserName}!',
                              style: TextStyle(
                                  color: textMuted, fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data()
                            as Map<String, dynamic>;
                        final isMe =
                            data['senderId'] == currentUser?.uid;

                        return _MessageBubble(
                          text: data['text'] ?? '',
                          isMe: isMe,
                          surface: surface,
                          border: border,
                          textPrimary: textPrimary,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Input bar ────────────────────────────────────────────
              Container(
                padding: EdgeInsets.only(
                  left: 16, right: 12,
                  top: 10, bottom: 10 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Text field
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: border)),
                        child: TextField(
                          controller: _msgController,
                          focusNode: _focusNode,
                          style: TextStyle(
                              color: textPrimary, fontSize: 14),
                          cursorColor: accent,
                          maxLines: null,
                          textCapitalization:
                              TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Message…',
                            hintStyle: TextStyle(
                                color: textMuted, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Send button
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String picUrl;
  final String name;
  final Color surface;
  final Color textMuted;
  final double radius;

  const _Avatar({
    required this.picUrl, required this.name,
    required this.surface, required this.textMuted,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: surface,
    backgroundImage:
        picUrl.isNotEmpty ? NetworkImage(picUrl) : null,
    child: picUrl.isEmpty
        ? Icon(Icons.person_rounded, size: radius, color: textMuted)
        : null,
  );
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final Color surface;
  final Color border;
  final Color textPrimary;

  const _MessageBubble({
    required this.text, required this.isMe,
    required this.surface, required this.border,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00C030);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? accent : surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe ? null : Border.all(color: border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.black : textPrimary,
            fontSize: 14,
            fontWeight:
                isMe ? FontWeight.w500 : FontWeight.w400,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
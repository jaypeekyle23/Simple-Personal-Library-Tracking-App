import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/book.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _K {
  static const accent     = Color(0xFF00C030);
  static const accentDim  = Color(0xFF00C03018);
  static const amber      = Color(0xFFEFC050);
  static const amberDim   = Color(0xFFEFC05022);
}

class ReviewDialog extends StatefulWidget {
  final Book book;
  const ReviewDialog({super.key, required this.book});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final currentUser = FirebaseAuth.instance.currentUser;

  late int _tempRating;
  late TextEditingController _reviewController;
  bool _isSaving = false;

  // Track which star was just tapped for pop animation
  int _animatedStar = -1;

  @override
  void initState() {
    super.initState();
    int existingRating = widget.book.rating ?? 0;
    if (existingRating > 5) existingRating = 5;
    _tempRating = existingRating;
    _reviewController = TextEditingController(text: widget.book.review ?? '');
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _saveReview() async {
    if (currentUser == null) return;
    setState(() => _isSaving = true);

    try {
      final uid = currentUser!.uid;
      final int? finalRating = _tempRating == 0 ? null : _tempRating;
      final String finalReview = _reviewController.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('books')
          .doc(widget.book.id)
          .update({
        'rating': finalRating,
        'review': finalReview,
      });

      if (finalReview.isNotEmpty || finalRating != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data() ?? {};

        await FirebaseFirestore.instance.collection('feed').add({
          'userId': uid,
          'username': userData['username'] ?? 'Someone',
          'userPicUrl': userData['profileImageUrl'] ?? '',
          'action': finalReview.isNotEmpty ? 'reviewed' : 'rated',
          'bookTitle': widget.book.title,
          'bookAuthor': widget.book.author,
          'coverUrl': widget.book.coverUrl,
          'rating': finalRating,
          'reviewText': finalReview,
          'createdAt': FieldValue.serverTimestamp(),
          'likes': [],
          'commentCount': 0,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving review: $e');
      setState(() => _isSaving = false);
    }
  }

  void _onStarTap(int index) {
    setState(() {
      _animatedStar = index;
      _tempRating = (_tempRating == index + 1) ? 0 : index + 1;
    });
    // Reset animated star after the pop completes
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _animatedStar = -1);
    });
  }

  // Letterboxd-style rating label
  String get _ratingLabel {
    switch (_tempRating) {
      case 1: return 'Poor';
      case 2: return 'Below average';
      case 3: return 'Decent';
      case 4: return 'Great';
      case 5: return 'Amazing';
      default: return 'Tap to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        final isDark = mode == ThemeMode.dark;

        final bg         = isDark ? const Color(0xFF1A1D27) : Colors.white;
        final surface    = isDark ? const Color(0xFF22263A) : const Color(0xFFF4F5F7);
        final border     = isDark ? const Color(0xFF2A2F45) : const Color(0xFFE0E3EB);
        final textPrimary= isDark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1117);
        final textSecondary= isDark ? const Color(0xFF8A8FA8) : const Color(0xFF5A6070);
        final textMuted  = isDark ? const Color(0xFF4A5068) : const Color(0xFF9AA0B0);
        final hintFill   = isDark ? const Color(0xFF13161F) : const Color(0xFFF0F1F5);

        return Dialog(
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: border, width: 0.8),
          ),
          // FIX: Added SingleChildScrollView right here!
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Header ──────────────────────────────────────────────
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Review',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.4)),
                        const SizedBox(height: 4),
                        Text(widget.book.title ?? '',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                        if ((widget.book.author ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(widget.book.author ?? '',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400)),
                        ],
                      ])),
                    const SizedBox(width: 12),
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: border, width: 0.8)),
                        child: Icon(Icons.close_rounded,
                          color: textMuted, size: 15))),
                  ]),

                  const SizedBox(height: 28),

                  // ── Stars ────────────────────────────────────────────────
                  Center(child: Column(children: [

                    // Rating label with animated crossfade
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child)),
                      child: Text(
                        _ratingLabel,
                        key: ValueKey(_tempRating),
                        style: TextStyle(
                          color: _tempRating == 0 ? textMuted : _K.amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2),
                      )),

                    const SizedBox(height: 14),

                    // Star row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final filled = index < _tempRating;
                        final isAnimating = _animatedStar == index;

                        return GestureDetector(
                          onTap: () => _onStarTap(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 1.0, end: isAnimating ? 1.35 : 1.0),
                              duration: const Duration(milliseconds: 180),
                              curve: isAnimating ? Curves.easeOut : Curves.elasticOut,
                              builder: (_, scale, child) => Transform.scale(
                                scale: scale, child: child),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  filled
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  key: ValueKey(filled),
                                  color: filled ? _K.amber : textMuted,
                                  size: 42,
                                )),
                            )),
                        );
                      }),
                    ),
                  ])),

                  const SizedBox(height: 24),

                  // ── Divider ──────────────────────────────────────────────
                  Divider(color: border, height: 1, thickness: 0.8),

                  const SizedBox(height: 20),

                  // ── Review text field ────────────────────────────────────
                  Text('Review',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reviewController,
                    maxLines: 5,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      height: 1.55),
                    cursorColor: _K.accent,
                    decoration: InputDecoration(
                      hintText: 'What did you think of this book?',
                      hintStyle: TextStyle(color: textMuted, fontSize: 13),
                      filled: true,
                      fillColor: hintFill,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: border, width: 0.8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: _K.accent, width: 1.2)),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Actions ──────────────────────────────────────────────
                  Row(children: [
                    // Cancel
                    Expanded(child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: border, width: 0.8)),
                        alignment: Alignment.center,
                        child: Text('Cancel',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500))))),
                    const SizedBox(width: 10),
                    // Save
                    Expanded(flex: 2, child: GestureDetector(
                      onTap: _isSaving ? null : _saveReview,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 44,
                        decoration: BoxDecoration(
                          color: _isSaving
                              ? _K.accent.withOpacity(0.5)
                              : _K.accent,
                          borderRadius: BorderRadius.circular(11)),
                        alignment: Alignment.center,
                        child: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Text('Save Review',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1))))),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
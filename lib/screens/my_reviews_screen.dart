import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/book.dart';
import '../widgets/review_dialog.dart';

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
class UserReviewsScreen extends StatelessWidget {
  final String userId;
  final String? username;

  const UserReviewsScreen(
      {super.key, required this.userId, this.username});

  Future<void> _deleteReview(
      BuildContext context, Book book, _P p) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || book.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete Review',
                style: TextStyle(color: p.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'Remove your review for "${book.title}"?',
                style: TextStyle(color: p.textSecondary,
                  fontSize: 13, height: 1.5)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(color: p.surfaceEl,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border)),
                    child: Center(child: Text('Cancel',
                      style: TextStyle(color: p.textSecondary,
                        fontSize: 13, fontWeight: FontWeight.w500)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(true),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: _K.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _K.danger.withOpacity(0.35))),
                    child: const Center(child: Text('Delete',
                      style: TextStyle(color: _K.danger,
                        fontSize: 13, fontWeight: FontWeight.w600)))))),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('books')
          .doc(book.id)
          .update({'rating': null, 'review': null});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Review deleted.',
              style: TextStyle(color: p.textPrimary, fontSize: 13)),
          backgroundColor: p.surfaceEl,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwner = currentUid == userId;

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
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: p.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context)),
            title: Text(
              isOwner
                  ? 'My Reviews'
                  : "${username ?? 'User'}'s Reviews",
              style: TextStyle(color: p.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('books')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(
                    color: _K.accent, strokeWidth: 2.5));
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final r   = data['rating'] as int?;
                final rev = data['review'] as String?;
                return (r != null && r > 0) ||
                    (rev != null && rev.trim().isNotEmpty);
              }).toList();

              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: p.surfaceEl, shape: BoxShape.circle,
                        border: Border.all(color: p.border)),
                      child: Icon(Icons.star_outline_rounded,
                          size: 30, color: p.textMuted)),
                    const SizedBox(height: 16),
                    Text('No reviews yet',
                      style: TextStyle(color: p.textSecondary,
                        fontSize: 15, fontWeight: FontWeight.w300)),
                    const SizedBox(height: 4),
                    Text(
                      isOwner
                          ? 'Rate a book to see your reviews here'
                          : 'This user has no reviews yet',
                      style: TextStyle(color: p.textMuted, fontSize: 12)),
                  ],
                ));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final book = Book.fromMap(
                      docs[index].data() as Map<String, dynamic>,
                      docs[index].id);
                  return _ReviewCard(
                    p: p,
                    book: book,
                    isOwner: isOwner,
                    onEdit: () => showDialog(
                      context: context,
                      builder: (_) => ReviewDialog(book: book)),
                    onDelete: () => _deleteReview(context, book, p),
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

// ─── Review card ──────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final _P p;
  final Book book;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReviewCard({
    required this.p, required this.book, required this.isOwner,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasReview =
        book.review != null && book.review!.trim().isNotEmpty;
    final hasRating = book.rating != null && book.rating! > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Book info row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: book.coverUrl != null &&
                          book.coverUrl!.isNotEmpty
                      ? Image.network(book.coverUrl!,
                          width: 44, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholderCover(p))
                      : _placeholderCover(p)),
                const SizedBox(width: 12),

                // Title / author / stars
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title ?? 'Unknown',
                      style: TextStyle(color: p.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w600,
                        letterSpacing: -0.2, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(book.author ?? 'Unknown Author',
                      style: TextStyle(color: p.textSecondary,
                        fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (hasRating) ...[
                      const SizedBox(height: 7),
                      _StarRow(rating: book.rating!, p: p),
                    ],
                  ])),

                // Owner actions
                if (isOwner)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      color: p.textMuted,
                      onTap: onEdit),
                    const SizedBox(width: 2),
                    _ActionBtn(
                      icon: Icons.delete_outline_rounded,
                      color: _K.danger,
                      onTap: onDelete),
                  ]),
              ]),
          ),

          // ── Review text ───────────────────────────────────────────
          if (hasReview) ...[
            Container(height: 1, color: p.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 14),
              child: Text(
                book.review!,
                style: TextStyle(color: p.textSecondary,
                  fontSize: 13, height: 1.55,
                  fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholderCover(_P p) => Container(
    width: 44, height: 64,
    decoration: BoxDecoration(color: p.surfaceEl,
        borderRadius: BorderRadius.circular(7)),
    child: Icon(Icons.book_outlined, color: p.textMuted, size: 20));
}

// ─── Star row ─────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final int rating;
  final _P p;
  const _StarRow({required this.rating, required this.p});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 14,
          color: i < rating
              ? _K.amber
              : p.textMuted),
      )));
  }
}

// ─── Small icon button ────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, color: color, size: 18)));
}
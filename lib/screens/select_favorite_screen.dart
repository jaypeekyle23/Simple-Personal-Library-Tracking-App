import 'package:flutter/material.dart';
import '../models/book.dart';
import '../main.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);
}

class _P {
  final Color bg, surface, surfaceEl, border, textPrimary, textSecondary, textMuted;
  const _P({required this.bg, required this.surface, required this.surfaceEl,
    required this.border, required this.textPrimary,
    required this.textSecondary, required this.textMuted});
  factory _P.dark() => const _P(
    bg: Color(0xFF0F1117), surface: Color(0xFF1A1D27),
    surfaceEl: Color(0xFF22263A), border: Color(0xFF2A2F45),
    textPrimary: Color(0xFFEEEEEE), textSecondary: Color(0xFF8A8FA8),
    textMuted: Color(0xFF4A5068));
  factory _P.light() => const _P(
    bg: Color(0xFFF4F5F7), surface: Color(0xFFFFFFFF),
    surfaceEl: Color(0xFFEEF0F4), border: Color(0xFFDDE0E8),
    textPrimary: Color(0xFF0F1117), textSecondary: Color(0xFF5A6070),
    textMuted: Color(0xFF9AA0B0));
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class SelectFavoriteScreen extends StatefulWidget {
  final List<Book> userBooks;
  const SelectFavoriteScreen({super.key, required this.userBooks});

  @override
  State<SelectFavoriteScreen> createState() => _SelectFavoriteScreenState();
}

class _SelectFavoriteScreenState extends State<SelectFavoriteScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final p = isDark ? _P.dark() : _P.light();

    final query = _searchQuery.toLowerCase().trim();
    final filteredBooks = widget.userBooks.where((b) {
      if (b.coverUrl == null || b.coverUrl!.isEmpty) return false;
      if (query.isEmpty) return true;
      final titleMatch  = b.title?.toLowerCase().contains(query) ?? false;
      final authorMatch = b.author?.toLowerCase().contains(query) ?? false;
      return titleMatch || authorMatch;
    }).toList();

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: p.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: Text('Pick a Favourite',
          style: TextStyle(color: p.textPrimary, fontSize: 16,
            fontWeight: FontWeight.w600, letterSpacing: -0.3)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border)),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: p.textPrimary, fontSize: 14),
                cursorColor: _K.accent,
                decoration: InputDecoration(
                  hintText: 'Search title or author…',
                  hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: p.textMuted, size: 19),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(Icons.close_rounded,
                              color: p.textMuted, size: 17))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // ── Count row ───────────────────────────────────────────────
          if (filteredBooks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                Text(
                  '${filteredBooks.length} ${filteredBooks.length == 1 ? 'BOOK' : 'BOOKS'}',
                  style: TextStyle(color: p.textMuted, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 2)),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 1,
                    color: p.border.withOpacity(0.5))),
              ]),
            ),

          // ── Grid ────────────────────────────────────────────────────
          Expanded(
            child: filteredBooks.isEmpty
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 44, color: p.textMuted),
                      const SizedBox(height: 14),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No books with covers yet'
                            : 'No results for "$_searchQuery"',
                        style: TextStyle(color: p.textSecondary,
                            fontSize: 15, fontWeight: FontWeight.w300)),
                      const SizedBox(height: 5),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Add books with cover images to pick a favourite'
                            : 'Try a different search term',
                        style: TextStyle(color: p.textMuted, fontSize: 12),
                        textAlign: TextAlign.center),
                    ]))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return _BookCoverTile(
                          p: p, book: book,
                          onTap: () => Navigator.pop(context, book.coverUrl));
                    }),
          ),
        ],
      ),
    );
  }
}

// ─── Book cover tile ─────────────────────────────────────────────────────────
class _BookCoverTile extends StatelessWidget {
  final _P p;
  final Book book;
  final VoidCallback onTap;

  const _BookCoverTile(
      {required this.p, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(fit: StackFit.expand, children: [
          // Cover image
          Image.network(
            book.coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: p.surfaceEl,
              child: Icon(Icons.broken_image_outlined,
                  color: p.textMuted, size: 28)),
          ),

          // Tap ripple border
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                splashColor: const Color(0xFF00C030).withOpacity(0.2),
                highlightColor: Colors.transparent,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
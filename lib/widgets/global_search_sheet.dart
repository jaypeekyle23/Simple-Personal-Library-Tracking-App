import 'package:flutter/material.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../models/book.dart';
import '../services/google_books_api.dart';
import '../main.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _K {
  static const accent = Color(0xFF00C030);
}

class _P {
  final Color bg, surface, surfaceEl, border, textPrimary, textSecondary, textMuted;
  const _P({required this.bg, required this.surface, required this.surfaceEl,
    required this.border, required this.textPrimary, required this.textSecondary, required this.textMuted});
  factory _P.dark() => const _P(
    bg: Color(0xFF0F1117), surface: Color(0xFF1A1D27), surfaceEl: Color(0xFF22263A),
    border: Color(0xFF2A2F45), textPrimary: Color(0xFFEEEEEE),
    textSecondary: Color(0xFF8A8FA8), textMuted: Color(0xFF4A5068));
  factory _P.light() => const _P(
    bg: Color(0xFFF4F5F7), surface: Color(0xFFFFFFFF), surfaceEl: Color(0xFFEEF0F4),
    border: Color(0xFFDDE0E8), textPrimary: Color(0xFF0F1117),
    textSecondary: Color(0xFF5A6070), textMuted: Color(0xFF9AA0B0));
}

class GlobalSearchSheet extends StatefulWidget {
  const GlobalSearchSheet({super.key});

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    final results = await GoogleBooksApi.searchBooks(query);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _scanBarcode() async {
    var res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleBarcodeScannerPage(),
      ),
    );

    if (res is String && res != '-1') {
      setState(() {
        _searchController.text = res;
      });
      _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final p = isDark ? _P.dark() : _P.light();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Drag handle ───────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2))),
            ),
          ),

          // ── Section label ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 14),
            child: Text('SEARCH GOOGLE BOOKS',
              style: TextStyle(
                color: p.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6)),
          ),

          // ── Search field ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small label above the field
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 6),
                  child: Text('Title, author, or ISBN',
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border, width: 0.8)),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400),
                        cursorColor: _K.accent,
                        decoration: InputDecoration(
                          hintText: 'Search…',
                          hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 13)),
                        onSubmitted: (_) => _performSearch(),
                      )),
                    // Scanner icon
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner_rounded,
                        color: p.textSecondary, size: 20),
                      onPressed: _scanBarcode,
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36)),
                    // Search / go icon
                    GestureDetector(
                      onTap: _performSearch,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(7),
                        child: Icon(Icons.search_rounded,
                          color: _K.accent, size: 22))),
                  ]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Results ───────────────────────────────────────────────────
          Expanded(
            child: _isSearching
              ? const Center(child: CircularProgressIndicator(
                  color: _K.accent, strokeWidth: 2))
              : _searchResults.isEmpty
                ? Center(child: Text(
                    'Type a book name or scan an ISBN.',
                    style: TextStyle(color: p.textSecondary, fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final b = _searchResults[index];
                      return _ResultCard(b: b, p: p, onTap: () {
                        final selectedBook = Book(
                          title: b['title'],
                          author: b['author'],
                          coverUrl: b['coverUrl'],
                          totalPages: b['totalPages'],
                          datePublished: b['datePublished'],
                          genres: b['genres'] != null
                              ? List<String>.from(b['genres']) : [],
                          format: BookFormat.paperback,
                          status: ReadingStatus.planToRead,
                        );
                        Navigator.pop(context, selectedBook);
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Result Card ─────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> b;
  final _P p;
  final VoidCallback onTap;

  const _ResultCard({required this.b, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          splashColor: Colors.white.withOpacity(0.03),
          highlightColor: Colors.white.withOpacity(0.03),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: p.border, width: 0.8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [

              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: b['coverUrl'] != null
                  ? Image.network(
                      b['coverUrl'],
                      width: 42, height: 62,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _NoCover(p: p))
                  : _NoCover(p: p)),

              const SizedBox(width: 14),

              // Title + Author
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b['title'] ?? 'Unknown',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(b['author'] ?? 'Unknown',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                ])),

              const SizedBox(width: 8),

              // Chevron
              Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NoCover extends StatelessWidget {
  final _P p;
  const _NoCover({required this.p});

  @override
  Widget build(BuildContext context) => Container(
    width: 42, height: 62,
    decoration: BoxDecoration(
      color: p.surfaceEl,
      borderRadius: BorderRadius.circular(6)),
    child: Icon(Icons.book_outlined, color: p.textMuted, size: 18));
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../main.dart';
import '../models/book.dart';
import '../services/google_books_api.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);
  static const danger    = Color(0xFFFF3B30);
  static Color statusAccent(ReadingStatus s) {
    switch (s) {
      case ReadingStatus.currentlyReading: return const Color(0xFF00C030);
      case ReadingStatus.read:             return const Color(0xFF4A9EFF);
      case ReadingStatus.planToRead:       return const Color(0xFFFFA040);
      default:                             return const Color(0xFFFF5555);
    }
  }
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

InputDecoration _fd(_P p, String label, {String? hint, Widget? suffix}) =>
    InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: TextStyle(color: p.textMuted, fontSize: 13),
      hintStyle: TextStyle(color: p.textMuted, fontSize: 13),
      suffixIcon: suffix, filled: true, fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _K.accent, width: 1.5)),
    );

// ─── Screen ───────────────────────────────────────────────────────────────────
class AddBookScreen extends StatefulWidget {
  final Book? book;
  const AddBookScreen({super.key, this.book});
  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _titleCtrl   = TextEditingController();
  final _authorCtrl  = TextEditingController();
  final _dateCtrl    = TextEditingController();
  final _editionCtrl = TextEditingController();
  final _isbnCtrl    = TextEditingController();
  final _pagesCtrl   = TextEditingController();
  final _curPageCtrl = TextEditingController();
  final _pctCtrl     = TextEditingController();
  final _tagCtrl     = TextEditingController();

  ReadingStatus _status = ReadingStatus.planToRead;
  BookFormat    _format = BookFormat.paperback;
  String?       _coverUrl;
  List<String>  _genres = [];
  bool          _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pagesCtrl.addListener(() => setState(() {}));
    if (widget.book != null) {
      final b = widget.book!;
      _titleCtrl.text   = b.title ?? '';
      _authorCtrl.text  = b.author ?? '';
      _dateCtrl.text    = b.datePublished ?? '';
      _editionCtrl.text = b.edition ?? '';
      _isbnCtrl.text    = b.isbn ?? '';
      _pagesCtrl.text   = b.totalPages?.toString() ?? '';
      _curPageCtrl.text = b.currentPage?.toString() ?? '';
      _pctCtrl.text     = b.readPercentage?.toString() ?? '';
      _status = b.status; _format = b.format;
      _coverUrl = b.coverUrl; _genres = b.genres?.toList() ?? [];
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _authorCtrl, _dateCtrl, _editionCtrl,
        _isbnCtrl, _pagesCtrl, _curPageCtrl, _pctCtrl, _tagCtrl]) c.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_genres.contains(t)) {
      setState(() => _genres.add(t));
      _tagCtrl.clear();
    }
  }

  Future<void> _scanBarcode() async {
    final res = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1' && res.isNotEmpty) {
      setState(() => _isbnCtrl.text = res);
      _fetchByIsbn();
    }
  }

  Future<void> _fetchByIsbn() async {
    final isbn = _isbnCtrl.text.trim();
    if (isbn.isEmpty) { _snack('Enter an ISBN first.'); return; }
    _snack('Searching…');
    try {
      final r = await GoogleBooksApi.searchBooks('isbn:$isbn');
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (r.isNotEmpty) { _apply(r.first); _snack('Details fetched!'); }
      else _snack('No book found.');
    } catch (_) { if (mounted) _snack('Error fetching data.'); }
  }

  void _apply(Map<String, dynamic> d) => setState(() {
    if (d['title'] != null)        _titleCtrl.text  = d['title'];
    if (d['author'] != null)       _authorCtrl.text = d['author'];
    if (d['totalPages'] != null)   _pagesCtrl.text  = d['totalPages'].toString();
    if (d['datePublished'] != null) _dateCtrl.text  = d['datePublished'];
    if (d['coverUrl'] != null)     _coverUrl        = d['coverUrl'];
    if (d['genres'] != null) {
      _genres = (d['genres'] as List).map((e) => e.toString()).toList();
    }
  });

  void _showSearch(_P p) {
    final ctrl = TextEditingController();
    bool searching = false;
    List<Map<String, dynamic>> results = [];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        Future<void> doSearch() async {
          if (ctrl.text.isEmpty) return;
          set(() => searching = true);
          final r = await GoogleBooksApi.searchBooks(ctrl.text);
          set(() { results = r; searching = false; });
        }
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16, right: 16, top: 20),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: p.border,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                _Label('SEARCH GOOGLE BOOKS', p),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  style: TextStyle(color: p.textPrimary, fontSize: 14),
                  cursorColor: _K.accent,
                  decoration: _fd(p, 'Title, author, or ISBN',
                      suffix: IconButton(
                          icon: const Icon(Icons.search_rounded,
                              color: _K.accent, size: 20),
                          onPressed: doSearch)),
                  onSubmitted: (_) => doSearch(),
                ),
                const SizedBox(height: 14),
                Expanded(child: searching
                  ? const Center(child: CircularProgressIndicator(color: _K.accent))
                  : results.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 36, color: p.textMuted),
                          const SizedBox(height: 10),
                          Text('Search for a book above',
                              style: TextStyle(color: p.textSecondary, fontSize: 13)),
                        ]))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final b = results[i];
                          return _SearchTile(p: p,
                            title: b['title'] ?? '',
                            author: b['author'] ?? '',
                            coverUrl: b['coverUrl'],
                            onTap: () { _apply(b); Navigator.pop(ctx); });
                        })),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a title.'); return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _snack('Not logged in.'); return; }
    
    setState(() => _isSaving = true);
    
    try {
      final ref = FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('books');
      
      if (widget.book == null) {
        final ex = await ref.where('title', isEqualTo: _titleCtrl.text)
            .where('author', isEqualTo: _authorCtrl.text).get();
        if (ex.docs.isNotEmpty) {
          final go = await showDialog<bool>(
            context: context,
            builder: (_) => _DupDialog(
              p: themeNotifier.value == ThemeMode.dark ? _P.dark() : _P.light(),
              title: _titleCtrl.text, author: _authorCtrl.text));
          if (go != true) { setState(() => _isSaving = false); return; }
        }
      }
      
      final book = widget.book ?? Book();
      book.title = _titleCtrl.text; book.author = _authorCtrl.text;
      book.datePublished = _dateCtrl.text; book.edition = _editionCtrl.text;
      book.isbn = _isbnCtrl.text;
      book.totalPages = int.tryParse(_pagesCtrl.text);
      book.coverUrl = _coverUrl; book.genres = _genres;
      book.currentPage = int.tryParse(_curPageCtrl.text);
      book.readPercentage = double.tryParse(_pctCtrl.text);
      book.status = _status; book.format = _format;
      
      // Save locally to user's collection
      if (book.id != null) {
        await ref.doc(book.id).update(book.toMap());
      } else {
        await ref.add(book.toMap());
      }

      // ─── NEW: PUBLISH TO GLOBAL FEED ───
      try {
        // Fetch the user's profile to get their username and avatar
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final username = userDoc.data()?['username'] ?? 'A reader';
        final userPic = userDoc.data()?['profileImageUrl'] ?? '';

        // Dynamic action text based on their reading status
        String actionText = 'added a book to their library';
        if (_status == ReadingStatus.currentlyReading) actionText = 'started reading';
        if (_status == ReadingStatus.read) actionText = 'finished reading';

        await FirebaseFirestore.instance.collection('feed').add({
          'userId': user.uid,
          'username': username,
          'userPicUrl': userPic,
          'action': actionText,
          'bookTitle': _titleCtrl.text.trim(),
          'bookAuthor': _authorCtrl.text.trim(),
          'coverUrl': _coverUrl ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (feedError) {
        debugPrint('Error publishing to feed: $feedError');
      }
      // ───────────────────────────────────

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('Error saving: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    final p = themeNotifier.value == ThemeMode.dark ? _P.dark() : _P.light();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: p.textPrimary, fontSize: 13)),
      backgroundColor: p.surfaceEl, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16)));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();
        final editing = widget.book != null;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: _appBar(p, editing),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Quick search banner ───────────────────────────────
                _SearchBanner(p: p, onTap: () => _showSearch(p)),
                const SizedBox(height: 16),

                // ── Cover hero ────────────────────────────────────────
                if (_coverUrl != null) ...[
                  _CoverHero(p: p, coverUrl: _coverUrl!,
                    title: _titleCtrl.text, author: _authorCtrl.text,
                    onRemove: () => setState(() => _coverUrl = null)),
                  const SizedBox(height: 16),
                ],

                // ── Book info ─────────────────────────────────────────
                _Section(p: p, label: 'BOOK INFO', children: [
                  _F(p: p, ctrl: _titleCtrl, label: 'Title *',
                      onChange: (_) => setState(() {})),
                  const SizedBox(height: 11),
                  _F(p: p, ctrl: _authorCtrl, label: 'Author'),
                  const SizedBox(height: 11),
                  Row(children: [
                    Expanded(child: _F(p: p, ctrl: _dateCtrl, label: 'Pub. Year')),
                    const SizedBox(width: 10),
                    Expanded(child: _F(p: p, ctrl: _editionCtrl, label: 'Edition')),
                  ]),
                  const SizedBox(height: 11),
                  _F(p: p, ctrl: _pagesCtrl, label: 'Total Pages',
                      keyboard: TextInputType.number),
                ]),
                const SizedBox(height: 14),

                // ── ISBN lookup ───────────────────────────────────────
                _Section(p: p, label: 'ISBN LOOKUP', children: [
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _isbnCtrl,
                      style: TextStyle(color: p.textPrimary, fontSize: 14),
                      cursorColor: _K.accent,
                      keyboardType: TextInputType.number,
                      decoration: _fd(p, 'ISBN-10 or ISBN-13',
                          hint: 'Enter or scan…'),
                    )),
                    const SizedBox(width: 8),
                    _IsbnBtn(icon: Icons.qr_code_scanner_rounded,
                        label: 'SCAN', onTap: _scanBarcode, p: p),
                    const SizedBox(width: 6),
                    _IsbnBtn(icon: Icons.download_rounded,
                        label: 'FETCH', onTap: _fetchByIsbn,
                        p: p, primary: true),
                  ]),
                  const SizedBox(height: 7),
                  Text('Scan or enter ISBN to auto-fill details',
                      style: TextStyle(color: p.textMuted, fontSize: 11)),
                ]),
                const SizedBox(height: 14),

                // ── Format ────────────────────────────────────────────
                _Section(p: p, label: 'EDITION FORMAT', children: [
                  Wrap(spacing: 7, runSpacing: 7,
                    children: BookFormat.values.map((f) => _Chip(
                      p: p, label: f.displayName,
                      selected: _format == f,
                      onTap: () => setState(() => _format = f))).toList()),
                ]),
                const SizedBox(height: 14),

                // ── Status ────────────────────────────────────────────
                _Section(p: p, label: 'READING STATUS', children: [
                  Wrap(spacing: 7, runSpacing: 7,
                    children: ReadingStatus.values.map((s) {
                      final sel = _status == s;
                      return _Chip(
                        p: p, label: s.displayName, selected: sel,
                        accentColor: sel ? _K.statusAccent(s) : null,
                        onTap: () => setState(() => _status = s));
                    }).toList()),
                ]),
                const SizedBox(height: 14),

                // ── Progress ──────────────────────────────────────────
                if (_status == ReadingStatus.currentlyReading) ...[
                  _Section(p: p, label: 'READING PROGRESS', dot: true,
                    children: [
                      _pagesCtrl.text.isNotEmpty
                        ? _F(p: p, ctrl: _curPageCtrl, label: 'Current Page',
                            keyboard: TextInputType.number,
                            suffix: Text('of ${_pagesCtrl.text}',
                                style: TextStyle(color: p.textMuted, fontSize: 12)))
                        : _F(p: p, ctrl: _pctCtrl, label: 'Percentage Read',
                            keyboard: const TextInputType.numberWithOptions(decimal: true),
                            suffix: Text('%',
                                style: TextStyle(color: p.textMuted, fontSize: 14))),
                    ]),
                  const SizedBox(height: 14),
                ],

                // ── Tags ──────────────────────────────────────────────
                _Section(p: p, label: 'GENRES & TAGS', children: [
                  if (_genres.isNotEmpty) ...[
                    Wrap(spacing: 7, runSpacing: 7,
                      children: _genres.map((g) => _Tag(
                        p: p, label: g,
                        onDelete: () => setState(() => _genres.remove(g)))).toList()),
                    const SizedBox(height: 12),
                  ],
                  Row(children: [
                    Expanded(child: TextField(
                      controller: _tagCtrl,
                      style: TextStyle(color: p.textPrimary, fontSize: 14),
                      cursorColor: _K.accent,
                      decoration: _fd(p, 'Add a tag…', hint: 'e.g. Sci-Fi'),
                      onSubmitted: _addTag)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _addTag(_tagCtrl.text),
                      child: Container(width: 44, height: 44,
                        decoration: BoxDecoration(color: _K.accentDim,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _K.accent.withOpacity(0.4))),
                        child: const Icon(Icons.add_rounded,
                            color: _K.accent, size: 22))),
                  ]),
                ]),
                const SizedBox(height: 24),

                // ── Save ──────────────────────────────────────────────
                _isSaving
                  ? const Center(child: CircularProgressIndicator(
                      color: _K.accent, strokeWidth: 2.5))
                  : GestureDetector(
                      onTap: _save,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: _K.accent,
                          borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(editing ? Icons.check_rounded : Icons.add_rounded,
                                color: Colors.black, size: 19),
                            const SizedBox(width: 8),
                            Text(editing ? 'Save Changes' : 'Add to Library',
                              style: const TextStyle(color: Colors.black,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                          ]))),
              ],
            ),
          ),
        );
      },
    );
  }

  AppBar _appBar(_P p, bool editing) => AppBar(
    backgroundColor: p.bg, elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.textSecondary, size: 18),
      onPressed: () => Navigator.pop(context)),
    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(editing ? 'EDITING' : 'NEW BOOK',
        style: const TextStyle(color: _K.accent, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 2.5)),
      Text(editing
          ? (_titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Book Details')
          : 'Add to Library',
        style: TextStyle(color: p.textPrimary, fontSize: 15,
          fontWeight: FontWeight.w400, letterSpacing: -0.2),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _SearchBanner extends StatelessWidget {
  final _P p; final VoidCallback onTap;
  const _SearchBanner({required this.p, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border)),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(Icons.search_rounded, color: _K.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('Search Google Books by title or author…',
          style: TextStyle(color: p.textMuted, fontSize: 13))),
        Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _K.accentDim,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _K.accent.withOpacity(0.35))),
          child: const Text('SEARCH',
            style: TextStyle(color: _K.accent, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.2))),
      ])));
}

class _CoverHero extends StatelessWidget {
  final _P p; final String coverUrl, title, author;
  final VoidCallback onRemove;
  const _CoverHero({required this.p, required this.coverUrl,
    required this.title, required this.author, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: p.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.border)),
    child: Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(coverUrl, height: 110, width: 74,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(height: 110, width: 74,
            color: p.surfaceEl,
            child: Icon(Icons.broken_image, color: p.textMuted, size: 28)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.isNotEmpty ? title : 'Untitled',
            style: TextStyle(color: p.textPrimary, fontSize: 15,
              fontWeight: FontWeight.w600, height: 1.3),
            maxLines: 3, overflow: TextOverflow.ellipsis),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(author, style: TextStyle(color: p.textSecondary, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRemove,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.close_rounded, size: 12, color: p.textMuted),
              const SizedBox(width: 4),
              Text('Remove cover', style: TextStyle(color: p.textMuted,
                fontSize: 11, fontWeight: FontWeight.w500)),
            ])),
        ])),
    ]));
}

class _Section extends StatelessWidget {
  final _P p; final String label;
  final List<Widget> children; final bool dot;
  const _Section({required this.p, required this.label,
    required this.children, this.dot = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(color: p.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: p.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (dot) ...[
          Container(width: 6, height: 6,
            decoration: const BoxDecoration(
                color: _K.accent, shape: BoxShape.circle)),
          const SizedBox(width: 7),
        ],
        _Label(label, p),
      ]),
      ...children,
    ]));
}

class _Label extends StatelessWidget {
  final String text; final _P p;
  const _Label(this.text, this.p);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: TextStyle(color: p.textMuted, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 2)));
}

class _F extends StatelessWidget {
  final _P p; final TextEditingController ctrl; final String label;
  final TextInputType? keyboard; final Widget? suffix;
  final void Function(String)? onChange;
  const _F({required this.p, required this.ctrl, required this.label,
    this.keyboard, this.suffix, this.onChange});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: TextStyle(color: p.textPrimary, fontSize: 14),
    cursorColor: _K.accent, keyboardType: keyboard, onChanged: onChange,
    decoration: _fd(p, label,
        suffix: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix)
          : null));
}

class _Chip extends StatelessWidget {
  final _P p; final String label; final bool selected;
  final Color? accentColor; final VoidCallback onTap;
  const _Chip({required this.p, required this.label, required this.selected,
    required this.onTap, this.accentColor});
  @override
  Widget build(BuildContext context) {
    final c = accentColor ?? _K.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : p.surfaceEl,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? c : p.border)),
        child: Text(label, style: TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? c : p.textSecondary))));
  }
}

class _Tag extends StatelessWidget {
  final _P p; final String label; final VoidCallback onDelete;
  const _Tag({required this.p, required this.label, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
    decoration: BoxDecoration(color: p.surfaceEl,
      borderRadius: BorderRadius.circular(6), border: Border.all(color: p.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: p.textSecondary, fontSize: 12,
        fontWeight: FontWeight.w500)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onDelete,
        child: Container(padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: p.border, shape: BoxShape.circle),
          child: Icon(Icons.close_rounded, size: 10, color: p.textMuted))),
    ]));
}

class _IsbnBtn extends StatelessWidget {
  final _P p; final IconData icon; final String label;
  final VoidCallback onTap; final bool primary;
  const _IsbnBtn({required this.p, required this.icon, required this.label,
    required this.onTap, this.primary = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: primary ? _K.accentDim : p.surfaceEl,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: primary ? _K.accent.withOpacity(0.5) : p.border)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 19, color: primary ? _K.accent : p.textSecondary),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: primary ? _K.accent : p.textSecondary)),
      ])));
}

class _SearchTile extends StatelessWidget {
  final _P p; final String title, author; final String? coverUrl;
  final VoidCallback onTap;
  const _SearchTile({required this.p, required this.title, required this.author,
    required this.onTap, this.coverUrl});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.surfaceEl,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border)),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(6),
          child: coverUrl != null
            ? Image.network(coverUrl!, width: 38, height: 55, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumb(p))
            : _thumb(p)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: p.textPrimary, fontSize: 13,
              fontWeight: FontWeight.w600), maxLines: 2,
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(author, style: TextStyle(color: p.textSecondary, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 17),
      ])));
  Widget _thumb(_P p) => Container(width: 38, height: 55,
    decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(6)),
    child: Icon(Icons.book_outlined, color: p.textMuted, size: 18));
}

class _DupDialog extends StatelessWidget {
  final _P p; final String title, author;
  const _DupDialog({required this.p, required this.title, required this.author});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: p.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Duplicate Found', style: TextStyle(color: p.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        RichText(text: TextSpan(
          style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.5),
          children: [
            const TextSpan(text: 'You already have '),
            TextSpan(text: '"$title"',
                style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600)),
            const TextSpan(text: ' by '),
            TextSpan(text: author, style: TextStyle(color: p.textPrimary)),
            const TextSpan(text: '.\n\nAdd another copy?'),
          ])),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Container(height: 40,
              decoration: BoxDecoration(color: p.surfaceEl,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.border)),
              child: Center(child: Text('Cancel',
                style: TextStyle(color: p.textSecondary, fontSize: 13,
                  fontWeight: FontWeight.w500)))))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(height: 40,
              decoration: BoxDecoration(color: _K.accentDim,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _K.accent.withOpacity(0.4))),
              child: const Center(child: Text('Add Anyway',
                style: TextStyle(color: _K.accent, fontSize: 13,
                  fontWeight: FontWeight.w600)))))),
        ]),
      ])));
}
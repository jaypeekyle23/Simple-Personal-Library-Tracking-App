import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';

import '../main.dart';
import '../models/book.dart';
import '../services/google_books_api.dart';

// ─── Fixed accent colours ─────────────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);

  static Color statusAccent(ReadingStatus s) {
    switch (s) {
      case ReadingStatus.currentlyReading: return const Color(0xFF00C030);
      case ReadingStatus.read:             return const Color(0xFF4A9EFF);
      case ReadingStatus.planToRead:       return const Color(0xFFFFA040);
      default:                             return const Color(0xFFFF5555);
    }
  }
}

// ─── Theme-aware palette ──────────────────────────────────────────────────────
class _P {
  final Color bg;
  final Color surface;
  final Color surfaceEl;
  final Color border;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const _P({
    required this.bg,
    required this.surface,
    required this.surfaceEl,
    required this.border,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  factory _P.dark() => const _P(
    bg:            Color(0xFF0F1117),
    surface:       Color(0xFF1A1D27),
    surfaceEl:     Color(0xFF22263A),
    border:        Color(0xFF2A2F45),
    divider:       Color(0xFF252A3D),
    textPrimary:   Color(0xFFEEEEEE),
    textSecondary: Color(0xFF8A8FA8),
    textMuted:     Color(0xFF4A5068),
  );

  factory _P.light() => const _P(
    bg:            Color(0xFFF4F5F7),
    surface:       Color(0xFFFFFFFF),
    surfaceEl:     Color(0xFFEEF0F4),
    border:        Color(0xFFDDE0E8),
    divider:       Color(0xFFE8EAF0),
    textPrimary:   Color(0xFF0F1117),
    textSecondary: Color(0xFF5A6070),
    textMuted:     Color(0xFF9AA0B0),
  );
}

// ─── Input decoration helper ──────────────────────────────────────────────────
InputDecoration _fieldDecor(_P p, String label,
    {String? hint, Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: p.textMuted, fontSize: 13),
    hintStyle: TextStyle(color: p.textMuted, fontSize: 13),
    suffixIcon: suffix,
    filled: true,
    fillColor: p.surface,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: p.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _K.accent, width: 1.5),
    ),
  );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddBookScreen extends StatefulWidget {
  final Book? book;
  const AddBookScreen({super.key, this.book});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _titleController       = TextEditingController();
  final _authorController      = TextEditingController();
  final _datePublishedController = TextEditingController();
  final _editionController     = TextEditingController();
  final _isbnController        = TextEditingController();
  final _totalPagesController  = TextEditingController();
  final _currentPageController = TextEditingController();
  final _readPctController     = TextEditingController();
  final _genreInputController  = TextEditingController();

  ReadingStatus _selectedStatus = ReadingStatus.planToRead;
  BookFormat    _selectedFormat = BookFormat.paperback;
  String?       _coverUrl;
  List<String>  _genres = [];

  @override
  void initState() {
    super.initState();
    _totalPagesController.addListener(() => setState(() {}));
    if (widget.book != null) {
      final b = widget.book!;
      _titleController.text        = b.title ?? '';
      _authorController.text       = b.author ?? '';
      _datePublishedController.text = b.datePublished ?? '';
      _editionController.text      = b.edition ?? '';
      _isbnController.text         = b.isbn ?? '';
      _totalPagesController.text   = b.totalPages?.toString() ?? '';
      _currentPageController.text  = b.currentPage?.toString() ?? '';
      _readPctController.text      = b.readPercentage?.toString() ?? '';
      _selectedStatus = b.status;
      _selectedFormat = b.format;
      _coverUrl       = b.coverUrl;
      _genres         = b.genres?.toList() ?? [];
    }
  }

  void _addGenre(String genre) {
    final clean = genre.trim();
    if (clean.isNotEmpty && !_genres.contains(clean)) {
      setState(() => _genres.add(clean));
      _genreInputController.clear();
    }
  }

  Future<void> _scanBarcode() async {
    final res = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1' && res.isNotEmpty) {
      setState(() => _isbnController.text = res);
      _fetchByIsbn();
    }
  }

  Future<void> _fetchByIsbn() async {
    final isbn = _isbnController.text.trim();
    if (isbn.isEmpty) { _snack('Please enter an ISBN first.'); return; }
    _snack('Searching for ISBN…');
    try {
      final results = await GoogleBooksApi.searchBooks('isbn:$isbn');
      if (results.isNotEmpty) {
        _applyBookData(results.first);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _snack('Book details fetched!');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _snack('No book found with that ISBN.');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _snack('Error fetching book data.');
      }
    }
  }

  void _applyBookData(Map<String, dynamic> data) {
    setState(() {
      if (data['title'] != null)        _titleController.text = data['title'];
      if (data['author'] != null)       _authorController.text = data['author'];
      if (data['totalPages'] != null)   _totalPagesController.text = data['totalPages'].toString();
      if (data['datePublished'] != null) _datePublishedController.text = data['datePublished'];
      if (data['coverUrl'] != null)     _coverUrl = data['coverUrl'];
      if (data['genres'] != null)
        _genres = (data['genres'] as List).map((e) => e.toString()).toList();
    });
  }

  void _showSearchBottomSheet(_P p) {
    final searchCtrl = TextEditingController();
    bool isSearching = false;
    List<Map<String, dynamic>> results = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> doSearch() async {
            if (searchCtrl.text.isEmpty) return;
            setModal(() => isSearching = true);
            final r = await GoogleBooksApi.searchBooks(searchCtrl.text);
            setModal(() { results = r; isSearching = false; });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16, right: 16, top: 20,
            ),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: p.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('SEARCH GOOGLE BOOKS',
                      style: TextStyle(
                        color: p.textMuted, fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 2.2,
                      )),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchCtrl,
                    style: TextStyle(color: p.textPrimary, fontSize: 14),
                    cursorColor: _K.accent,
                    decoration: _fieldDecor(p, 'Title, author, or ISBN',
                        suffix: IconButton(
                          icon: const Icon(Icons.search_rounded,
                              color: _K.accent, size: 20),
                          onPressed: doSearch,
                        )),
                    onSubmitted: (_) => doSearch(),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isSearching
                        ? const Center(child: CircularProgressIndicator(color: _K.accent))
                        : results.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search, size: 40, color: p.textMuted),
                                    const SizedBox(height: 12),
                                    Text('Search for a book above',
                                        style: TextStyle(
                                            color: p.textSecondary, fontSize: 14)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (_, i) {
                                  final b = results[i];
                                  return _SearchResultTile(
                                    p: p,
                                    title: b['title'] ?? '',
                                    author: b['author'] ?? '',
                                    coverUrl: b['coverUrl'],
                                    onTap: () {
                                      _applyBookData(b);
                                      Navigator.pop(ctx);
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveBook() async {
    if (_titleController.text.isEmpty) return;
    if (widget.book == null) {
      final existing = await isar.books
          .filter()
          .titleEqualTo(_titleController.text, caseSensitive: false)
          .and()
          .authorEqualTo(_authorController.text, caseSensitive: false)
          .findAll();
      if (existing.isNotEmpty) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => _DuplicateDialog(
            p: themeNotifier.value == ThemeMode.dark ? _P.dark() : _P.light(),
            title: _titleController.text,
            author: _authorController.text,
          ),
        );
        if (proceed != true) return;
      }
    }
    final book = widget.book ?? Book();
    book.title         = _titleController.text;
    book.author        = _authorController.text;
    book.datePublished = _datePublishedController.text;
    book.edition       = _editionController.text;
    book.isbn          = _isbnController.text;
    book.totalPages    = int.tryParse(_totalPagesController.text);
    book.coverUrl      = _coverUrl;
    book.genres        = _genres;
    book.currentPage   = int.tryParse(_currentPageController.text);
    book.readPercentage = double.tryParse(_readPctController.text);
    book.status        = _selectedStatus;
    book.format        = _selectedFormat;
    await isar.writeTxn(() async => await isar.books.put(book));
    if (mounted) Navigator.pop(context);
  }

  void _snack(String msg) {
    final p = themeNotifier.value == ThemeMode.dark ? _P.dark() : _P.light();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: p.textPrimary, fontSize: 13)),
      backgroundColor: p.surfaceEl,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _datePublishedController.dispose();
    _editionController.dispose();
    _isbnController.dispose();
    _totalPagesController.dispose();
    _currentPageController.dispose();
    _readPctController.dispose();
    _genreInputController.dispose();
    super.dispose();
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();
        final isEditing = widget.book != null;

        return Scaffold(
          backgroundColor: p.bg,
          appBar: _buildAppBar(p, isEditing),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCoverHero(p),
                _buildBookInfoSection(p),
                const SizedBox(height: 20),
                _buildIsbnSection(p),
                const SizedBox(height: 20),
                _buildFormatStatusSection(p),
                if (_selectedStatus == ReadingStatus.currentlyReading) ...[
                  const SizedBox(height: 20),
                  _buildProgressSection(p),
                ],
                const SizedBox(height: 20),
                _buildGenresSection(p),
                const SizedBox(height: 32),
                _buildSaveButton(p, isEditing),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(_P p, bool isEditing) {
    return AppBar(
      backgroundColor: p.bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: p.textSecondary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'EDITING' : 'NEW BOOK',
            style: const TextStyle(
              color: _K.accent, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 2.5,
            ),
          ),
          Text(
            isEditing
                ? (_titleController.text.isNotEmpty
                    ? _titleController.text
                    : 'Book Details')
                : 'Add to Library',
            style: TextStyle(
              color: p.textPrimary, fontSize: 16,
              fontWeight: FontWeight.w400, letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () => _showSearchBottomSheet(p),
          child: Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: p.border),
            ),
            child: Icon(Icons.search_rounded, color: p.textSecondary, size: 18),
          ),
        ),
      ],
    );
  }

  // ─── Cover hero ───────────────────────────────────────────────────────────────

  Widget _buildCoverHero(_P p) {
    if (_coverUrl == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              _coverUrl!, height: 130, width: 88, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 130, width: 88, color: p.surfaceEl,
                child: Icon(Icons.broken_image, color: p.textMuted, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleController.text.isNotEmpty
                      ? _titleController.text : 'Untitled',
                  style: TextStyle(
                    color: p.textPrimary, fontSize: 16,
                    fontWeight: FontWeight.w600, height: 1.3,
                  ),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
                if (_authorController.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(_authorController.text,
                      style: TextStyle(color: p.textSecondary, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _coverUrl = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.surfaceEl,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded, size: 12, color: p.textMuted),
                        const SizedBox(width: 5),
                        Text('Remove cover',
                            style: TextStyle(
                              color: p.textMuted, fontSize: 11,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Book info ────────────────────────────────────────────────────────────────

  Widget _buildBookInfoSection(_P p) {
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('BOOK INFO', p),
          _StyledField(p: p, controller: _titleController,
              label: 'Title *', onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _StyledField(p: p, controller: _authorController, label: 'Author'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StyledField(
                  p: p, controller: _datePublishedController,
                  label: 'Pub. Date')),
              const SizedBox(width: 12),
              Expanded(child: _StyledField(
                  p: p, controller: _editionController, label: 'Edition')),
            ],
          ),
          const SizedBox(height: 12),
          _StyledField(p: p, controller: _totalPagesController,
              label: 'Total Pages',
              keyboardType: TextInputType.number),
        ],
      ),
    );
  }

  // ─── ISBN ─────────────────────────────────────────────────────────────────────

  Widget _buildIsbnSection(_P p) {
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('ISBN LOOKUP', p),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _isbnController,
                  style: TextStyle(color: p.textPrimary, fontSize: 14),
                  cursorColor: _K.accent,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecor(p, 'ISBN', hint: 'Enter or scan…'),
                ),
              ),
              const SizedBox(width: 10),
              _IsbnActionBtn(
                  p: p, icon: Icons.qr_code_scanner_rounded,
                  label: 'SCAN', onTap: _scanBarcode),
              const SizedBox(width: 8),
              _IsbnActionBtn(
                  p: p, icon: Icons.cloud_download_outlined,
                  label: 'FETCH', onTap: _fetchByIsbn, isPrimary: true),
            ],
          ),
          const SizedBox(height: 8),
          Text('Scan or enter an ISBN to auto-fill book details',
              style: TextStyle(color: p.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Format & Status ──────────────────────────────────────────────────────────

  Widget _buildFormatStatusSection(_P p) {
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('FORMAT & STATUS', p),
          Text('Format',
              style: TextStyle(color: p.textSecondary, fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: BookFormat.values.map((fmt) => _ToggleChip(
              p: p, label: fmt.displayName,
              isSelected: _selectedFormat == fmt,
              onTap: () => setState(() => _selectedFormat = fmt),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: p.divider),
          const SizedBox(height: 20),
          Text('Reading Status',
              style: TextStyle(color: p.textSecondary, fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: ReadingStatus.values.map((status) {
              final sel = _selectedStatus == status;
              return _ToggleChip(
                p: p, label: status.displayName,
                isSelected: sel,
                accentColor: sel ? _K.statusAccent(status) : null,
                onTap: () => setState(() => _selectedStatus = status),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Progress ─────────────────────────────────────────────────────────────────

  Widget _buildProgressSection(_P p) {
    final hasPages = _totalPagesController.text.isNotEmpty;
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: _K.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              _SectionLabel('READING PROGRESS', p),
            ],
          ),
          const SizedBox(height: 4),
          if (hasPages)
            _StyledField(
              p: p, controller: _currentPageController,
              label: 'Current Page',
              suffix: Text('of ${_totalPagesController.text}',
                  style: TextStyle(color: p.textMuted, fontSize: 12)),
              keyboardType: TextInputType.number,
            )
          else
            _StyledField(
              p: p, controller: _readPctController,
              label: 'Percentage Read',
              suffix: Text('%',
                  style: TextStyle(color: p.textMuted, fontSize: 14)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
        ],
      ),
    );
  }

  // ─── Genres ───────────────────────────────────────────────────────────────────

  Widget _buildGenresSection(_P p) {
    return _Card(
      p: p,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('GENRES & TAGS', p),
          if (_genres.isNotEmpty) ...[
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _genres.map((g) => _GenreTag(
                p: p, label: g,
                onDelete: () => setState(() => _genres.remove(g)),
              )).toList(),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _genreInputController,
                  style: TextStyle(color: p.textPrimary, fontSize: 14),
                  cursorColor: _K.accent,
                  decoration: _fieldDecor(p, 'Add a tag…',
                      hint: 'e.g. Sci-Fi, Summer Read'),
                  onSubmitted: _addGenre,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _addGenre(_genreInputController.text),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _K.accentDim,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _K.accent.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.add_rounded, color: _K.accent, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Save button ──────────────────────────────────────────────────────────────

  Widget _buildSaveButton(_P p, bool isEditing) {
    return GestureDetector(
      onTap: _saveBook,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _K.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isEditing ? Icons.check_rounded : Icons.add_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              isEditing ? 'Save Changes' : 'Add to Library',
              style: const TextStyle(
                color: Colors.black, fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final _P p;
  const _SectionLabel(this.text, this.p);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: TextStyle(
            color: p.textMuted, fontSize: 10,
            fontWeight: FontWeight.w700, letterSpacing: 2.2,
          )),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final _P p;
  const _Card({required this.child, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 1),
      ),
      child: child,
    );
  }
}

class _StyledField extends StatelessWidget {
  final _P p;
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final void Function(String)? onChanged;

  const _StyledField({
    required this.p,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.suffix,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(color: p.textPrimary, fontSize: 14),
      cursorColor: _K.accent,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: _fieldDecor(p, label,
          suffix: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix)
              : null),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final _P p;
  final String label;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.p,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? _K.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : p.surfaceEl,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : p.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isSelected ? color : p.textSecondary,
            )),
      ),
    );
  }
}

class _GenreTag extends StatelessWidget {
  final _P p;
  final String label;
  final VoidCallback onDelete;
  const _GenreTag({required this.p, required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: p.surfaceEl,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                color: p.textSecondary, fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: p.border, shape: BoxShape.circle),
              child: Icon(Icons.close_rounded, size: 10, color: p.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _IsbnActionBtn extends StatelessWidget {
  final _P p;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _IsbnActionBtn({
    required this.p,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? _K.accentDim : p.surfaceEl,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isPrimary ? _K.accent.withOpacity(0.5) : p.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20,
                color: isPrimary ? _K.accent : p.textSecondary),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1,
                  color: isPrimary ? _K.accent : p.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _P p;
  final String title;
  final String author;
  final String? coverUrl;
  final VoidCallback onTap;
  const _SearchResultTile({
    required this.p, required this.title, required this.author,
    required this.onTap, this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.surfaceEl,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: coverUrl != null
                  ? Image.network(coverUrl!, width: 40, height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumb(p))
                  : _thumb(p),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: p.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(author,
                      style: TextStyle(color: p.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _thumb(_P p) => Container(
    width: 40, height: 58,
    decoration: BoxDecoration(
        color: p.surface, borderRadius: BorderRadius.circular(6)),
    child: Icon(Icons.book_outlined, color: p.textMuted, size: 20),
  );
}

class _DuplicateDialog extends StatelessWidget {
  final _P p;
  final String title;
  final String author;
  const _DuplicateDialog(
      {required this.p, required this.title, required this.author});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duplicate Found',
                style: TextStyle(
                  color: p.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                    color: p.textSecondary, fontSize: 13, height: 1.5),
                children: [
                  const TextSpan(text: 'You already have a copy of '),
                  TextSpan(text: '"$title"',
                      style: TextStyle(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' by '),
                  TextSpan(text: author,
                      style: TextStyle(color: p.textPrimary)),
                  const TextSpan(text: ' in your library.\n\nAdd another copy?'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: p.surfaceEl,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                      ),
                      child: Center(child: Text('Cancel',
                          style: TextStyle(
                            color: p.textSecondary, fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: _K.accentDim,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _K.accent.withOpacity(0.4)),
                      ),
                      child: const Center(child: Text('Add Anyway',
                          style: TextStyle(
                            color: _K.accent, fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/book.dart';
import 'add_book_screen.dart';
import 'settings_screen.dart';

// ─── Sort options ─────────────────────────────────────────────────────────────

enum SortOption { titleAsc, datePubAsc, datePubDesc, pagesAsc, pagesDesc }

extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.titleAsc:    return 'A-Z (Title)';
      case SortOption.datePubAsc:  return 'Date (Old→New)';
      case SortOption.datePubDesc: return 'Date (New→Old)';
      case SortOption.pagesAsc:    return 'Pages (Asc)';
      case SortOption.pagesDesc:   return 'Pages (Desc)';
    }
  }
}

// ─── Palette ─────────────────────────────────────────────────────────────────

class _K {
  static const accent       = Color(0xFF00C030);
  static const accentDim    = Color(0xFF00C03028);
  static const statusRead   = Color(0xFF4A9EFF);
  static const statusReadBg = Color(0xFF4A9EFF20);
  static const statusWant   = Color(0xFFFFA040);
  static const statusWantBg = Color(0xFFFFA04020);
  static const statusDnf    = Color(0xFFFF5555);
  static const statusDnfBg  = Color(0xFFFF555520);
  static const danger       = Color(0xFFFF3B30);
}

class _P {
  final Color bg, surface, surfaceEl, border, divider,
      textPrimary, textSecondary, textMuted;
  const _P({
    required this.bg, required this.surface, required this.surfaceEl,
    required this.border, required this.divider, required this.textPrimary,
    required this.textSecondary, required this.textMuted,
  });
  factory _P.dark() => const _P(
    bg: Color(0xFF0F1117), surface: Color(0xFF1A1D27),
    surfaceEl: Color(0xFF22263A), border: Color(0xFF2A2F45),
    divider: Color(0xFF252A3D), textPrimary: Color(0xFFEEEEEE),
    textSecondary: Color(0xFF8A8FA8), textMuted: Color(0xFF4A5068),
  );
  factory _P.light() => const _P(
    bg: Color(0xFFF4F5F7), surface: Color(0xFFFFFFFF),
    surfaceEl: Color(0xFFEEF0F4), border: Color(0xFFDDE0E8),
    divider: Color(0xFFE8EAF0), textPrimary: Color(0xFF0F1117),
    textSecondary: Color(0xFF5A6070), textMuted: Color(0xFF9AA0B0),
  );
}

Color _statusColor(ReadingStatus s) {
  switch (s) {
    case ReadingStatus.currentlyReading: return _K.accent;
    case ReadingStatus.read:             return _K.statusRead;
    case ReadingStatus.planToRead:       return _K.statusWant;
    default:                             return _K.statusDnf;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List<Book> _books = [];
  final _searchController = TextEditingController();
  SortOption _selectedSort = SortOption.titleAsc;
  ReadingStatus? _selectedFilter;
  Map<ReadingStatus?, int> _statusCounts = {null: 0};
  bool _showFilters = false;
  late final AnimationController _filterAnimController;
  late final Animation<double> _filterAnim;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _filterAnim = CurvedAnimation(
        parent: _filterAnimController, curve: Curves.easeInOut);
    _fetchBooks();
  }

  void _showSnack(String msg, _P p) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: p.textPrimary, fontSize: 13)),
      backgroundColor: p.surfaceEl,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _fetchBooks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('books').get();
    List<Book> baseBooks =
        snapshot.docs.map((d) => Book.fromMap(d.data(), d.id)).toList();

    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      baseBooks = baseBooks.where((b) {
        final t = b.title?.toLowerCase() ?? '';
        final a = b.author?.toLowerCase() ?? '';
        final g = b.genres?.join(' ').toLowerCase() ?? '';
        return t.contains(query) || a.contains(query) || g.contains(query);
      }).toList();
    }

    Map<ReadingStatus?, int> newCounts = {null: baseBooks.length};
    for (var s in ReadingStatus.values) {
      newCounts[s] = baseBooks.where((b) => b.status == s).length;
    }

    List<Book> filtered = baseBooks;
    if (_selectedFilter != null) {
      filtered = filtered.where((b) => b.status == _selectedFilter).toList();
    }

    filtered.sort((a, b) {
      if (a.status == ReadingStatus.currentlyReading &&
          b.status != ReadingStatus.currentlyReading) return -1;
      if (b.status == ReadingStatus.currentlyReading &&
          a.status != ReadingStatus.currentlyReading) return 1;
      switch (_selectedSort) {
        case SortOption.titleAsc:    return (a.title ?? '').compareTo(b.title ?? '');
        case SortOption.datePubAsc:  return (a.datePublished ?? '').compareTo(b.datePublished ?? '');
        case SortOption.datePubDesc: return (b.datePublished ?? '').compareTo(a.datePublished ?? '');
        case SortOption.pagesAsc:    return (a.totalPages ?? 0).compareTo(b.totalPages ?? 0);
        case SortOption.pagesDesc:   return (b.totalPages ?? 0).compareTo(a.totalPages ?? 0);
      }
    });

    setState(() { _books = filtered; _statusCounts = newCounts; });
  }

  Future<void> _deleteBook(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(user.uid).collection('books').doc(id).delete();
      _fetchBooks();
    }
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
    _showFilters ? _filterAnimController.forward() : _filterAnimController.reverse();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();
        return _HomeView(
          p: p, books: _books, statusCounts: _statusCounts,
          selectedSort: _selectedSort, selectedFilter: _selectedFilter,
          showFilters: _showFilters, filterAnim: _filterAnim,
          searchController: _searchController,
          onToggleFilters: _toggleFilters,
          onSortChanged: (s) { setState(() => _selectedSort = s); _fetchBooks(); },
          onFilterChanged: (f) { setState(() => _selectedFilter = f); _fetchBooks(); },
          onSearchChanged: (_) => _fetchBooks(),
          onSearchCleared: () { _searchController.clear(); _fetchBooks(); },
          onBookTap: (book) async {
            final result = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddBookScreen(book: book)));
            if (result == true) _showSnack('Book updated!', p);
            _fetchBooks();
          },
          onBookDelete: (id) { _deleteBook(id); _showSnack('Book deleted.', p); },
          onAddBook: () async {
            final result = await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddBookScreen()));
            if (result == true) _showSnack('Book added!', p);
            _fetchBooks();
          },
          onSettings: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        );
      },
    );
  }
}

// ─── Pure UI ──────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  final _P p;
  final List<Book> books;
  final Map<ReadingStatus?, int> statusCounts;
  final SortOption selectedSort;
  final ReadingStatus? selectedFilter;
  final bool showFilters;
  final Animation<double> filterAnim;
  final TextEditingController searchController;
  final VoidCallback onToggleFilters;
  final void Function(SortOption) onSortChanged;
  final void Function(ReadingStatus?) onFilterChanged;
  final void Function(String) onSearchChanged;
  final VoidCallback onSearchCleared;
  final void Function(Book) onBookTap;
  final void Function(String) onBookDelete;
  final VoidCallback onAddBook;
  final VoidCallback onSettings;

  const _HomeView({
    required this.p, required this.books, required this.statusCounts,
    required this.selectedSort, required this.selectedFilter,
    required this.showFilters, required this.filterAnim,
    required this.searchController, required this.onToggleFilters,
    required this.onSortChanged, required this.onFilterChanged,
    required this.onSearchChanged, required this.onSearchCleared,
    required this.onBookTap, required this.onBookDelete,
    required this.onAddBook, required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.bg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, __) => [_buildAppBar(ctx)],
        body: Column(children: [
          _buildSearchBar(),
          _buildFilterBar(),
          SizeTransition(sizeFactor: filterAnim, child: _buildSortPanel()),
          _buildCountRow(),
          Expanded(child: _buildBookList(context)),
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _K.accent,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: onAddBook,
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 108,
      floating: true, snap: true, pinned: false,
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        // Logout
        _NavBtn(
          icon: Icons.logout_rounded,
          color: p.textSecondary,
          onTap: () => _showLogoutDialog(context),
        ),
        const SizedBox(width: 4),
        // Settings
        _NavBtn(
          icon: Icons.settings_outlined,
          color: p.textSecondary,
          onTap: onSettings,
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Folio wordmark
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Folio',
                    style: TextStyle(
                      color: p.textPrimary, fontSize: 26,
                      fontWeight: FontWeight.w300, letterSpacing: -1.2, height: 1,
                    )),
                Text('.',
                    style: const TextStyle(
                      color: _K.accent, fontSize: 26,
                      fontWeight: FontWeight.w700, height: 1,
                    )),
              ],
            ),
            const SizedBox(height: 1),
            Text('YOUR LIBRARY',
                style: TextStyle(
                  color: p.textMuted, fontSize: 8.5,
                  fontWeight: FontWeight.w700, letterSpacing: 2.5,
                )),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = p.bg == const Color(0xFF0F1117);
    showDialog(
      context: context,
      builder: (_) => _StyledDialog(
        p: p,
        isDark: isDark,
        title: 'Sign out',
        body: 'Are you sure you want to sign out of Folio?',
        cancelLabel: 'Cancel',
        confirmLabel: 'Sign out',
        confirmColor: _K.danger,
        onConfirm: () async {
          Navigator.of(context).pop();
          await FirebaseAuth.instance.signOut();
        },
      ),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: TextField(
          controller: searchController,
          style: TextStyle(color: p.textPrimary, fontSize: 14),
          cursorColor: _K.accent,
          decoration: InputDecoration(
            hintText: 'Search title, author, tag…',
            hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: p.textMuted, size: 19),
            suffixIcon: searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: onSearchCleared,
                    child: Icon(Icons.close_rounded, color: p.textMuted, size: 17))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: onSearchChanged,
        ),
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(p: p, label: 'All', count: statusCounts[null] ?? 0,
              isSelected: selectedFilter == null,
              onTap: () => onFilterChanged(null)),
          ...ReadingStatus.values.map((s) => _FilterChip(
              p: p, label: s.displayName,
              count: statusCounts[s] ?? 0,
              isSelected: selectedFilter == s,
              color: _statusColor(s),
              onTap: () => onFilterChanged(s))),
          const SizedBox(width: 6),
          _SortToggle(p: p, active: showFilters, onTap: onToggleFilters),
        ],
      ),
    );
  }

  // ── Sort panel ──────────────────────────────────────────────────────────────

  Widget _buildSortPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SORT BY', style: TextStyle(
          color: p.textMuted, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 2,
        )),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7,
          children: SortOption.values.map((sort) {
            final sel = selectedSort == sort;
            return GestureDetector(
              onTap: () => onSortChanged(sort),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? _K.accent : p.surfaceEl,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sel ? _K.accent : p.border),
                ),
                child: Text(sort.displayName,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.black : p.textSecondary)),
              ),
            );
          }).toList()),
      ]),
    );
  }

  // ── Count row ───────────────────────────────────────────────────────────────

  Widget _buildCountRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        Text('${books.length} ${books.length == 1 ? 'BOOK' : 'BOOKS'}',
          style: TextStyle(color: p.textMuted, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: p.divider)),
      ]),
    );
  }

  // ── Book list ───────────────────────────────────────────────────────────────

  Widget _buildBookList(BuildContext context) {
    if (books.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.menu_book_outlined, size: 44, color: p.textMuted),
        const SizedBox(height: 14),
        Text('No books yet', style: TextStyle(
            color: p.textSecondary, fontSize: 16, fontWeight: FontWeight.w300)),
        const SizedBox(height: 5),
        Text('Tap + to add your first book',
            style: TextStyle(color: p.textMuted, fontSize: 13)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: books.length,
      itemBuilder: (_, i) => _buildCard(context, books[i]),
    );
  }

  // ── Book card ───────────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, Book book) {
    double progress = 0.0;
    String progressText = '';
    if (book.status == ReadingStatus.currentlyReading) {
      if (book.totalPages != null && book.totalPages! > 0) {
        final cur = book.currentPage ?? 0;
        progress = (cur / book.totalPages!).clamp(0.0, 1.0);
        progressText = '$cur / ${book.totalPages}p';
      } else if (book.readPercentage != null) {
        progress = (book.readPercentage! / 100.0).clamp(0.0, 1.0);
        progressText = '${book.readPercentage!.toStringAsFixed(0)}%';
      }
    }
    final sc = _statusColor(book.status);

    return Dismissible(
      key: ValueKey(book.id ?? UniqueKey().toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => _StyledDialog(
          p: p,
          isDark: p.bg == const Color(0xFF0F1117),
          title: 'Delete book',
          body: 'Remove "${book.title}" from your library?',
          cancelLabel: 'Cancel',
          confirmLabel: 'Delete',
          confirmColor: _K.danger,
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        color: _K.danger,
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          SizedBox(height: 3),
          Text('DELETE', style: TextStyle(color: Colors.white,
              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        ]),
      ),
      onDismissed: (_) { if (book.id != null) onBookDelete(book.id!); },
      child: GestureDetector(
        onTap: () => onBookTap(book),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildCover(book),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(book.title ?? 'Unknown Title',
                        style: TextStyle(color: p.textPrimary, fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(book.status.displayName,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w500, color: sc)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(book.author ?? 'Unknown Author',
                      style: TextStyle(color: p.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.surfaceEl,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(book.format.displayName.toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: p.textMuted, letterSpacing: 1)),
                    ),
                    if (book.status == ReadingStatus.currentlyReading &&
                        progressText.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress, minHeight: 3,
                            backgroundColor: p.divider,
                            valueColor:
                                const AlwaysStoppedAnimation(_K.accent)),
                        )),
                        const SizedBox(width: 7),
                        Text(progressText,
                          style: const TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: _K.accent)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCover(Book book) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
      child: book.coverUrl != null && book.coverUrl!.isNotEmpty
          ? Image.network(book.coverUrl!, width: 64, height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderCover(book))
          : _placeholderCover(book),
    );
  }

  Widget _placeholderCover(Book book) {
    return Container(
      width: 64, height: 96,
      decoration: BoxDecoration(
        color: p.surfaceEl,
        border: Border(right: BorderSide(color: p.border))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.menu_book_rounded, color: p.textMuted, size: 22),
        if (book.title != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text((book.title ?? '').split(' ').take(2).join(' '),
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.textMuted, fontSize: 8,
                fontWeight: FontWeight.w600, letterSpacing: 0.2)),
          ),
        ],
      ]),
    );
  }
}

// ─── Shared dialog ────────────────────────────────────────────────────────────

class _StyledDialog extends StatelessWidget {
  final _P p;
  final bool isDark;
  final String title, body, cancelLabel, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _StyledDialog({
    required this.p, required this.isDark, required this.title,
    required this.body, required this.cancelLabel, required this.confirmLabel,
    required this.confirmColor, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: p.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(color: p.textSecondary,
              fontSize: 13, height: 1.5)),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: p.surfaceEl,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.border),
                ),
                child: Text(cancelLabel, style: TextStyle(
                    color: p.textSecondary, fontSize: 13,
                    fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onConfirm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: confirmColor.withOpacity(0.35)),
                ),
                child: Text(confirmLabel, style: TextStyle(
                    color: confirmColor, fontSize: 13,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── Small widgets ────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Icon(icon, color: color, size: 21),
  );
}

class _SortToggle extends StatelessWidget {
  final _P p;
  final bool active;
  final VoidCallback onTap;
  const _SortToggle(
      {required this.p, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: active ? _K.accentDim : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? _K.accent.withOpacity(0.5) : p.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.tune_rounded, size: 12,
            color: active ? _K.accent : p.textSecondary),
        const SizedBox(width: 4),
        Text('Sort', style: TextStyle(fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? _K.accent : p.textSecondary)),
      ]),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final _P p;
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.p, required this.label, required this.count,
    required this.isSelected, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final active = color ?? _K.accent;
    final isDark = p.bg == const Color(0xFF0F1117);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? active.withOpacity(isDark ? 0.18 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? active.withOpacity(0.5) : p.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? active : p.textSecondary)),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(fontSize: 11,
            color: isSelected ? active.withOpacity(0.8) : p.textMuted)),
        ]),
      ),
    );
  }
}
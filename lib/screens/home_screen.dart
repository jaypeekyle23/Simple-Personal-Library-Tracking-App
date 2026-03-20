import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../main.dart';
import '../models/book.dart';
import 'add_book_screen.dart';
import 'settings_screen.dart';

// ─── Sort options ─────────────────────────────────────────────────────────────

enum SortOption {
  titleAsc,
  datePubAsc,
  datePubDesc,
  pagesAsc,
  pagesDesc,
}

extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.titleAsc:       return 'A-Z (Title)';
      case SortOption.datePubAsc:     return 'Date (Old to New)';
      case SortOption.datePubDesc:    return 'Date (New to Old)';
      case SortOption.pagesAsc:       return 'Pages (Least to Most)';
      case SortOption.pagesDesc:      return 'Pages (Most to Least)';
    }
  }
}

// ─── Shared palette (mirrors settings_screen / add_book_screen) ───────────────

// Fixed accent colours — same in both modes
class _K {
  static const accent       = Color(0xFF00C030);
  static const accentDim    = Color(0xFF00C03028);
  static const statusRead   = Color(0xFF4A9EFF);
  static const statusReadBg = Color(0xFF4A9EFF20);
  static const statusWant   = Color(0xFFFFA040);
  static const statusWantBg = Color(0xFFFFA04020);
  static const statusDnf    = Color(0xFFFF5555);
  static const statusDnfBg  = Color(0xFFFF555520);
}

// Theme-aware palette resolved at build time
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

// Status helpers
Color _statusColor(ReadingStatus status) {
  switch (status) {
    case ReadingStatus.currentlyReading: return _K.accent;
    case ReadingStatus.read:             return _K.statusRead;
    case ReadingStatus.planToRead:       return _K.statusWant;
    default:                             return _K.statusDnf;
  }
}

Color _statusBgColor(ReadingStatus status) {
  switch (status) {
    case ReadingStatus.currentlyReading: return _K.accentDim;
    case ReadingStatus.read:             return _K.statusReadBg;
    case ReadingStatus.planToRead:       return _K.statusWantBg;
    default:                             return _K.statusDnfBg;
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
  final TextEditingController _searchController = TextEditingController();
  SortOption _selectedSort = SortOption.titleAsc;
  ReadingStatus? _selectedFilter;
  Map<ReadingStatus?, int> _statusCounts = {null: 0};
  bool _showFilters = false;

  late AnimationController _filterAnimController;
  late Animation<double> _filterAnim;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _filterAnim = CurvedAnimation(
      parent: _filterAnimController,
      curve: Curves.easeInOut,
    );
    _fetchBooks();
  }

  Future<void> _fetchBooks() async {
    final query = _searchController.text;
    List<Book> baseBooks;

    if (query.isEmpty) {
      baseBooks = await isar.books.where().findAll();
    } else {
      baseBooks = await isar.books
          .filter()
          .titleContains(query, caseSensitive: false)
          .or()
          .authorContains(query, caseSensitive: false)
          .or()
          .genresElementContains(query, caseSensitive: false)
          .findAll();
    }

    Map<ReadingStatus?, int> newCounts = {null: baseBooks.length};
    for (var status in ReadingStatus.values) {
      newCounts[status] = baseBooks.where((b) => b.status == status).length;
    }

    List<Book> filteredBooks = baseBooks;
    if (_selectedFilter != null) {
      filteredBooks = filteredBooks.where((b) => b.status == _selectedFilter).toList();
    }

    filteredBooks.sort((a, b) {
      if (a.status == ReadingStatus.currentlyReading &&
          b.status != ReadingStatus.currentlyReading) return -1;
      if (b.status == ReadingStatus.currentlyReading &&
          a.status != ReadingStatus.currentlyReading) return 1;
      switch (_selectedSort) {
        case SortOption.titleAsc:
          return (a.title ?? '').compareTo(b.title ?? '');
        case SortOption.datePubAsc:
          return (a.datePublished ?? '').compareTo(b.datePublished ?? '');
        case SortOption.datePubDesc:
          return (b.datePublished ?? '').compareTo(a.datePublished ?? '');
        case SortOption.pagesAsc:
          return (a.totalPages ?? 0).compareTo(b.totalPages ?? 0);
        case SortOption.pagesDesc:
          return (b.totalPages ?? 0).compareTo(a.totalPages ?? 0);
      }
    });

    setState(() {
      _books = filteredBooks;
      _statusCounts = newCounts;
    });
  }

  Future<void> _deleteBook(int id) async {
    await isar.writeTxn(() async => await isar.books.delete(id));
    _fetchBooks();
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

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final p = mode == ThemeMode.dark ? _P.dark() : _P.light();
        return _HomeView(
          p: p,
          books: _books,
          statusCounts: _statusCounts,
          selectedSort: _selectedSort,
          selectedFilter: _selectedFilter,
          showFilters: _showFilters,
          filterAnim: _filterAnim,
          searchController: _searchController,
          onToggleFilters: _toggleFilters,
          onSortChanged: (s) { setState(() => _selectedSort = s); _fetchBooks(); },
          onFilterChanged: (f) { setState(() => _selectedFilter = f); _fetchBooks(); },
          onSearchChanged: (_) => _fetchBooks(),
          onSearchCleared: () { _searchController.clear(); _fetchBooks(); },
          onBookTap: (book) async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddBookScreen(book: book)));
            _fetchBooks();
          },
          onBookDelete: _deleteBook,
          onAddBook: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddBookScreen()));
            _fetchBooks();
          },
          onSettings: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        );
      },
    );
  }
}

// ─── Pure UI view (stateless, receives palette) ───────────────────────────────

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
  final void Function(int) onBookDelete;
  final VoidCallback onAddBook;
  final VoidCallback onSettings;

  const _HomeView({
    required this.p,
    required this.books,
    required this.statusCounts,
    required this.selectedSort,
    required this.selectedFilter,
    required this.showFilters,
    required this.filterAnim,
    required this.searchController,
    required this.onToggleFilters,
    required this.onSortChanged,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onBookTap,
    required this.onBookDelete,
    required this.onAddBook,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar()],
        body: Column(
          children: [
            _buildSearchBar(),
            _buildFilterBar(),
            SizeTransition(sizeFactor: filterAnim, child: _buildSortPanel()),
            _buildDividerWithCount(),
            Expanded(child: _buildBookList()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.settings_outlined, color: p.textSecondary, size: 22),
          onPressed: onSettings,
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LIBRARY',
                style: TextStyle(
                  color: _K.accent, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 3.5,
                )),
            const SizedBox(height: 2),
            Text('of Jaypee',
                style: TextStyle(
                  color: p.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w300, letterSpacing: -0.3, height: 1,
                )),
          ],
        ),
      ),
    );
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border, width: 1),
        ),
        child: TextField(
          controller: searchController,
          style: TextStyle(color: p.textPrimary, fontSize: 14),
          cursorColor: _K.accent,
          decoration: InputDecoration(
            hintText: 'Search title, author, tag…',
            hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: p.textMuted, size: 20),
            suffixIcon: searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: onSearchCleared,
                    child: Icon(Icons.close, color: p.textMuted, size: 18))
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
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            p: p, label: 'All', count: statusCounts[null] ?? 0,
            isSelected: selectedFilter == null,
            onTap: () => onFilterChanged(null),
          ),
          ...ReadingStatus.values.map((status) => _FilterChip(
            p: p,
            label: status.displayName,
            count: statusCounts[status] ?? 0,
            isSelected: selectedFilter == status,
            color: _statusColor(status),
            onTap: () => onFilterChanged(status),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggleFilters,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: showFilters ? _K.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: showFilters ? _K.accent.withOpacity(0.5) : p.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 13,
                      color: showFilters ? _K.accent : p.textSecondary),
                  const SizedBox(width: 5),
                  Text('Sort',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: showFilters ? FontWeight.w600 : FontWeight.w400,
                        color: showFilters ? _K.accent : p.textSecondary,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sort panel ──────────────────────────────────────────────────────────────

  Widget _buildSortPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SORT BY',
              style: TextStyle(
                color: p.textMuted, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 2,
              )),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: SortOption.values.map((sort) {
              final sel = selectedSort == sort;
              return GestureDetector(
                onTap: () => onSortChanged(sort),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _K.accent : p.surfaceEl,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sel ? _K.accent : p.border),
                  ),
                  child: Text(
                    sort.displayName,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.black : p.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Divider + count ─────────────────────────────────────────────────────────

  Widget _buildDividerWithCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(
            '${books.length} ${books.length == 1 ? 'BOOK' : 'BOOKS'}',
            style: TextStyle(
              color: p.textMuted, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: p.divider)),
        ],
      ),
    );
  }

  // ── Book list ───────────────────────────────────────────────────────────────

  Widget _buildBookList() {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: p.textMuted),
            const SizedBox(height: 16),
            Text('No books found',
                style: TextStyle(
                    color: p.textSecondary, fontSize: 16,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 6),
            Text('Add your first book with the + button',
                style: TextStyle(color: p.textMuted, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: books.length,
      itemBuilder: (_, i) => _buildBookCard(books[i]),
    );
  }

  // ── Book card ───────────────────────────────────────────────────────────────

  Widget _buildBookCard(Book book) {
    double progress = 0.0;
    String progressText = '';
    if (book.status == ReadingStatus.currentlyReading) {
      if (book.totalPages != null && book.totalPages! > 0) {
        int current = book.currentPage ?? 0;
        progress = (current / book.totalPages!).clamp(0.0, 1.0);
        progressText = '$current / ${book.totalPages}p';
      } else if (book.readPercentage != null) {
        progress = (book.readPercentage! / 100.0).clamp(0.0, 1.0);
        progressText = '${book.readPercentage!.toStringAsFixed(0)}%';
      }
    }

    final statusColor   = _statusColor(book.status);
    final statusBgColor = _statusBgColor(book.status);

    return Dismissible(
      key: ValueKey(book.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: const Color(0xFFFF3B30),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('DELETE',
                style: TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ],
        ),
      ),
      onDismissed: (_) => onBookDelete(book.id),
      child: GestureDetector(
        onTap: () => onBookTap(book),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover
              _buildCover(book),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              book.title ?? 'Unknown Title',
                              style: TextStyle(
                                color: p.textPrimary, fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2, height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              book.status.displayName,
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w500,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        book.author ?? 'Unknown Author',
                        style: TextStyle(
                            color: p.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.surfaceEl,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          book.format.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: p.textMuted, letterSpacing: 1,
                          ),
                        ),
                      ),
                      if (book.status == ReadingStatus.currentlyReading &&
                          progressText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: p.divider,
                                  valueColor: const AlwaysStoppedAnimation(
                                      _K.accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(progressText,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w700,
                                    color: _K.accent)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(Book book) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        bottomLeft: Radius.circular(12),
      ),
      child: book.coverUrl != null && book.coverUrl!.isNotEmpty
          ? Image.network(
              book.coverUrl!,
              width: 68, height: 102, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholderCover(book),
            )
          : _placeholderCover(book),
    );
  }

  Widget _placeholderCover(Book book) {
    return Container(
      width: 68, height: 102,
      decoration: BoxDecoration(
        color: p.surfaceEl,
        border: Border(right: BorderSide(color: p.border, width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: p.textMuted, size: 24),
          if (book.title != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                (book.title ?? '').split(' ').take(2).join(' '),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.textMuted, fontSize: 9,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: _K.accent,
      foregroundColor: Colors.black,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: onAddBook,
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final _P p;
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.p,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: isSelected
              ? active.withOpacity(isDark ? 0.18 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? active.withOpacity(0.5)
                : p.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? active : p.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isSelected ? active.withOpacity(0.8) : p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
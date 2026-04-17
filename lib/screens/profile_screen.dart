import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../models/book.dart';
import 'add_book_screen.dart';
import 'edit_profile_screen.dart';
import 'select_favorite_screen.dart';
import 'follow_list_screen.dart';
import '../widgets/review_dialog.dart';
import 'my_reviews_screen.dart';

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
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03028);
  static const statusRead = Color(0xFF4A9EFF);
  static const statusWant = Color(0xFFFFA040);
  static const statusDnf  = Color(0xFFFF5555);
  static const danger     = Color(0xFFFF3B30);
  static const amber      = Color(0xFFFFB800);
}

class _P {
  final Color bg, surface, surfaceEl, border, divider,
      textPrimary, textSecondary, textMuted;
  const _P({
    required this.bg, required this.surface, required this.surfaceEl,
    required this.border, required this.divider,
    required this.textPrimary, required this.textSecondary, required this.textMuted,
  });
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

Color _statusColor(ReadingStatus s) {
  switch (s) {
    case ReadingStatus.currentlyReading: return _K.accent;
    case ReadingStatus.read:             return _K.statusRead;
    case ReadingStatus.planToRead:       return _K.statusWant;
    default:                             return _K.statusDnf;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  static VoidCallback? refreshLibrary;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  List<Book> _books = [];
  final _searchController = TextEditingController();
  SortOption _selectedSort = SortOption.titleAsc;
  ReadingStatus? _selectedFilter;
  Map<ReadingStatus?, int> _statusCounts = {null: 0};
  bool _showFilters = false;

  late final AnimationController _filterAnimController;
  late final Animation<double> _filterAnim;

  String _username = 'Loading...';
  String _bio = '';
  String _profilePicUrl = '';
  List<String?> _favoriteBookUrls = [null, null, null, null];
  int _totalPagesRead = 0;
  int _followerCount  = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    ProfileScreen.refreshLibrary = _fetchData;
    _filterAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _filterAnim = CurvedAnimation(
        parent: _filterAnimController, curve: Curves.easeInOut);
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Future.wait([_fetchUserData(), _fetchBooks()]);
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        List<String?> favs = [null, null, null, null];
        if (data['favorites'] != null) {
          List<dynamic> f = data['favorites'];
          for (int i = 0; i < 4 && i < f.length; i++) {
            favs[i] = f[i] as String?;
          }
        }
        setState(() {
          _username       = data['username'] ?? 'Reader';
          _bio            = data['bio'] ?? '';
          _profilePicUrl  = data['profileImageUrl'] ?? '';
          _favoriteBookUrls = favs;
          _followerCount  = (data['followers'] as List? ?? []).length;
          _followingCount = (data['following'] as List? ?? []).length;
        });
      } else if (mounted) {
        setState(() => _username = 'Reader');
      }
    } catch (e) { debugPrint('Error fetching user: $e'); }
  }

  Future<void> _fetchBooks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('books').get();
    List<Book> base =
        snapshot.docs.map((d) => Book.fromMap(d.data(), d.id)).toList();

    int pages = 0;
    for (var b in base) {
      if (b.status == ReadingStatus.read) pages += b.totalPages ?? 0;
      else if (b.status == ReadingStatus.currentlyReading) pages += b.currentPage ?? 0;
    }

    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      base = base.where((b) {
        return (b.title?.toLowerCase().contains(query) ?? false) ||
               (b.author?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    Map<ReadingStatus?, int> counts = {null: base.length};
    for (var s in ReadingStatus.values) {
      counts[s] = base.where((b) => b.status == s).length;
    }

    List<Book> filtered = base;
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

    if (mounted) {
      setState(() { _books = filtered; _statusCounts = counts; _totalPagesRead = pages; });
    }
  }

  void _showSnack(String msg, _P p) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: p.textPrimary, fontSize: 13)),
      backgroundColor: p.surfaceEl, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
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

  // ─── NEW: Logout Confirmation Method ───
  Future<void> _confirmLogout(_P p) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log out?', 
          style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to log out of your account?', 
          style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: _K.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  void dispose() {
    if (ProfileScreen.refreshLibrary == _fetchData) {
      ProfileScreen.refreshLibrary = null;
    }
    _searchController.dispose();
    _filterAnimController.dispose();
    super.dispose();
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
          body: CustomScrollView(
            slivers: [
              _buildAppBar(p),
              SliverToBoxAdapter(child: _buildProfileHeader(p)),
              SliverToBoxAdapter(child: _buildFavoritesSection(p)),
              SliverToBoxAdapter(child: _buildLibraryDivider(p)),
              SliverToBoxAdapter(child: _buildSearchBar(p)),
              SliverToBoxAdapter(child: _buildFilterBar(p)),
              SliverToBoxAdapter(
                child: SizeTransition(
                    sizeFactor: _filterAnim,
                    child: _buildSortPanel(p)),
              ),
              SliverToBoxAdapter(child: _buildCountRow(p)),
              _buildBookList(p),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: _K.accent,
            foregroundColor: Colors.black,
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            onPressed: () async {
              final result = await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddBookScreen()));
              if (result == true) {
                _showSnack('Book added!', p);
                _fetchBooks();
              }
            },
            child: const Icon(Icons.add_rounded, size: 26),
          ),
        );
      },
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar(_P p) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true, snap: true, pinned: false,
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 48,
      actions: [
        IconButton(
          icon: Icon(Icons.logout_rounded, color: p.textMuted, size: 20),
          onPressed: () => _confirmLogout(p), // WIRED THE NEW CONFIRMATION HERE
        ),
      ],
    );
  }

  // ── Profile header ──────────────────────────────────────────────────────────
  Widget _buildProfileHeader(_P p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Avatar + name + buttons in one tight row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.surfaceEl,
                  border: Border.all(color: p.border, width: 2),
                  image: _profilePicUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_profilePicUrl),
                          fit: BoxFit.cover)
                      : null),
                child: _profilePicUrl.isEmpty
                    ? Icon(Icons.person_rounded, color: p.textMuted, size: 34)
                    : null),
              const SizedBox(width: 14),

              // Name + action buttons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_username,
                      style: TextStyle(color: p.textPrimary, fontSize: 20,
                        fontWeight: FontWeight.w700, letterSpacing: -0.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      _ActionButton(
                        label: 'Edit Profile',
                        p: p,
                        onTap: () async {
                          final saved = await Navigator.push(context,
                            MaterialPageRoute(builder: (_) => EditProfileScreen(
                              currentUsername: _username,
                              currentBio: _bio,
                              currentPicUrl: _profilePicUrl,
                            )));
                          if (saved == true) _fetchUserData();
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: 'Reviews',
                        icon: Icons.star_rounded,
                        iconColor: _K.amber,
                        p: p,
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => UserReviewsScreen(
                            userId: FirebaseAuth.instance.currentUser!.uid,
                            username: _username,
                          ))),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          // Bio — shown directly below, no gap when present
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_bio, style: TextStyle(
                color: p.textSecondary, fontSize: 13, height: 1.5),
              maxLines: 3, overflow: TextOverflow.ellipsis),
          ],

          const SizedBox(height: 16),

          // Stats row — tightly packed, no awkward gap
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border)),
            child: Row(children: [
              _buildStat('BOOKS',     _books.length.toString(),       null,         p),
              _buildVertDiv(p),
              _buildStat('PAGES',     _totalPagesRead.toString(),     null,         p),
              _buildVertDiv(p),
              _buildStat('FOLLOWERS', _followerCount.toString(),      'FOLLOWERS',  p),
              _buildVertDiv(p),
              _buildStat('FOLLOWING', _followingCount.toString(),     'FOLLOWING',  p),
            ]),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVertDiv(_P p) => Container(
    width: 1, height: 32, color: p.border);

  Widget _buildStat(String label, String value, String? tappableLabel, _P p) {
    final tappable = tappableLabel != null;
    return Expanded(
      child: GestureDetector(
        onTap: tappable ? () {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => FollowListScreen(
                userId: user.uid,
                initialIndex: label == 'FOLLOWERS' ? 0 : 1)));
          }
        } : null,
        child: Column(children: [
          Text(value, style: TextStyle(
            color: tappable ? _K.accent : p.textPrimary,
            fontSize: 18, fontWeight: FontWeight.w700,
            letterSpacing: -0.3)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
            color: p.textMuted, fontSize: 8,
            fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ]),
      ),
    );
  }

  // ── Favorites section ───────────────────────────────────────────────────────
  Widget _buildFavoritesSection(_P p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FAVOURITE BOOKS', style: TextStyle(
              color: p.textMuted, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            Text('tap · hold to remove', style: TextStyle(
              color: p.textMuted.withOpacity(0.5), fontSize: 9,
              fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(4, (i) {
            final url = _favoriteBookUrls[i];
            final slotW = (MediaQuery.of(context).size.width - 40 - 24) / 4;
            return Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
              child: GestureDetector(
                onTap: () async {
                  final selected = await Navigator.push<String?>(context,
                    MaterialPageRoute(
                        builder: (_) => SelectFavoriteScreen(userBooks: _books)));
                  if (selected != null && selected.isNotEmpty) {
                    setState(() => _favoriteBookUrls[i] = selected);
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users').doc(user.uid)
                          .set({'favorites': _favoriteBookUrls},
                              SetOptions(merge: true));
                    }
                  }
                },
                onLongPress: () async {
                  if (url != null) {
                    setState(() => _favoriteBookUrls[i] = null);
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users').doc(user.uid)
                          .set({'favorites': _favoriteBookUrls},
                              SetOptions(merge: true));
                    }
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    width: slotW,
                    height: slotW * 1.5,
                    decoration: BoxDecoration(
                      color: p.surfaceEl,
                      border: Border.all(color: p.border),
                      image: url != null
                          ? DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover)
                          : null),
                    child: url == null
                        ? Center(child: Icon(Icons.add_rounded,
                            color: p.textMuted, size: 22))
                        : null),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }

  // ── Library section ─────────────────────────────────────────────────────────
  Widget _buildLibraryDivider(_P p) => Container(
    height: 6, color: p.surface,
    margin: const EdgeInsets.only(bottom: 4));

  Widget _buildSearchBar(_P p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            hintText: 'Search library…',
            hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: p.textMuted, size: 19),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchController.clear(); _fetchBooks(); },
                    child: Icon(Icons.close_rounded, color: p.textMuted, size: 17))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12)),
          onChanged: (_) => _fetchBooks(),
        ),
      ),
    );
  }

  Widget _buildFilterBar(_P p) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('All', _statusCounts[null] ?? 0,
              _selectedFilter == null, () { setState(() => _selectedFilter = null); _fetchBooks(); },
              _K.accent, p),
          ...ReadingStatus.values.map((s) => _buildFilterChip(
              s.displayName, _statusCounts[s] ?? 0, _selectedFilter == s,
              () { setState(() => _selectedFilter = s); _fetchBooks(); },
              _statusColor(s), p)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _toggleFilters,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: _showFilters ? _K.accentDim : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _showFilters
                      ? _K.accent.withOpacity(0.5) : p.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.tune_rounded, size: 12,
                    color: _showFilters ? _K.accent : p.textSecondary),
                const SizedBox(width: 4),
                Text('Sort', style: TextStyle(
                  fontSize: 12,
                  fontWeight: _showFilters ? FontWeight.w600 : FontWeight.w400,
                  color: _showFilters ? _K.accent : p.textSecondary)),
              ])),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, bool isSelected,
      VoidCallback onTap, Color activeColor, _P p) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? activeColor.withOpacity(0.5) : p.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? activeColor : p.textSecondary)),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(
            fontSize: 11,
            color: isSelected ? activeColor.withOpacity(0.8) : p.textMuted)),
        ]),
      ),
    );
  }

  Widget _buildSortPanel(_P p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SORT BY', style: TextStyle(
          color: p.textMuted, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7,
          children: SortOption.values.map((sort) {
            final sel = _selectedSort == sort;
            return GestureDetector(
              onTap: () { setState(() => _selectedSort = sort); _fetchBooks(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? _K.accent : p.surfaceEl,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sel ? _K.accent : p.border)),
                child: Text(sort.displayName, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: sel ? Colors.black : p.textSecondary))));
          }).toList()),
      ]),
    );
  }

  Widget _buildCountRow(_P p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        Text('YOUR LIBRARY', style: TextStyle(
          color: p.textMuted, fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: p.divider)),
      ]),
    );
  }

  Widget _buildBookList(_P p) {
    if (_books.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 44, color: p.textMuted),
            const SizedBox(height: 14),
            Text('No books yet', style: TextStyle(
              color: p.textSecondary, fontSize: 16, fontWeight: FontWeight.w300)),
            const SizedBox(height: 5),
            Text('Tap + to add your first book',
                style: TextStyle(color: p.textMuted, fontSize: 12)),
          ])),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
            (_, i) => _buildCard(_books[i], p),
            childCount: _books.length),
      ),
    );
  }

  Widget _buildCard(Book book, _P p) {
    double progress = 0.0;
    String progressText = '';
    if (book.status == ReadingStatus.currentlyReading) {
      if (book.totalPages != null && book.totalPages! > 0) {
        progress = ((book.currentPage ?? 0) / book.totalPages!).clamp(0.0, 1.0);
        progressText = '${book.currentPage} / ${book.totalPages}p';
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
        builder: (ctx) => Dialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Delete book', style: TextStyle(color: p.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Remove "${book.title}" from your library?',
                style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.5)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(false),
                  child: Container(height: 40,
                    decoration: BoxDecoration(color: p.surfaceEl,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border)),
                    child: Center(child: Text('Cancel', style: TextStyle(
                      color: p.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(true),
                  child: Container(height: 40,
                    decoration: BoxDecoration(
                      color: _K.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _K.danger.withOpacity(0.35))),
                    child: const Center(child: Text('Delete', style: TextStyle(
                      color: _K.danger, fontSize: 13, fontWeight: FontWeight.w600)))))),
              ]),
            ]),
          ),
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
        ])),
      onDismissed: (_) {
        if (book.id != null) {
          _deleteBook(book.id!);
          _showSnack('Book deleted.', p);
        }
      },
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddBookScreen(book: book)));
          if (result == true) { _showSnack('Book updated!', p); _fetchBooks(); }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Cover
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12)),
              child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                  ? Image.network(book.coverUrl!, width: 64, height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderCover(p))
                  : _placeholderCover(p)),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(book.title ?? 'Unknown',
                        style: TextStyle(color: p.textPrimary, fontSize: 14,
                          fontWeight: FontWeight.w600, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(book.status.displayName,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w500, color: sc))),
                    ]),
                    const SizedBox(height: 3),
                    Text(book.author ?? 'Unknown Author',
                      style: TextStyle(color: p.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),

                    if (book.rating != null && book.rating! > 0) ...[
                      const SizedBox(height: 5),
                      Row(mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            i < book.rating!
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < book.rating!
                                ? _K.amber : p.textMuted,
                            size: 13)))),
                    ],

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
                                const AlwaysStoppedAnimation(_K.accent)))),
                        const SizedBox(width: 7),
                        Text(progressText, style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _K.accent)),
                      ]),
                    ],
                  ],
                ),
              ),
            ),

            // Review button
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: GestureDetector(
                onTap: () async {
                  await showDialog(context: context,
                      builder: (_) => ReviewDialog(book: book));
                  _fetchBooks();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.rate_review_outlined,
                      color: p.textMuted, size: 20)))),
          ]),
        ),
      ),
    );
  }

  Widget _placeholderCover(_P p) => Container(
    width: 64, height: 96,
    decoration: BoxDecoration(
      color: p.surfaceEl,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))),
    child: Icon(Icons.menu_book, color: p.textMuted));
}

// ─── Small action button ──────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final _P p;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label, required this.p, required this.onTap,
    this.icon, this.iconColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? p.textSecondary, size: 13),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(
          color: p.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ])));
}
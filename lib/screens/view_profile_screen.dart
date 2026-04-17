import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/book.dart';
import 'follow_list_screen.dart';
import 'chat_screen.dart';
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
class ViewProfileScreen extends StatefulWidget {
  final String userId;
  const ViewProfileScreen({super.key, required this.userId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen>
    with TickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  String _username = 'Loading...';
  String _bio = '';
  String _profilePicUrl = '';
  List<String?> _favoriteBookUrls = [null, null, null, null];

  List<Book> _allBooks = [];
  List<Book> _books = [];
  final _searchController = TextEditingController();
  SortOption _selectedSort = SortOption.titleAsc;
  ReadingStatus? _selectedFilter;
  Map<ReadingStatus?, int> _statusCounts = {null: 0};
  int _totalPagesRead = 0;

  bool _showFilters = false;
  late final AnimationController _filterAnimController;
  late final Animation<double> _filterAnim;

  bool _isPrivate    = false;
  bool _isFollowing  = false;
  bool _hasRequested = false;
  int  _followerCount  = 0;
  int  _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _filterAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _filterAnim = CurvedAnimation(
        parent: _filterAnimController, curve: Curves.easeInOut);
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async => await _fetchUserData();

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(widget.userId).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      List<String?> favs = [null, null, null, null];
      if (data['favorites'] != null) {
        List<dynamic> f = data['favorites'];
        for (int i = 0; i < 4 && i < f.length; i++) {
          favs[i] = f[i] as String?;
        }
      }

      _isPrivate      = data['isPrivate'] ?? false;
      List followers  = data['followers'] ?? [];
      List following  = data['following'] ?? [];
      List requests   = data['followRequests'] ?? [];

      _followerCount  = followers.length;
      _followingCount = following.length;

      if (currentUser != null) {
        _isFollowing  = followers.contains(currentUser!.uid);
        _hasRequested = requests.contains(currentUser!.uid);
      }

      _username      = data['username'] ?? 'Reader';
      _bio           = data['bio'] ?? '';
      _profilePicUrl = data['profileImageUrl'] ?? '';
      _favoriteBookUrls = favs;

      if (!isLocked()) {
        final snap = await FirebaseFirestore.instance
            .collection('users').doc(widget.userId).collection('books').get();
        _allBooks = snap.docs.map((d) => Book.fromMap(d.data(), d.id)).toList();
        _applyFiltersAndSort();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    int pages = 0;
    for (var b in _allBooks) {
      if (b.status == ReadingStatus.read) pages += b.totalPages ?? 0;
      else if (b.status == ReadingStatus.currentlyReading) pages += b.currentPage ?? 0;
    }

    List<Book> filtered = List.from(_allBooks);
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered.where((b) {
        return (b.title?.toLowerCase().contains(query) ?? false) ||
               (b.author?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    Map<ReadingStatus?, int> counts = {null: filtered.length};
    for (var s in ReadingStatus.values) {
      counts[s] = filtered.where((b) => b.status == s).length;
    }

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
      setState(() {
        _books = filtered;
        _statusCounts = counts;
        _totalPagesRead = pages;
      });
    }
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
    _showFilters ? _filterAnimController.forward() : _filterAnimController.reverse();
  }

  Future<void> _toggleFollow() async {
    if (currentUser == null) return;
    final targetRef = FirebaseFirestore.instance
        .collection('users').doc(widget.userId);
    final myRef = FirebaseFirestore.instance
        .collection('users').doc(currentUser!.uid);

    final bool wasFollowing  = _isFollowing;
    final bool hadRequested  = _hasRequested;
    final int  oldFollowers  = _followerCount;

    setState(() {
      if (_isFollowing) {
        _isFollowing = false; _followerCount--;
      } else if (_hasRequested) {
        _hasRequested = false;
      } else if (_isPrivate) {
        _hasRequested = true;
      } else {
        _isFollowing = true; _followerCount++;
      }
    });

    try {
      if (wasFollowing || hadRequested) {
        await targetRef.update({
          'followers':      FieldValue.arrayRemove([currentUser!.uid]),
          'followRequests': FieldValue.arrayRemove([currentUser!.uid]),
        });
        await myRef.update({'following': FieldValue.arrayRemove([widget.userId])});
        try {
          await targetRef.collection('notifications')
              .doc('follow_${currentUser!.uid}').delete();
          await targetRef.collection('notifications')
              .doc('follow_req_${currentUser!.uid}').delete();
        } catch (_) {}
      } else if (_isPrivate) {
        await targetRef.update({'followRequests': FieldValue.arrayUnion([currentUser!.uid])});
        try {
          final me = await FirebaseFirestore.instance
              .collection('users').doc(currentUser!.uid).get();
          await targetRef.collection('notifications')
              .doc('follow_req_${currentUser!.uid}').set({
            'type': 'follow_request', 'senderId': currentUser!.uid,
            'senderName': me.data()?['username'] ?? 'Someone',
            'senderPic':  me.data()?['profileImageUrl'] ?? '',
            'isRead': false, 'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) { debugPrint('Notif error: $e'); }
      } else {
        await targetRef.update({'followers': FieldValue.arrayUnion([currentUser!.uid])});
        await myRef.update({'following': FieldValue.arrayUnion([widget.userId])});
        try {
          final me = await FirebaseFirestore.instance
              .collection('users').doc(currentUser!.uid).get();
          await targetRef.collection('notifications')
              .doc('follow_${currentUser!.uid}').set({
            'type': 'follow', 'senderId': currentUser!.uid,
            'senderName': me.data()?['username'] ?? 'Someone',
            'senderPic':  me.data()?['profileImageUrl'] ?? '',
            'isRead': false, 'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) { debugPrint('Notif error: $e'); }
        _fetchUserData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing  = wasFollowing;
          _hasRequested = hadRequested;
          _followerCount = oldFollowers;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update follow status.')));
      }
    }
  }

  bool isLocked() =>
      _isPrivate && !_isFollowing && currentUser?.uid != widget.userId;

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: p.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context)),
            centerTitle: true,
            title: _isLoading ? null : Text(_username,
              style: TextStyle(color: p.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w600, letterSpacing: -0.3)),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  color: _K.accent, strokeWidth: 2.5))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _buildProfileHeader(p)),
                  if (isLocked())
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: p.surfaceEl, shape: BoxShape.circle,
                              border: Border.all(color: p.border)),
                            child: Icon(Icons.lock_outline_rounded,
                                size: 30, color: p.textMuted)),
                          const SizedBox(height: 16),
                          Text('This account is private', style: TextStyle(
                            color: p.textSecondary, fontSize: 15,
                            fontWeight: FontWeight.w300)),
                          const SizedBox(height: 4),
                          Text('Follow to see their books and reviews.',
                            style: TextStyle(color: p.textMuted, fontSize: 12)),
                        ],
                      )),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _buildFavoritesSection(p)),
                    SliverToBoxAdapter(child: _buildLibraryDivider(p)),
                    SliverToBoxAdapter(child: _buildSearchBar(p)),
                    SliverToBoxAdapter(child: _buildFilterBar(p)),
                    SliverToBoxAdapter(child: SizeTransition(
                        sizeFactor: _filterAnim,
                        child: _buildSortPanel(p))),
                    SliverToBoxAdapter(child: _buildCountRow(p)),
                    _buildBookList(p),
                  ],
                ]),
        );
      },
    );
  }

  // ── Profile header ──────────────────────────────────────────────────────────
  Widget _buildProfileHeader(_P p) {
    final isOwnProfile = currentUser?.uid == widget.userId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Avatar + name + buttons
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: p.surfaceEl,
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

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_username, style: TextStyle(
                color: p.textPrimary, fontSize: 20,
                fontWeight: FontWeight.w700, letterSpacing: -0.5),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),

              // Action buttons row
              if (!isOwnProfile)
                Row(children: [
                  // Follow / Requested / Following button
                  Expanded(child: GestureDetector(
                    onTap: _toggleFollow,
                    child: Container(
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isFollowing || _hasRequested
                            ? p.surface : _K.accent,
                        border: Border.all(
                          color: _isFollowing || _hasRequested
                              ? p.border : Colors.transparent),
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _isFollowing ? 'Following'
                            : _hasRequested ? 'Requested' : 'Follow',
                        style: TextStyle(
                          color: _isFollowing || _hasRequested
                              ? p.textSecondary : Colors.black,
                          fontSize: 12, fontWeight: FontWeight.w700))))),

                  if (!isLocked()) ...[
                    const SizedBox(width: 8),

                    // Message button
                    Expanded(child: _ViewActionButton(
                      label: 'Message',
                      p: p,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ChatScreen(
                          targetUserId: widget.userId,
                          targetUserName: _username,
                          targetUserPic: _profilePicUrl))),
                    )),
                    const SizedBox(width: 8),

                    // Reviews button
                    Expanded(child: _ViewActionButton(
                      label: 'Reviews',
                      icon: Icons.star_rounded,
                      iconColor: _K.amber,
                      p: p,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => UserReviewsScreen(
                          userId: widget.userId,
                          username: _username))),
                    )),
                  ],
                ]),
            ],
          )),
        ]),

        // Bio
        if (_bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_bio, style: TextStyle(
              color: p.textSecondary, fontSize: 13, height: 1.5),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        ],

        const SizedBox(height: 16),

        // Stats card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border)),
          child: Row(children: [
            _buildStat('BOOKS',
                isLocked() ? '—' : _allBooks.length.toString(), null, p),
            _buildVertDiv(p),
            _buildStat('PAGES',
                isLocked() ? '—' : _totalPagesRead.toString(), null, p),
            _buildVertDiv(p),
            _buildStat('FOLLOWERS', _followerCount.toString(),
                'FOLLOWERS', p),
            _buildVertDiv(p),
            _buildStat('FOLLOWING', _followingCount.toString(),
                'FOLLOWING', p),
          ]),
        ),

        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildVertDiv(_P p) =>
      Container(width: 1, height: 32, color: p.border);

  Widget _buildStat(String label, String value, String? tappable, _P p) {
    return Expanded(
      child: GestureDetector(
        onTap: tappable != null ? () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => FollowListScreen(
              userId: widget.userId,
              initialIndex: label == 'FOLLOWERS' ? 0 : 1)));
        } : null,
        child: Column(children: [
          Text(value, style: TextStyle(
            color: tappable != null ? _K.accent : p.textPrimary,
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

  // ── Favourites section ──────────────────────────────────────────────────────
  Widget _buildFavoritesSection(_P p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('FAVOURITE BOOKS', style: TextStyle(
          color: p.textMuted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(4, (i) {
            final url = _favoriteBookUrls[i];
            final slotW = (MediaQuery.of(context).size.width - 40 - 24) / 4;
            return Padding(
              padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
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
                      ? Center(child: Icon(Icons.book_rounded,
                          color: p.textMuted.withOpacity(0.3), size: 22))
                      : null),
              ),
            );
          }),
        ),
      ]),
    );
  }

  // ── Library section ─────────────────────────────────────────────────────────
  Widget _buildLibraryDivider(_P p) =>
      Container(height: 6, color: p.surface,
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
                    onTap: () { _searchController.clear(); _applyFiltersAndSort(); },
                    child: Icon(Icons.close_rounded, color: p.textMuted, size: 17))
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12)),
          onChanged: (_) => _applyFiltersAndSort(),
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
              _selectedFilter == null,
              () { setState(() => _selectedFilter = null); _applyFiltersAndSort(); },
              _K.accent, p),
          ...ReadingStatus.values.map((s) => _buildFilterChip(
              s.displayName, _statusCounts[s] ?? 0, _selectedFilter == s,
              () { setState(() => _selectedFilter = s); _applyFiltersAndSort(); },
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
              onTap: () { setState(() => _selectedSort = sort); _applyFiltersAndSort(); },
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
        Text("${_username.toUpperCase()}'S LIBRARY", style: TextStyle(
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
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.menu_book_outlined, size: 44, color: p.textMuted),
          const SizedBox(height: 14),
          Text('No books yet', style: TextStyle(
            color: p.textSecondary, fontSize: 16, fontWeight: FontWeight.w300)),
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

    return Container(
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
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(book.title ?? 'Unknown',
                  style: TextStyle(color: p.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w600, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(book.status.displayName, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500, color: sc))),
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
                      color: i < book.rating! ? _K.amber : p.textMuted,
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
                      valueColor: const AlwaysStoppedAnimation(_K.accent)))),
                  const SizedBox(width: 7),
                  Text(progressText, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: _K.accent)),
                ]),
              ],
            ],
          ),
        )),
      ]),
    );
  }

  Widget _placeholderCover(_P p) => Container(
    width: 64, height: 96,
    decoration: BoxDecoration(
      color: p.surfaceEl,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        bottomLeft: Radius.circular(12))),
    child: Icon(Icons.menu_book, color: p.textMuted));
}

// ─── Small action button (read-only, no edit) ─────────────────────────────────
class _ViewActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final _P p;
  final VoidCallback onTap;

  const _ViewActionButton({
    required this.label, required this.p, required this.onTap,
    this.icon, this.iconColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surfaceEl,
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor ?? p.textSecondary, size: 13),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(
          color: p.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w600)),
      ])));
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'add_book_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart'; 
import '../widgets/global_search_sheet.dart';
import '../models/book.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; 

  Future<void> _clearNotifications() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final unreadNotifs = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ─── Ensure we have exactly 5 screens ───
    final List<Widget> screens = [
      const HomeScreen(),        
      const NotificationsScreen(), 
      const SizedBox(),          
      const ProfileScreen(),     
      const SettingsScreen(),    
    ];

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
        final isDark = mode == ThemeMode.dark;

        final bg        = isDark ? const Color(0xFF0F1117) : const Color(0xFFF4F5F7);
        final surface   = isDark ? const Color(0xFF1A1D27) : const Color(0xFFFFFFFF);
        final border    = isDark ? const Color(0xFF2A2F45) : const Color(0xFFDDE0E8);
        final textMuted = isDark ? const Color(0xFF4A5068) : const Color(0xFF9AA0B0);
        const accent    = Color(0xFF00C030);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: surface,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bg,
            // Safety fallback for the index
            body: _currentIndex < screens.length ? screens[_currentIndex] : screens[0],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border, width: 1)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      // 1. Feed 
                      _NavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Feed',
                        index: 0,
                        currentIndex: _currentIndex,
                        accent: accent,
                        textMuted: textMuted,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),

                      // 2. Activity (WITH BADGE)
                      _NavItem(
                        icon: Icons.notifications_none_rounded,
                        activeIcon: Icons.notifications_rounded,
                        label: 'Activity',
                        index: 1,
                        currentIndex: _currentIndex,
                        accent: accent,
                        textMuted: textMuted,
                        showBadge: true,
                        onTap: () {
                          setState(() => _currentIndex = 1);
                          _clearNotifications();
                        },
                      ),

                      // 3. Add Button 
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final selectedBook = await showModalBottomSheet<Book>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const GlobalSearchSheet(),
                            );
                            if (selectedBook != null && context.mounted) {
                              final didSave = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddBookScreen(book: selectedBook)),
                              );
                              if (didSave == true) {
                                setState(() => _currentIndex = 3);
                                ProfileScreen.refreshLibrary?.call();
                              }
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)),
                                child: const Icon(Icons.add_rounded, color: Colors.black, size: 26),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 4. Library 
                      _NavItem(
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Library',
                        index: 3,
                        currentIndex: _currentIndex,
                        accent: accent,
                        textMuted: textMuted,
                        onTap: () => setState(() => _currentIndex = 3),
                      ),

                      // 5. Settings 
                      _NavItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings_rounded,
                        label: 'Settings',
                        index: 4,
                        currentIndex: _currentIndex,
                        accent: accent,
                        textMuted: textMuted,
                        onTap: () => setState(() => _currentIndex = 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, currentIndex;
  final Color accent, textMuted;
  final VoidCallback onTap;
  final bool showBadge;

  const _NavItem({
    required this.icon, required this.activeIcon, required this.label,
    required this.index, required this.currentIndex,
    required this.accent, required this.textMuted, required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    
    // THE FIX: We isolate the base icon into its own final variable.
    // This prevents the StreamBuilder from infinitely calling itself!
    final Widget baseIcon = Icon(
      selected ? activeIcon : icon,
      key: ValueKey(selected),
      color: selected ? accent : textMuted,
      size: 24,
    );

    Widget finalIconWidget = baseIcon;

    if (showBadge) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        finalIconWidget = StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(user.uid)
              .collection('notifications').where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            int count = snapshot.data?.docs.length ?? 0;
            return Badge(
              label: Text('$count'),
              isLabelVisible: count > 0,
              backgroundColor: Colors.red,
              // We inject the baseIcon here, completely avoiding the loop!
              child: baseIcon, 
            );
          },
        );
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180), 
              child: finalIconWidget
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: selected ? accent : textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
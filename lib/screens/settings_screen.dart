import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../main.dart';
import '../services/export_service.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);
  static const blue      = Color(0xFF4A9EFF);
  static const orange    = Color(0xFFFFA040);
  static const red       = Color(0xFFFF5555);
  static const redDim    = Color(0xFFFF555518);
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
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPrivate = false;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
  }

  Future<void> _loadPrivacySetting() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isPrivate = doc.data()?['isPrivate'] ?? false;
        });
      }
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _isPrivate = value);
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'isPrivate': value,
      }, SetOptions(merge: true));
    }
  }

  void _snack(BuildContext context, String msg, _P p) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: p.textPrimary, fontSize: 13)),
      backgroundColor: p.surfaceEl, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16)));
  }

  // ─── Logout Confirmation ───
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
            child: const Text('Log Out', style: TextStyle(color: _K.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pop(context); // Pop settings screen
    }
  }

  // ─── NEW: Delete Account Confirmation ───
  Future<void> _confirmDeleteAccount(_P p) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account?', 
          style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text('This action cannot be undone. All your profile data, library, and settings will be permanently removed.', 
          style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: _K.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && user != null) {
      try {
        // 1. Delete from Firestore first
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).delete();
        
        // 2. Delete from Authentication
        await user!.delete();
        
        if (mounted) {
          Navigator.pop(context); // Pop settings screen, auth state listener should handle routing to login
        }
      } catch (e) {
        debugPrint('Error deleting account: $e');
        if (mounted) {
          _snack(context, 'Failed to delete account. Please log out and log back in to verify your identity before deleting.', p);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        final isDark = currentMode == ThemeMode.dark;
        final p = isDark ? _P.dark() : _P.light();

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: canPop,
            leading: canPop
              ? IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: p.textSecondary, size: 18),
                  onPressed: () => Navigator.pop(context))
              : null,
            centerTitle: true,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Folio', style: TextStyle(color: p.textPrimary,
                  fontSize: 20, fontWeight: FontWeight.w300, letterSpacing: -0.8)),
                const Text('.', style: TextStyle(color: _K.accent,
                  fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
            children: [

              // ── ACCOUNT ─────────────────────────────────────────────
              if (user != null) ...[
                _SectionLabel('ACCOUNT', p),
                _Card(p: p, child: Column(children: [

                  // Email row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(children: [
                      SizedBox(width: 20, child: Icon(Icons.person_outline_rounded, color: _K.accent, size: 20)),
                      const SizedBox(width: 13),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Signed in as',
                            style: TextStyle(color: p.textMuted,
                              fontSize: 11, fontWeight: FontWeight.w500,
                              letterSpacing: 0.3)),
                          const SizedBox(height: 2),
                          Text(user!.email ?? 'Unknown',
                            style: TextStyle(color: p.textPrimary,
                              fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                    ])),

                  _Divider(p),

                  // Private Account toggle
                  _ToggleTile(
                    p: p,
                    icon: Icons.lock_outline_rounded,
                    iconColor: p.textSecondary,
                    title: 'Private Account',
                    subtitle: 'Only approved followers see your library',
                    value: _isPrivate,
                    onChanged: _togglePrivacy,
                  ),

                  _Divider(p),

                  // Sign Out
                  _TapTile(
                    p: p,
                    icon: Icons.logout_rounded,
                    iconColor: _K.red,
                    title: 'Sign Out',
                    subtitle: 'Log out of your account on this device',
                    titleColor: _K.red,
                    showChevron: false,
                    onTap: () => _confirmLogout(p), 
                  ),

                  _Divider(p),

                  // Delete Account
                  _TapTile(
                    p: p,
                    icon: Icons.person_remove_rounded,
                    iconColor: _K.red,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your account & data',
                    titleColor: _K.red,
                    showChevron: false,
                    onTap: () => _confirmDeleteAccount(p), 
                  ),
                ])),
                const SizedBox(height: 28),
              ],

              // ── APPEARANCE ──────────────────────────────────────────
              _SectionLabel('APPEARANCE', p),
              _Card(p: p, child: _ToggleTile(
                p: p,
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                iconColor: isDark ? _K.accent : p.textSecondary,
                title: 'Dark Mode',
                subtitle: isDark ? 'Currently using dark theme' : 'Currently using light theme',
                value: isDark,
                onChanged: (val) async {
                  themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('isDarkMode', val);
                },
              )),
              const SizedBox(height: 28),

              // ── DATA & BACKUPS ──────────────────────────────────────
              _SectionLabel('DATA & BACKUPS (IN DEVELOPMENT)', p),
              _Card(p: p, child: Column(children: [
                _TapTile(
                  p: p,
                  icon: Icons.ios_share_rounded,
                  iconColor: _K.blue,
                  title: 'Share CSV',
                  subtitle: 'Send to Drive, Email, or Messaging apps',
                  onTap: () async {
                    _snack(context, 'Preparing your CSV…', p);
                    await ExportService.shareLibraryCsv();
                  }),
                _Divider(p),
                _TapTile(
                  p: p,
                  icon: Icons.download_rounded,
                  iconColor: _K.accent,
                  title: 'Download to Device',
                  subtitle: "Save directly to your phone's local storage",
                  onTap: () async {
                    _snack(context, 'Saving CSV to device…', p);
                    await ExportService.downloadLibraryCsvLocally();
                    if (!context.mounted) return;
                    _snack(context, 'Saved successfully!', p);
                  }),
                _Divider(p),
                _TapTile(
                  p: p,
                  icon: Icons.upload_file_rounded,
                  iconColor: _K.orange,
                  title: 'Import from CSV',
                  subtitle: 'Restore your library from a backup',
                  onTap: () async {
                    _snack(context, 'Select your CSV file…', p);
                    final ok = await ExportService.importLibraryCsv();
                    if (!context.mounted) return;
                    _snack(context,
                        ok ? 'Library restored!' : 'Import canceled or failed.', p);
                  }),
              ])),
              const SizedBox(height: 28),

              // ── ABOUT ────────────────────────────────────────────────
              _SectionLabel('ABOUT', p),
              _Card(p: p, child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  SizedBox(width: 20, child: Icon(Icons.info_outline_rounded, color: p.textSecondary, size: 20)),
                  const SizedBox(width: 13),
                  Expanded(child: Text('Version',
                    style: TextStyle(color: p.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.surfaceEl,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: p.border)),
                    child: Text('1.0.0.0',
                      style: TextStyle(color: p.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w500,
                        letterSpacing: 0.3))),
                ]))),
              const SizedBox(height: 48),

              // ── Footer ───────────────────────────────────────────────
              Center(child: Column(children: [
                Row(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Folio', style: TextStyle(color: p.textMuted,
                      fontSize: 13, fontWeight: FontWeight.w300,
                      letterSpacing: -0.5)),
                    const Text('.', style: TextStyle(color: _K.accent,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                const SizedBox(height: 3),
                Text('Your personal reading tracker',
                  style: TextStyle(color: p.textMuted, fontSize: 11)),
              ])),
            ],
          ),
        );
      },
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

/// Uniform custom toggle — identical look for both dark mode & private account.
class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final _P p;
  const _CustomToggle({
    required this.value, required this.onChanged, required this.p});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 44, height: 25,
      decoration: BoxDecoration(
        color: value ? _K.accent : p.surfaceEl,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: value ? _K.accent : p.border, width: 1)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 17, height: 17,
          decoration: BoxDecoration(
            color: value ? Colors.black.withOpacity(0.75) : p.textMuted,
            shape: BoxShape.circle)))));
}

/// A row with a toggle — no chevron.
class _ToggleTile extends StatelessWidget {
  final _P p;
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.p, required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      SizedBox(width: 20, child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 13),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: p.textPrimary,
            fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: p.textMuted, fontSize: 11)),
        ])),
      const SizedBox(width: 12),
      _CustomToggle(value: value, onChanged: onChanged, p: p),
    ]));
}

/// A tappable row — optionally shows chevron.
class _TapTile extends StatelessWidget {
  final _P p;
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  const _TapTile({
    required this.p, required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
    this.titleColor, this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      splashColor: iconColor.withOpacity(0.06),
      highlightColor: p.surfaceEl.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          SizedBox(width: 20, child: Icon(icon, color: iconColor, size: 20)),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                color: titleColor ?? p.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle,
                style: TextStyle(color: p.textMuted, fontSize: 11)),
            ])),
          if (showChevron)
            Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 16),
        ]))));
}

// ─── Layout Primitives ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text; final _P p;
  const _SectionLabel(this.text, this.p);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text,
      style: TextStyle(color: p.textMuted, fontSize: 10,
        fontWeight: FontWeight.w700, letterSpacing: 1.8)));
}

class _Card extends StatelessWidget {
  final Widget child; final _P p;
  const _Card({required this.child, required this.p});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: p.border, width: 0.8)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: child));
}

class _Divider extends StatelessWidget {
  final _P p;
  const _Divider(this.p);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 49),
    height: 0.5,
    color: p.divider);
}
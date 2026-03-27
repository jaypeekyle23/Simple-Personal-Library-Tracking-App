import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String msg, _P p) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: p.textPrimary, fontSize: 13)),
      backgroundColor: p.surfaceEl, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        final isDark = currentMode == ThemeMode.dark;
        final p = isDark ? _P.dark() : _P.light();
        final user = FirebaseAuth.instance.currentUser;

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg, elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: p.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context)),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [

              // ── ACCOUNT ─────────────────────────────────────────────
              if (user != null) ...[
                _Label('ACCOUNT', p),
                const SizedBox(height: 8),
                // User email card
                _Card(p: p, child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _K.accentDim,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _K.accent.withOpacity(0.3))),
                      child: const Icon(Icons.person_outline_rounded,
                          color: _K.accent, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Signed in as',
                          style: TextStyle(color: p.textMuted,
                            fontSize: 10, fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(user.email ?? 'Unknown',
                          style: TextStyle(color: p.textPrimary,
                            fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                  ]))),
                const SizedBox(height: 8),
                // Sign out — separate card so it stands out
                _Card(p: p, child: _Tile(
                  p: p,
                  icon: Icons.logout_rounded,
                  iconColor: _K.red,
                  title: 'Sign Out',
                  subtitle: 'Log out of your account on this device',
                  titleColor: _K.red,
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                  },
                )),
                const SizedBox(height: 24),
              ],

              // ── APPEARANCE ──────────────────────────────────────────
              _Label('APPEARANCE', p),
              const SizedBox(height: 8),
              _Card(p: p, child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(
                    isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: isDark ? _K.accent : p.textSecondary,
                    size: 20),
                  const SizedBox(width: 14),
                  Expanded(child: Text('Dark Mode',
                    style: TextStyle(color: p.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w500))),
                  // Animated toggle
                  GestureDetector(
                    onTap: () async {
                      themeNotifier.value =
                          isDark ? ThemeMode.light : ThemeMode.dark;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isDarkMode', !isDark);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 44, height: 24,
                      decoration: BoxDecoration(
                        color: isDark ? _K.accent : p.surfaceEl,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark ? _K.accent : p.border)),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 220),
                        alignment: isDark
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black87
                                : p.textMuted,
                            shape: BoxShape.circle))))),
                ]))),
              const SizedBox(height: 24),

              // ── DATA & BACKUPS ──────────────────────────────────────
              _Label('DATA & BACKUPS', p),
              const SizedBox(height: 8),
              _Card(p: p, child: Column(children: [
                _Tile(
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
                _Tile(
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
                _Tile(
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
              const SizedBox(height: 24),

              // ── ABOUT ────────────────────────────────────────────────
              _Label('ABOUT', p),
              const SizedBox(height: 8),
              _Card(p: p, child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded,
                      color: p.textSecondary, size: 20),
                  const SizedBox(width: 14),
                  Expanded(child: Text('Version',
                    style: TextStyle(color: p.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w500))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: p.surfaceEl,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: p.border)),
                    child: Text('1.0.0.0',
                      style: TextStyle(color: p.textMuted,
                        fontSize: 12, fontWeight: FontWeight.w500,
                        letterSpacing: 0.3))),
                ]))),
              const SizedBox(height: 40),

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

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text; final _P p;
  const _Label(this.text, this.p);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(color: p.textMuted, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 2));
}

class _Card extends StatelessWidget {
  final Widget child; final _P p;
  const _Card({required this.child, required this.p});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: p.surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: p.border)),
    child: child);
}

class _Divider extends StatelessWidget {
  final _P p;
  const _Divider(this.p);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 50),
    height: 1, color: p.divider);
}

class _Tile extends StatelessWidget {
  final _P p;
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _Tile({
    required this.p, required this.icon, required this.iconColor,
    required this.title, required this.subtitle, required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      splashColor: iconColor.withOpacity(0.06),
      highlightColor: p.surfaceEl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                color: titleColor ?? p.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle,
                style: TextStyle(color: p.textMuted, fontSize: 12)),
            ])),
          Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 15),
        ]))));
}
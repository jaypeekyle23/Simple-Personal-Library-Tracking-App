import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Firebase Auth Import
import '../main.dart';
import '../services/export_service.dart';

// ─── Accent & status colours (same in both modes) ─────────────────────────────
class _K {
  static const accent = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);
  static const blue = Color(0xFF4A9EFF);
  static const blueDim = Color(0xFF4A9EFF18);
  static const orange = Color(0xFFFFA040);
  static const orangeDim = Color(0xFFFFA04018);
  static const red = Color(0xFFFF5555); // Added for the logout button
}

// ─── Theme-aware palette resolved at build time ───────────────────────────────
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
        bg: Color(0xFF0F1117),
        surface: Color(0xFF1A1D27),
        surfaceEl: Color(0xFF22263A),
        border: Color(0xFF2A2F45),
        divider: Color(0xFF252A3D),
        textPrimary: Color(0xFFEEEEEE),
        textSecondary: Color(0xFF8A8FA8),
        textMuted: Color(0xFF4A5068),
      );

  factory _P.light() => const _P(
        bg: Color(0xFFF4F5F7),
        surface: Color(0xFFFFFFFF),
        surfaceEl: Color(0xFFEEF0F4),
        border: Color(0xFFDDE0E8),
        divider: Color(0xFFE8EAF0),
        textPrimary: Color(0xFF0F1117),
        textSecondary: Color(0xFF5A6070),
        textMuted: Color(0xFF9AA0B0),
      );
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _snack(BuildContext context, String msg, _P p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: TextStyle(color: p.textPrimary, fontSize: 13)),
        backgroundColor: p.surfaceEl,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        final isDark = currentMode == ThemeMode.dark;
        final p = isDark ? _P.dark() : _P.light();
        
        // Fetch the currently logged-in user
        final user = FirebaseAuth.instance.currentUser;

        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: p.textSecondary, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [

              // ── ACCOUNT ─────────────────────────────────────────────────
              if (user != null) ...[
                _SectionLabel('ACCOUNT', p),
                const SizedBox(height: 8),
                _Card(
                  p: p,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _K.accentDim,
                              radius: 16,
                              child: const Icon(Icons.person_outline_rounded,
                                  color: _K.accent, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                user.email ?? 'Unknown User',
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TileDivider(p),
                      _SettingsTile(
                        p: p,
                        icon: Icons.logout_rounded,
                        iconColor: _K.red,
                        title: 'Sign Out',
                        subtitle: 'Log out of your account on this device',
                        onTap: () async {
                          // Close settings screen first
                          Navigator.pop(context);
                          // Log out
                          await FirebaseAuth.instance.signOut();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── APPEARANCE ──────────────────────────────────────────────
              _SectionLabel('APPEARANCE', p),
              const SizedBox(height: 8),
              _Card(
                p: p,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: isDark ? _K.accent : p.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Dark Mode',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Animated toggle
                      GestureDetector(
                        onTap: () async {
                          themeNotifier.value =
                              isDark ? ThemeMode.light : ThemeMode.dark;
                          final prefs =
                              await SharedPreferences.getInstance();
                          await prefs.setBool('isDarkMode', !isDark);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 44,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDark ? _K.accent : p.surfaceEl,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? _K.accent : p.border,
                            ),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 220),
                            alignment: isDark
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(3),
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black87 : p.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── DATA & BACKUPS ──────────────────────────────────────────
              _SectionLabel('DATA & BACKUPS', p),
              const SizedBox(height: 8),
              _Card(
                p: p,
                child: Column(
                  children: [
                    _SettingsTile(
                      p: p,
                      icon: Icons.share_rounded,
                      iconColor: _K.blue,
                      title: 'Share CSV',
                      subtitle: 'Send to Drive, Email, or Messaging apps',
                      onTap: () async {
                        _snack(context, 'Preparing your CSV…', p);
                        await ExportService.shareLibraryCsv();
                      },
                    ),
                    _TileDivider(p),
                    _SettingsTile(
                      p: p,
                      icon: Icons.download_rounded,
                      iconColor: _K.accent,
                      title: 'Download to Device',
                      subtitle: "Save directly to your phone's local storage",
                      onTap: () async {
                        _snack(context, 'Saving CSV to device…', p);
                        await ExportService.downloadLibraryCsvLocally();
                        if (!context.mounted) return;
                        _snack(context, 'Successfully saved to device!', p);
                      },
                    ),
                    _TileDivider(p),
                    _SettingsTile(
                      p: p,
                      icon: Icons.upload_file_rounded,
                      iconColor: _K.orange,
                      title: 'Import from CSV',
                      subtitle: 'Restore your library from a backup',
                      onTap: () async {
                        _snack(context, 'Select your CSV file…', p);
                        final success =
                            await ExportService.importLibraryCsv();
                        if (!context.mounted) return;
                        _snack(
                          context,
                          success
                              ? 'Library restored successfully!'
                              : 'Import canceled or failed.',
                          p,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── ABOUT ───────────────────────────────────────────────────
              _SectionLabel('ABOUT', p),
              const SizedBox(height: 8),
              _Card(
                p: p,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: p.textSecondary, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Version',
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '1.0.0.0',
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Footer ──────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Library of Jaypee',
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your personal reading tracker',
                      style: TextStyle(
                          color: p.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
    return Text(
      text,
      style: TextStyle(
        color: p.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
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
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border, width: 1),
      ),
      child: child,
    );
  }
}

class _TileDivider extends StatelessWidget {
  final _P p;
  const _TileDivider(this.p);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 50),
      height: 1,
      color: p.divider,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final _P p;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.p,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _K.accent.withOpacity(0.05),
        highlightColor: p.surfaceEl,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          color: p.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: p.textMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
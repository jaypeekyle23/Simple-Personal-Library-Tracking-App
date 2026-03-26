import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Palette (shared across app) ─────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03015);

  // Dark
  static const darkBg      = Color(0xFF0F1117);
  static const darkSurface = Color(0xFF1A1D27);
  static const darkBorder  = Color(0xFF2A2F45);
  static const darkText    = Color(0xFFEEEEEE);
  static const darkSub     = Color(0xFF8A8FA8);
  static const darkMuted   = Color(0xFF4A5068);

  // Light
  static const lightBg      = Color(0xFFF4F5F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFDDE0E8);
  static const lightText    = Color(0xFF0F1117);
  static const lightSub     = Color(0xFF5A6070);
  static const lightMuted   = Color(0xFF9AA0B0);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  final _identifierController = TextEditingController();
  final _usernameController   = TextEditingController();
  final _passwordController   = TextEditingController();

  bool _isLogin    = true;
  bool _isLoading  = false;
  bool _obscurePwd = true;
  String _errorMessage = '';

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Logic (unchanged) ────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    setState(() { _errorMessage = ''; _isLoading = true; });

    try {
      final identifier = _identifierController.text.trim();
      final password   = _passwordController.text.trim();

      if (_isLogin) {
        String loginEmail = identifier;

        if (!identifier.contains('@')) {
          final q = await _db
              .collection('users')
              .where('username', isEqualTo: identifier)
              .limit(1)
              .get();

          if (q.docs.isEmpty) {
            setState(() { _errorMessage = 'Username not found.'; _isLoading = false; });
            return;
          }
          loginEmail = q.docs.first.data()['email'];
        }

        await _auth.signInWithEmailAndPassword(
            email: loginEmail, password: password);
      } else {
        final username = _usernameController.text.trim();
        if (username.isEmpty || identifier.isEmpty || password.isEmpty) {
          setState(() { _errorMessage = 'Please fill in all fields.'; _isLoading = false; });
          return;
        }

        final existing = await _db
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          setState(() { _errorMessage = 'That username is already taken.'; _isLoading = false; });
          return;
        }

        final cred = await _auth.createUserWithEmailAndPassword(
            email: identifier, password: password);

        await _db.collection('users').doc(cred.user!.uid).set({
          'username': username,
          'email': identifier,
        });

        await _auth.signOut();

        if (mounted) {
          setState(() {
            _isLogin = true;
            _passwordController.clear();
            _usernameController.clear();
          });
          _showSnack('Account created! Please sign in.');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'An error occurred.');
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    _fadeCtrl.reset();
    setState(() { _isLogin = !_isLogin; _errorMessage = ''; });
    _fadeCtrl.forward();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: _K.darkText, fontSize: 13)),
      backgroundColor: _K.darkSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Always dark on auth screen for cinematic feel
    const bg      = _K.darkBg;
    const surface = _K.darkSurface;
    const border  = _K.darkBorder;
    const text    = _K.darkText;
    const sub     = _K.darkSub;
    const muted   = _K.darkMuted;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    // ── Brand hero ──────────────────────────────────────────
                    _buildHero(),

                    const SizedBox(height: 48),

                    // ── Form card ───────────────────────────────────────────
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildForm(
                          surface: surface,
                          border: border,
                          text: text,
                          sub: sub,
                          muted: muted),
                    ),

                    const Spacer(),

                    // ── Switch mode ─────────────────────────────────────────
                    _buildSwitchRow(sub),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Brand hero ──────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folio wordmark
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Folio',
              style: TextStyle(
                color: _K.darkText,
                fontSize: 52,
                fontWeight: FontWeight.w300,
                letterSpacing: -2.5,
                height: 1,
              ),
            ),
            const Text(
              '.',
              style: TextStyle(
                color: _K.accent,
                fontSize: 52,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'YOUR PERSONAL LIBRARY',
          style: TextStyle(
            color: _K.darkMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 36),

        // Headline
        Text(
          _isLogin ? 'Welcome\nback.' : 'Create your\naccount.',
          style: const TextStyle(
            color: _K.darkText,
            fontSize: 32,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Sign in to continue tracking your reading.'
              : 'Join Folio and start building your library.',
          style: const TextStyle(
            color: _K.darkSub,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────────

  Widget _buildForm({
    required Color surface,
    required Color border,
    required Color text,
    required Color sub,
    required Color muted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error banner
        if (_errorMessage.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B3015),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF3B3040)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFFF5555), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                        color: Color(0xFFFF5555), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Username field (register only)
        if (!_isLogin) ...[
          _buildField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.alternate_email_rounded,
            surface: surface,
            border: border,
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 14),
        ],

        // Email / identifier
        _buildField(
          controller: _identifierController,
          label: _isLogin ? 'Email or Username' : 'Email Address',
          icon: Icons.mail_outline_rounded,
          surface: surface,
          border: border,
          text: text,
          sub: sub,
          keyboardType: _isLogin
              ? TextInputType.text
              : TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // Password
        _buildField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          surface: surface,
          border: border,
          text: text,
          sub: sub,
          obscure: _obscurePwd,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePwd = !_obscurePwd),
            child: Icon(
              _obscurePwd
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: muted,
              size: 18,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Submit button
        _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: _K.accent, strokeWidth: 2.5),
                ),
              )
            : _buildSubmitButton(),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color surface,
    required Color border,
    required Color text,
    required Color sub,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _K.darkMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            autocorrect: false,
            style: TextStyle(
              color: text,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            cursorColor: _K.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: _K.darkMuted, size: 18),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: suffixIcon,
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitForm,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _K.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLogin ? 'Sign In' : 'Create Account',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.black, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Switch row ──────────────────────────────────────────────────────────────

  Widget _buildSwitchRow(Color sub) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? "Don't have an account?" : 'Already have an account?',
          style: TextStyle(color: sub, fontSize: 13),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _toggleMode,
          child: Text(
            _isLogin ? 'Register' : 'Sign in',
            style: const TextStyle(
              color: _K.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
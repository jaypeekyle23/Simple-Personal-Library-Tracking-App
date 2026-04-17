import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ADDED: Import for dotenv

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);
  static const danger    = Color(0xFFFF5555);
  static const warn      = Color(0xFFFFB800);

  static const bg        = Color(0xFF0F1117);
  static const surface   = Color(0xFF1A1D27);
  static const surfaceEl = Color(0xFF22263A);
  static const border    = Color(0xFF2A2F45);
  static const text      = Color(0xFFEEEEEE);
  static const sub       = Color(0xFF8A8FA8);
  static const muted     = Color(0xFF4A5068);

  static Color get dangerBg  => danger.withOpacity(0.10);
  static Color get dangerBdr => danger.withOpacity(0.28);
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

  // ─── App State Helpers ────────────────────────────────────────────────────

  Future<FirebaseApp> _getAuthHelperApp() async {
    try {
      return Firebase.app('AuthHelperApp');
    } catch (e) {
      return await Firebase.initializeApp(
          name: 'AuthHelperApp', options: Firebase.app().options);
    }
  }

  /// Returns a human-readable error or an empty string if it's a cancellation
  String _getFriendlyErrorMessage(dynamic e) {
    final errStr = e.toString().toLowerCase();
    
    // Check for cancellations first - return empty string to show nothing
    if (errStr.contains('sign_in_canceled') || 
        errStr.contains('12501') || 
        errStr.contains('user_cancelled') ||
        errStr.contains('cancel')) {
      return ''; 
    }

    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email/username or password.';
        case 'invalid-email':
          return 'The email address is not valid.';
        case 'email-already-in-use':
          return 'This email is already in use.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return e.message ?? 'An unexpected error occurred.';
      }
    }
    
    if (errStr.contains('network_error')) {
      return 'Check your internet connection and try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  // ─── Logic ────────────────────────────────────────────────────────────────

  Future<void> _submitForm() async {
    final identifier = _identifierController.text.trim();
    final password   = _passwordController.text.trim();
    final username   = _usernameController.text.trim();

    if (identifier.isEmpty || password.isEmpty || (!_isLogin && username.isEmpty)) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    setState(() { _errorMessage = ''; _isLoading = true; });

    try {
      if (_isLogin) {
        String loginEmail = identifier;
        
        if (!identifier.contains('@')) {
          final q = await _db.collection('users')
              .where('username', isEqualTo: identifier).limit(1).get();
          if (q.docs.isEmpty) {
            setState(() { _errorMessage = 'Username not found.'; _isLoading = false; });
            return;
          }
          loginEmail = q.docs.first.data()['email'];
        }

        final helperApp = await _getAuthHelperApp();
        final helperAuth = FirebaseAuth.instanceFor(app: helperApp);
        
        final cred = await helperAuth.signInWithEmailAndPassword(
            email: loginEmail, password: password);
        
        if (!cred.user!.emailVerified) {
          await helperAuth.signOut();
          if (mounted) {
            setState(() { _isLoading = false; });
            _showUnverifiedDialog(loginEmail);
          }
          return;
        }

        await helperAuth.signOut();
        await _auth.signInWithEmailAndPassword(email: loginEmail, password: password);

      } else {
        final existing = await _db.collection('users')
            .where('username', isEqualTo: username).limit(1).get();
        if (existing.docs.isNotEmpty) {
          setState(() { _errorMessage = 'That username is already taken.'; _isLoading = false; });
          return;
        }

        final helperApp = await _getAuthHelperApp();
        final helperAuth = FirebaseAuth.instanceFor(app: helperApp);
        final helperDb = FirebaseFirestore.instanceFor(app: helperApp);
        
        UserCredential? helperCred;
        try {
          helperCred = await helperAuth.createUserWithEmailAndPassword(
              email: identifier, password: password);
          await helperDb.collection('users').doc(helperCred.user!.uid).set(
              {'username': username, 'email': identifier});
          await helperCred.user!.sendEmailVerification();
          await helperAuth.signOut();
        } catch (e) {
          if (helperCred?.user != null) await helperCred!.user!.delete();
          rethrow;
        }

        if (mounted) {
          setState(() => _isLoading = false);
          _showVerificationDialog(identifier);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = _getFriendlyErrorMessage(e));
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _showVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FolioDialog(
        icon: Icons.mark_email_unread_outlined,
        iconColor: _K.accent,
        title: 'Verify your email',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("We've sent a verification link to:",
                style: TextStyle(color: _K.sub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _K.surfaceEl,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _K.border)),
              child: Text(email, style: const TextStyle(
                  color: _K.text, fontWeight: FontWeight.w600, fontSize: 13))),
            const SizedBox(height: 12),
            Text('Click the link in that email to activate your account before signing in.',
                style: TextStyle(color: _K.sub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _K.warn),
              const SizedBox(width: 6),
              Expanded(child: Text("Can't find it? Check your Spam or Junk folder.",
                  style: TextStyle(color: _K.warn, fontSize: 12, height: 1.4))),
            ]),
          ],
        ),
        confirmLabel: 'Got it',
        onConfirm: () {
          Navigator.of(context).pop();
          setState(() {
            _isLogin = true;
            _passwordController.clear();
            _usernameController.clear();
          });
          _fadeCtrl.forward(from: 0.0);
        },
      ),
    );
  }

  void _showUnverifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (_) => _FolioDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: _K.warn,
        title: 'Email not verified',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You must verify your email before signing in.',
                style: TextStyle(color: _K.sub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 10),
            Text('Verification link was sent to:',
                style: TextStyle(color: _K.sub, fontSize: 13)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _K.surfaceEl,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _K.border)),
              child: Text(email, style: const TextStyle(
                  color: _K.text, fontWeight: FontWeight.w600, fontSize: 13))),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _K.warn),
              const SizedBox(width: 6),
              Expanded(child: Text("Also check your Spam or Junk folder.",
                  style: TextStyle(color: _K.warn, fontSize: 12, height: 1.4))),
            ]),
          ],
        ),
        confirmLabel: 'OK',
        onConfirm: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _errorMessage = ''; _isLoading = true; });
    try {
      // Reverted back to your working initialization
      final googleSignIn = GoogleSignIn.instance;
      
      // CHANGED: Using dotenv here instead of the hardcoded string
      await googleSignIn.initialize(
          serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID']);
      
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      
      // If user just closed the picker, stop loading and return silently
      if (googleUser == null) { 
        if (mounted) setState(() { _isLoading = false; _errorMessage = ''; }); 
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken);
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      
      if (userCred.additionalUserInfo?.isNewUser == true) {
        String defaultUsername = userCred.user!.email?.split('@')[0] ??
            'user_${userCred.user!.uid.substring(0, 5)}';
        await _db.collection('users').doc(userCred.user!.uid).set(
            {'username': defaultUsername, 'email': userCred.user!.email});
      }
    } catch (e) {
      if (mounted) {
        // Double check for cancellation exceptions using the friendly message helper
        final err = _getFriendlyErrorMessage(e);
        if (err.isEmpty) {
          setState(() { _isLoading = false; _errorMessage = ''; });
        } else {
          setState(() { _errorMessage = err; _isLoading = false; });
        }
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    _fadeCtrl.reset();
    setState(() { _isLogin = !_isLogin; _errorMessage = ''; });
    _fadeCtrl.forward();
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _K.bg,
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
                    _buildHero(),
                    const SizedBox(height: 44),
                    // Only show banner if there is actually a non-empty error message
                    if (_errorMessage.isNotEmpty) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 20),
                    ],
                    FadeTransition(opacity: _fadeAnim, child: _buildForm()),
                    const Spacer(),
                    _buildSwitchRow(),
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

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text('Folio', style: TextStyle(
              color: _K.text, fontSize: 52,
              fontWeight: FontWeight.w300, letterSpacing: -2.5, height: 1)),
            const Text('.', style: TextStyle(
              color: Color(0xFF00C030), fontSize: 52,
              fontWeight: FontWeight.w700, height: 1)),
          ],
        ),
        const SizedBox(height: 6),
        const Text('YOUR PERSONAL LIBRARY', style: TextStyle(
          color: _K.muted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 3)),
        const SizedBox(height: 32),
        Text(
          _isLogin ? 'Welcome\nback.' : 'Create your\naccount.',
          style: const TextStyle(color: _K.text, fontSize: 32,
            fontWeight: FontWeight.w300, letterSpacing: -0.8, height: 1.15)),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Sign in to continue tracking your reading.'
              : 'Join Folio and start building your library.',
          style: const TextStyle(color: _K.sub, fontSize: 14,
            fontWeight: FontWeight.w400, height: 1.5)),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _K.dangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _K.dangerBdr)),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: _K.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(_errorMessage,
          style: const TextStyle(color: _K.danger, fontSize: 13))),
      ]));
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isLogin) ...[
          _buildField(
            controller: _usernameController,
            label: 'USERNAME',
            icon: Icons.alternate_email_rounded),
          const SizedBox(height: 14),
        ],
        _buildField(
          controller: _identifierController,
          label: _isLogin ? 'EMAIL OR USERNAME' : 'EMAIL ADDRESS',
          icon: Icons.mail_outline_rounded,
          keyboardType: _isLogin
              ? TextInputType.text
              : TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildField(
          controller: _passwordController,
          label: 'PASSWORD',
          icon: Icons.lock_outline_rounded,
          obscure: _obscurePwd,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePwd = !_obscurePwd),
            child: Icon(
              _obscurePwd
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _K.muted, size: 18))),
        const SizedBox(height: 28),
        if (_isLoading)
          const Center(child: SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(
                color: _K.accent, strokeWidth: 2.5)))
        else
          Column(children: [
            _buildSubmitButton(),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider(color: _K.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: const Text('OR', style: TextStyle(
                    color: _K.muted, fontSize: 11,
                    fontWeight: FontWeight.w700))),
              const Expanded(child: Divider(color: _K.border)),
            ]),
            const SizedBox(height: 20),
            _buildGoogleButton(),
          ]),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          color: _K.muted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.8)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _K.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _K.border)),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            autocorrect: false,
            style: const TextStyle(
                color: _K.text, fontSize: 15, fontWeight: FontWeight.w400),
            cursorColor: _K.accent,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(icon, color: _K.muted, size: 18)),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: suffixIcon)
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0)))),
      ]);
  }

  Widget _buildSubmitButton() => GestureDetector(
    onTap: _submitForm,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: _K.accent,
        borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_isLogin ? 'Sign In' : 'Create Account',
          style: const TextStyle(color: Colors.black, fontSize: 15,
            fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_rounded,
            color: Colors.black, size: 18),
      ])));

  Widget _buildGoogleButton() => GestureDetector(
    onTap: _signInWithGoogle,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: _K.surface,
        border: Border.all(color: _K.border),
        borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.network(
          'https://img.icons8.com/color/48/000000/google-logo.png',
          width: 20, height: 20,
          errorBuilder: (_, __, ___) => Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
            child: const Center(child: Text('G',
              style: TextStyle(color: Color(0xFF4285F4),
                fontWeight: FontWeight.w700, fontSize: 13)))),
        ),
        const SizedBox(width: 12),
        const Text('Continue with Google', style: TextStyle(
          color: _K.text, fontSize: 15, fontWeight: FontWeight.w500)),
      ])));

  Widget _buildSwitchRow() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        _isLogin ? "Don't have an account?" : 'Already have an account?',
        style: const TextStyle(color: _K.sub, fontSize: 13)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: _toggleMode,
        child: Text(_isLogin ? 'Register' : 'Sign in',
          style: const TextStyle(color: _K.accent,
            fontSize: 13, fontWeight: FontWeight.w600))),
    ]);
}

class _FolioDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, confirmLabel;
  final Widget content;
  final VoidCallback onConfirm;

  const _FolioDialog({
    required this.icon, required this.iconColor,
    required this.title, required this.confirmLabel,
    required this.content, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _K.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _K.border)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: iconColor.withOpacity(0.3))),
                child: Icon(icon, color: iconColor, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(
                color: _K.text, fontSize: 16,
                fontWeight: FontWeight.w700))),
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(height: 1, color: _K.border)),
            content,
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onConfirm,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: _K.accent,
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(confirmLabel,
                  style: const TextStyle(color: Colors.black,
                    fontSize: 14, fontWeight: FontWeight.w700))))),
          ],
        ),
      ),
    );
  }
}
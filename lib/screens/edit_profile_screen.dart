import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _K {
  static const accent    = Color(0xFF00C030);
  static const accentDim = Color(0xFF00C03018);
  static const danger    = Color(0xFFFF5555); 
}

class _P {
  final Color bg, surface, surfaceEl, border, textPrimary, textSecondary, textMuted;
  const _P({required this.bg, required this.surface, required this.surfaceEl,
    required this.border, required this.textPrimary,
    required this.textSecondary, required this.textMuted});
  factory _P.dark() => const _P(
    bg: Color(0xFF0F1117), surface: Color(0xFF1A1D27),
    surfaceEl: Color(0xFF22263A), border: Color(0xFF2A2F45),
    textPrimary: Color(0xFFEEEEEE), textSecondary: Color(0xFF8A8FA8),
    textMuted: Color(0xFF4A5068));
  factory _P.light() => const _P(
    bg: Color(0xFFF4F5F7), surface: Color(0xFFFFFFFF),
    surfaceEl: Color(0xFFEEF0F4), border: Color(0xFFDDE0E8),
    textPrimary: Color(0xFF0F1117), textSecondary: Color(0xFF5A6070),
    textMuted: Color(0xFF9AA0B0));
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  final String currentUsername;
  final String currentBio;
  final String currentPicUrl;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    required this.currentBio,
    required this.currentPicUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  bool _isSaving = false;
  
  File? _pickedImage;
  
  late final String _initialUsername;
  late final String _initialBio;

  @override
  void initState() {
    super.initState();
    _initialUsername = widget.currentUsername == 'Reader' ? '' : widget.currentUsername;
    _initialBio = widget.currentBio.contains('Add a bio') ? '' : widget.currentBio;
    
    _usernameCtrl = TextEditingController(text: _initialUsername);
    _bioCtrl = TextEditingController(text: _initialBio);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // ─── NEW PROTECTIVE FUNCTION ───
  Future<bool> _onWillPop() async {
    // 1. Check if the user actually changed anything
    final hasChanges = _pickedImage != null || 
                       _usernameCtrl.text != _initialUsername || 
                       _bioCtrl.text != _initialBio;

    // 2. If no changes, allow them to leave immediately
    if (!hasChanges) return true;

    // 3. If there ARE changes, show the warning
    final isDark = themeNotifier.value == ThemeMode.dark;
    final p = isDark ? _P.dark() : _P.light();

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel editing?', 
          style: TextStyle(color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to cancel? All unsaved changes will be lost.', 
          style: TextStyle(color: p.textSecondary, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // False = Don't leave
            child: Text('Keep Editing', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // True = Leave and discard
            child: const Text('Discard', style: TextStyle(color: _K.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return shouldCancel ?? false;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path); 
      });
    }
  }

  Future<String?> _uploadToStorage(String uid) async {
    if (_pickedImage == null) return widget.currentPicUrl; 

    try {
      final timeId = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_avatars')
          .child('${uid}_$timeId.jpg');

      await ref.putFile(_pickedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    
    try {
      String? finalImageUrl = await _uploadToStorage(user.uid);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'username': _usernameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'profileImageUrl': finalImageUrl ?? '',
      }, SetOptions(merge: true));
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final p = isDark ? _P.dark() : _P.light();

    // WRAP THE ENTIRE SCAFFOLD IN WILL POPSCOPE
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: _buildAppBar(p),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            _buildAvatarSection(p),
            const SizedBox(height: 28),

            _buildCard(p, 'PROFILE INFO', [
              _buildFieldRow(p, 'Username', _usernameCtrl,
                  icon: Icons.alternate_email_rounded, hint: 'Your display name'),
              _divider(p),
              _buildFieldRow(p, 'Bio', _bioCtrl,
                  icon: Icons.edit_note_rounded,
                  hint: 'Tell everyone about your reading taste…',
                  maxLines: 3),
            ]),
            const SizedBox(height: 28), 

            _isSaving
                ? const Center(child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        color: _K.accent, strokeWidth: 2.5)))
                : GestureDetector(
                    onTap: _saveProfile,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: _K.accent,
                        borderRadius: BorderRadius.circular(13)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              color: Colors.black, size: 20),
                          SizedBox(width: 8),
                          Text('Save Profile',
                            style: TextStyle(color: Colors.black,
                              fontSize: 15, fontWeight: FontWeight.w700)),
                        ]))),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(_P p) => AppBar(
    backgroundColor: p.bg, elevation: 0,
    surfaceTintColor: Colors.transparent,
    centerTitle: true,
    leading: GestureDetector(
      onTap: () async {
        // Trigger the exact same check when they manually tap the "X"
        if (await _onWillPop()) {
          if (mounted) Navigator.pop(context);
        }
      }, 
      child: Icon(Icons.close_rounded, color: p.textSecondary, size: 22)),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('EDIT PROFILE',
          style: TextStyle(color: p.textMuted, fontSize: 9,
            fontWeight: FontWeight.w700, letterSpacing: 2.5)),
        Row(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Folio', style: TextStyle(color: p.textPrimary,
              fontSize: 16, fontWeight: FontWeight.w300, letterSpacing: -0.6)),
            const Text('.', style: TextStyle(color: _K.accent,
              fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
      ],
    ),
  );

  Widget _buildAvatarSection(_P p) {
    final hasOldUrl = widget.currentPicUrl.isNotEmpty;
    final hasNewPickedImage = _pickedImage != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        GestureDetector(
          onTap: _pickImage, 
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 104, height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _K.accent.withOpacity((hasOldUrl || hasNewPickedImage) ? 0.4 : 0.15),
                    width: 2)),
            ),
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.surfaceEl,
                image: hasNewPickedImage 
                    ? DecorationImage(
                        image: FileImage(_pickedImage!), 
                        fit: BoxFit.cover)
                    : (hasOldUrl 
                        ? DecorationImage(
                            image: NetworkImage(widget.currentPicUrl), 
                            fit: BoxFit.cover) 
                        : null),
              ),
              child: (!hasOldUrl && !hasNewPickedImage) 
                  ? Icon(Icons.person_rounded, color: p.textMuted, size: 44) 
                  : null,
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _K.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.bg, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
          _usernameCtrl.text.isNotEmpty
              ? _usernameCtrl.text
              : 'Your Name',
          style: TextStyle(color: p.textPrimary, fontSize: 16,
              fontWeight: FontWeight.w600, letterSpacing: -0.3)),
        const SizedBox(height: 3),
        Text('Folio reader',
          style: TextStyle(color: p.textMuted, fontSize: 12)),
      ]),
    );
  }

  Widget _buildCard(_P p, String label, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(label, style: TextStyle(color: p.textMuted,
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2))),
      Container(
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: p.border)),
        child: Column(children: children)),
    ]);

  Widget _divider(_P p) => Container(
    margin: const EdgeInsets.only(left: 16),
    height: 1, color: p.border.withOpacity(0.6));

  Widget _buildFieldRow(_P p, String label, TextEditingController ctrl,
      {IconData? icon, String hint = '', int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 17, color: p.textMuted)),
          const SizedBox(width: 12),
        ],
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: p.textMuted, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              maxLines: maxLines,
              style: TextStyle(color: p.textPrimary, fontSize: 14),
              cursorColor: _K.accent,
              onChanged: (val) {
                if (label == 'Username') {
                  setState(() {});
                }
              },
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.textMuted.withOpacity(0.5),
                    fontSize: 13),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: _K.accent.withOpacity(0.5), width: 1)),
              )),
          ])),
      ]));
  }
}
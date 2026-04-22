import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart'; 
import '../../widgets/primary_button.dart';   

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  XFile? _imageFile; Uint8List? _imageBytes; String? _avatarUrl;

  @override
  void initState() { super.initState(); _loadUserData(); }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() { _emailController.text = user.email ?? ''; _nameController.text = user.userMetadata?['full_name'] ?? ''; _avatarUrl = user.userMetadata?['avatar_url']; });
    try { final data = await _supabase.from('profiles').select('full_name, avatar_url').eq('id', user.id).single(); if (mounted) setState(() { _nameController.text = data['full_name'] ?? ''; _avatarUrl = data['avatar_url']; }); } catch (e) { debugPrint('Gagal sync data: $e'); }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (pickedFile != null) { final bytes = await pickedFile.readAsBytes(); setState(() { _imageFile = pickedFile; _imageBytes = bytes; }); }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageBytes == null || _imageFile == null) return _avatarUrl;
    try { final fileExt = _imageFile!.name.split('.').last; final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt'; await _supabase.storage.from('avatars').uploadBinary(fileName, _imageBytes!, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg')); return _supabase.storage.from('avatars').getPublicUrl(fileName); } catch (e) { debugPrint("Gagal upload foto: $e"); return _avatarUrl; }
  }

  Future<void> _updateProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';
      final String? newAvatarUrl = await _uploadImage(user.id);
      if (!mounted) return;
      await _supabase.from('profiles').update({'full_name': _nameController.text.trim(), 'avatar_url': newAvatarUrl, 'updated_at': DateTime.now().toIso8601String()}).eq('id', user.id);
      final UserResponse response = await _supabase.auth.updateUser(UserAttributes(data: {'full_name': _nameController.text.trim(), 'avatar_url': newAvatarUrl}));
      if (response.user != null) await _supabase.auth.refreshSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui!')));
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red)); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    // [FIX] Web mode
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Edit Profil", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              GestureDetector(onTap: _pickImage, child: Stack(children: [
                CircleAvatar(radius: 50, backgroundColor: Colors.grey[200],
                  backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : (_avatarUrl != null && _avatarUrl!.isNotEmpty) ? NetworkImage(_avatarUrl!) : const NetworkImage('https://i.pravatar.cc/150?img=12') as ImageProvider),
                Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.camera_alt, color: Colors.white, size: 18))),
              ])),
              const SizedBox(height: 10),
              const Text("Ketuk foto untuk mengubah", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 30),
              CustomTextField(label: "Nama Lengkap", hint: "Masukkan nama", controller: _nameController), const SizedBox(height: 20),
              IgnorePointer(child: Opacity(opacity: 0.5, child: CustomTextField(label: "Email", hint: "Email", controller: _emailController))),
              const SizedBox(height: 40),
              PrimaryButton(text: "SIMPAN PERUBAHAN", isLoading: _isLoading, onPressed: _updateProfile),
            ]),
          ),
        ),
      ),
    );
  }
}
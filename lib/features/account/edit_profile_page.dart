import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
// [TAMBAHAN TAHAP 5] Import Accurate Service untuk Tembak Balik
import '../../admin/accurate/accurate_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase = Supabase.instance.client;
  // [TAMBAHAN TAHAP 5] Instance Accurate Service
  final _accurateService = AccurateService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  // [TAMBAHAN] Controller untuk Password Baru
  final _passwordController = TextEditingController(); 

  bool _isLoading = false;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _avatarUrl;

  // [TAMBAHAN TAHAP 5] Variabel untuk menampung ID Pelanggan
  String? _accurateCustomerId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose(); // Dispose password controller
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() {
      _emailController.text = user.email ?? '';
      _nameController.text = user.userMetadata?['full_name'] ?? '';
      _avatarUrl = user.userMetadata?['avatar_url'];
    });
    try {
      final data = await _supabase
          .from('profiles')
          .select('full_name, avatar_url, phone, accurate_customer_id') 
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone'] ?? ''; 
          _avatarUrl = data['avatar_url'];
          _accurateCustomerId = data['accurate_customer_id']; 
        });
      }
    } catch (e) {
      debugPrint('Gagal sync data: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 600, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageBytes == null || _imageFile == null) return _avatarUrl;
    try {
      final fileExt = _imageFile!.name.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _supabase.storage.from('avatars').uploadBinary(
          fileName, _imageBytes!,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
      return _supabase.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Gagal upload foto: $e");
      return _avatarUrl;
    }
  }

  Future<void> _updateProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      // =========================================================
      // [TAMBAHAN] SIMPAN PASSWORD BARU JIKA DIISI
      // =========================================================
      if (_passwordController.text.isNotEmpty) {
        if (_passwordController.text.length < 6) {
          throw 'Password minimal 6 karakter!';
        }
        // Update password di sistem Auth Supabase
        await _supabase.auth.updateUser(
          UserAttributes(password: _passwordController.text),
        );
      }
      
      final String? newAvatarUrl = await _uploadImage(user.id);
      final String fullName = _nameController.text.trim();
      final String phone = _phoneController.text.trim();

      if (!mounted) return;

      // 1. UPDATE DATA KE SUPABASE & BUKA GEMBOK SATPAM BIODATA
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'avatar_url': newAvatarUrl,
        'is_profile_completed': true, 
        'approval_status': 'APPROVED', 
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', user.id);

      final UserResponse response = await _supabase.auth.updateUser(
          UserAttributes(data: {'full_name': fullName, 'avatar_url': newAvatarUrl}));
      if (response.user != null) await _supabase.auth.refreshSession();

      // 2. TEMBAK BALIK KE ACCURATE JIKA PUNYA ID!
      if (_accurateCustomerId != null && _accurateCustomerId!.isNotEmpty) {
        final bool isAccurateUpdated = await _accurateService.updateCustomerToAccurate(
          customerId: _accurateCustomerId!,
          name: fullName,
          email: _emailController.text.trim(),
          phone: phone,
        );
        
        if (isAccurateUpdated) {
          debugPrint('Data pelanggan berhasil di-update di Accurate Deus Code!');
        } else {
          debugPrint('Peringatan: Gagal tembak balik ke Accurate.');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui!')));
      
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          title: const Text("Edit Profil", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              GestureDetector(
                  onTap: _pickImage,
                  child: Stack(children: [
                    CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageBytes != null
                            ? MemoryImage(_imageBytes!)
                            : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                ? NetworkImage(_avatarUrl!)
                                : const AssetImage('assets/images/logo.png') // Diganti pakai logo lokal menghindari error pravatar
                                    as ImageProvider),
                    Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 18))),
                  ])),
              const SizedBox(height: 10),
              const Text("Ketuk foto untuk mengubah",
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 30),

              if (_accurateCustomerId != null && _accurateCustomerId!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Terkoneksi dengan Accurate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                            Text('ID Pelanggan: $_accurateCustomerId', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF064E3B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              CustomTextField(
                  label: "Nama Lengkap",
                  hint: "Masukkan nama",
                  controller: _nameController),
              const SizedBox(height: 20),
              
              CustomTextField(
                  label: "Nomor Handphone",
                  hint: "Contoh: 081234567890",
                  controller: _phoneController,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 20),

              // =======================================================
              // [TAMBAHAN] KOLOM INPUT PASSWORD BARU
              // =======================================================
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buat Password Baru (Khusus Akun Accurate)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: "Biarkan kosong jika tidak ingin mengubah password",
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey[400]),
                      filled: true, 
                      fillColor: const Color(0xFFF8F9FC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              IgnorePointer(
                  child: Opacity(
                      opacity: 0.5,
                      child: CustomTextField(
                          label: "Email",
                          hint: "Email",
                          controller: _emailController))),
              const SizedBox(height: 40),
              PrimaryButton(
                  text: "SIMPAN PERUBAEM",
                  isLoading: _isLoading,
                  onPressed: _updateProfile),
            ]),
          ),
        ),
      ),
    );
  }
}
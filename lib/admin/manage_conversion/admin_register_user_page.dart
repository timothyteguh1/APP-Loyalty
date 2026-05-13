import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../admin_supabase.dart'; // Sesuaikan path ini dengan project Anda

class AdminRegisterUserPage extends StatefulWidget {
  const AdminRegisterUserPage({super.key});

  @override
  State<AdminRegisterUserPage> createState() => _AdminRegisterUserPageState();
}

class _AdminRegisterUserPageState extends State<AdminRegisterUserPage> {
  // Menggunakan AdminSupabase agar bisa create user tanpa menimpa session Admin saat ini
  final _admin = AdminSupabase.client;

  // ── Controllers ──
  final _emailController        = TextEditingController();
  final _passwordController     = TextEditingController();

  final _accurateIdController   = TextEditingController();
  final _namaTokoController     = TextEditingController();
  final _picNameController      = TextEditingController();
  final _phoneController        = TextEditingController();
  final _ktpNumberController    = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _domisiliController     = TextEditingController();

  bool       _isLoading = false;
  XFile?     _imageFile;
  Uint8List? _imageBytes;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _accurateIdController.dispose();
    _namaTokoController.dispose();
    _picNameController.dispose();
    _phoneController.dispose();
    _ktpNumberController.dispose();
    _storeAddressController.dispose();
    _domisiliController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // FOTO PROFIL (AVATAR)
  // ─────────────────────────────────────────────
  Future<void> _pickProfileImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 600, imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() { _imageFile = picked; _imageBytes = bytes; });
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_imageBytes == null || _imageFile == null) return null;
    try {
      final ext      = _imageFile!.name.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _admin.storage.from('avatars').uploadBinary(
        fileName, _imageBytes!,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _admin.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error upload image: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // VALIDASI
  // ─────────────────────────────────────────────
  bool _validate() {
    if (_emailController.text.trim().isEmpty)         return _showSnackError('Email wajib diisi');
    if (_passwordController.text.trim().length < 6)   return _showSnackError('Password minimal 6 karakter');
    if (_accurateIdController.text.trim().isEmpty)    return _showSnackError('No. Pelanggan Accurate wajib diisi');
    if (_namaTokoController.text.trim().isEmpty)      return _showSnackError('Nama Toko wajib diisi');
    if (_picNameController.text.trim().isEmpty)       return _showSnackError('Nama PIC wajib diisi');
    if (_storeAddressController.text.trim().isEmpty)  return _showSnackError('Alamat Toko wajib diisi');
    if (_domisiliController.text.trim().isEmpty)      return _showSnackError('Kota / Domisili wajib diisi');
    if (_phoneController.text.trim().isEmpty)         return _showSnackError('Nomor HP wajib diisi');
    if (_ktpNumberController.text.trim().isEmpty)     return _showSnackError('Nomor KTP wajib diisi');
    if (_ktpNumberController.text.trim().length < 16) return _showSnackError('Nomor KTP harus 16 digit');
    return true;
  }

  bool _showSnackError(String msg) {
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(width: 24, height: 24,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.warning_rounded, color: Colors.white, size: 14)),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
    return false;
  }

  // ─────────────────────────────────────────────
  // SIMPAN (REGISTER)
  // ─────────────────────────────────────────────
  Future<void> _registerUser() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      final email      = _emailController.text.trim();
      final password   = _passwordController.text.trim();
      // PERUBAHAN: Normalisasi ke UPPERCASE agar C.0001 dan c.0001 dianggap sama
      final accurateId = _accurateIdController.text.trim().toUpperCase();
      final namaToko   = _namaTokoController.text.trim();
      final picName    = _picNameController.text.trim();
      final phone      = _phoneController.text.trim();
      final nik        = _ktpNumberController.text.trim();
      final address    = _storeAddressController.text.trim();
      final domisili   = _domisiliController.text.trim();

      // 1. CREATE USER AUTH
      final res = await _admin.auth.admin.createUser(AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {
          'full_name': namaToko,
        }
      ));

      if (res.user == null) throw 'Gagal membuat user auth';
      final newUserId = res.user!.id;

      // 2. UPLOAD AVATAR JIKA ADA
      final String? avatarUrl = await _uploadProfileImage(newUserId);

      // 3. INSERT ATAU UPDATE DATA KE TABEL PROFILES
      await _admin.from('profiles').upsert({
        'id': newUserId,
        // PERUBAHAN: simpan No. Pelanggan (C.0001) UPPERCASE, bukan internal ID angka
        'accurate_customer_id': accurateId,
        'full_name': namaToko,
        'pic_name': picName,
        'phone': phone,
        'ktp_number': nik,
        'store_address': address,
        'domisili': domisili,
        'avatar_url': avatarUrl,
        'is_profile_completed': true,
        'approval_status': 'APPROVED',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Pengguna berhasil didaftarkan!', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context);

    } on AuthException catch (e) {
      if (mounted) _showSnackError('Auth Error: ${e.message}');
    } catch (e) {
      if (mounted) _showSnackError('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  // BUILD UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Registrasi Pengguna Baru",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Banner Informasi
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'Anda mendaftarkan pengguna baru sebagai Admin. Status toko otomatis akan menjadi APPROVED.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Foto Profil ──────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: Stack(children: [
                    CircleAvatar(
                      radius: 50, backgroundColor: Colors.grey[200],
                      backgroundImage: _imageBytes != null
                          ? MemoryImage(_imageBytes!)
                          : const AssetImage('assets/images/logo.png') as ImageProvider,
                    ),
                    Positioned(bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB71C1C),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        )),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: Text("Ketuk untuk menambah foto",
                  style: TextStyle(fontSize: 12, color: Colors.grey))),
              const SizedBox(height: 24),

              // ════════════════════════════════════════════════
              // SECTION: AKUN LOGIN
              // ════════════════════════════════════════════════
              _sectionHeader(Icons.security_rounded, 'Akun Login'),
              const SizedBox(height: 16),

              CustomTextField(label: "Email", hint: "Contoh: toko@gmail.com", controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),

              CustomTextField(label: "Password", hint: "Minimal 6 karakter", controller: _passwordController, isPassword: true),
              const SizedBox(height: 28),

              // ════════════════════════════════════════════════
              // SECTION: DATA TOKO
              // ════════════════════════════════════════════════
              _sectionHeader(Icons.store_rounded, 'Data Toko'),
              const SizedBox(height: 16),

              // PERUBAHAN: hint diubah ke format No. Pelanggan (C.0001)
              CustomTextField(
                label: "No. Pelanggan Accurate",
                hint: "Contoh: C.0001",
                controller: _accurateIdController,
              ),
              const SizedBox(height: 16),

              CustomTextField(label: "Nama Toko", hint: "Contoh: Toko Jaya Motor", controller: _namaTokoController),
              const SizedBox(height: 16),

              CustomTextField(label: "Nama PIC (Penanggung Jawab)", hint: "Contoh: Budi Santoso", controller: _picNameController),
              const SizedBox(height: 16),

              CustomTextField(label: "Alamat Toko", hint: "Jl. Raya No. 123, Surabaya", controller: _storeAddressController),
              const SizedBox(height: 16),

              CustomTextField(label: "Kota / Domisili", hint: "Contoh: Surabaya", controller: _domisiliController),
              const SizedBox(height: 28),

              // ════════════════════════════════════════════════
              // SECTION: DATA PRIBADI
              // ════════════════════════════════════════════════
              _sectionHeader(Icons.badge_rounded, 'Data Pribadi'),
              const SizedBox(height: 16),

              CustomTextField(label: "Nomor HP", hint: "Contoh: 08123456789",
                  controller: _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              CustomTextField(label: "Nomor KTP", hint: "16 digit nomor KTP",
                  controller: _ktpNumberController, keyboardType: TextInputType.number),
              const SizedBox(height: 40),

              PrimaryButton(text: "SIMPAN PENGGUNA BARU", isLoading: _isLoading, onPressed: _registerUser),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: const Color(0xFFB71C1C)),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    const SizedBox(width: 8),
    Expanded(child: Divider(color: Colors.grey[200])),
  ]);
}
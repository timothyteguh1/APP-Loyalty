import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../admin/accurate/accurate_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase        = Supabase.instance.client;
  final _accurateService = AccurateService();

  // ── Controllers ──
  final _namaTokoController     = TextEditingController();
  final _picNameController      = TextEditingController();
  final _emailController        = TextEditingController();
  final _phoneController        = TextEditingController();
  final _ktpNumberController    = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _domisiliController     = TextEditingController();

  bool       _isLoading = false;
  XFile?     _imageFile;
  Uint8List? _imageBytes;
  String?    _avatarUrl;
  String?    _accurateCustomerId;

  // Simpan approval_status existing agar tidak ditimpa sembarangan
  String _existingApprovalStatus = 'PENDING';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _namaTokoController.dispose();
    _picNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ktpNumberController.dispose();
    _storeAddressController.dispose();
    _domisiliController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Email dari auth session (pasti ada)
    setState(() => _emailController.text = user.email ?? '');

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (!mounted) return;
      setState(() {
        _namaTokoController.text     = data['full_name']      ?? '';
        _picNameController.text      = data['pic_name']       ?? '';
        _phoneController.text        = data['phone']          ?? '';

        // [FIX] Nama kolom yang benar di DB adalah 'ktp_number', bukan 'nik'
        _ktpNumberController.text    = data['ktp_number']     ?? '';

        // [FIX] Nama kolom yang benar di DB adalah 'store_address', bukan 'address'
        _storeAddressController.text = data['store_address']  ?? '';

        _domisiliController.text     = data['domisili']       ?? '';
        _avatarUrl                   = data['avatar_url'];
        _accurateCustomerId          = data['accurate_customer_id'];

        // Simpan approval_status yang sudah ada (APPROVED untuk user Accurate)
        _existingApprovalStatus      = data['approval_status'] ?? 'PENDING';
      });
    } catch (e) {
      debugPrint('Gagal load profil: $e');
    }
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
    if (_imageBytes == null || _imageFile == null) return _avatarUrl;
    try {
      final ext      = _imageFile!.name.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('avatars').uploadBinary(
        fileName, _imageBytes!,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _supabase.storage.from('avatars').getPublicUrl(fileName);
    } catch (_) { return _avatarUrl; }
  }

  // ─────────────────────────────────────────────
  // VALIDASI
  // ─────────────────────────────────────────────
  bool _validate() {
    if (_namaTokoController.text.trim().isEmpty)     return _showSnackError('Nama Toko wajib diisi');
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
  // SIMPAN
  // ─────────────────────────────────────────────
  Future<void> _updateProfile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      final String? newAvatarUrl = await _uploadProfileImage(user.id);

      final namaToko = _namaTokoController.text.trim();
      final picName  = _picNameController.text.trim();
      final phone    = _phoneController.text.trim();
      final nik      = _ktpNumberController.text.trim();
      final address  = _storeAddressController.text.trim();
      final domisili = _domisiliController.text.trim();
      final email    = _emailController.text.trim();

      // ============================================================
      // [FIX PENTING] Tentukan approval_status dengan benar:
      //
      // - User dari Accurate → sudah APPROVED dari awal (set oleh admin)
      //   Setelah isi profil, tetap APPROVED → langsung masuk HomePage
      //
      // - User mandiri → sudah PENDING dari signUp
      //   Setelah isi profil (edit profile tidak dipakai user mandiri,
      //   tapi kalau terjadi), tetap PENDING → ke PendingPage
      //
      // Jadi kita TIDAK boleh hardcode 'APPROVED' di sini.
      // Gunakan _existingApprovalStatus yang sudah diload dari DB.
      // ============================================================
      final String finalApprovalStatus = _existingApprovalStatus;

      // 1. UPDATE PROFILES
      await _supabase.from('profiles').update({
        'full_name'           : namaToko,
        'pic_name'            : picName,
        'phone'               : phone,
        'ktp_number'          : nik,       // [FIX] kolom yang benar
        'store_address'       : address,   // [FIX] kolom yang benar
        'domisili'            : domisili,
        'avatar_url'          : newAvatarUrl,
        'is_profile_completed': true,
        'approval_status'     : finalApprovalStatus, // [FIX] pakai status existing
        'updated_at'          : DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // 2. UPDATE AUTH METADATA
      await _supabase.auth.updateUser(UserAttributes(
          data: {'full_name': namaToko, 'avatar_url': newAvatarUrl}));

      // 3. SYNC KE ACCURATE (hanya kalau user dari Accurate)
      // PERUBAHAN: parameter 'customerId' → 'customerNo' (sekarang berisi C.0001)
      if (_accurateCustomerId != null && _accurateCustomerId!.isNotEmpty) {
        await _accurateService.updateCustomerToAccurate(
          customerNo: _accurateCustomerId!, name: namaToko,
          email: email, phone: phone, address: address,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Profil berhasil disimpan!', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      // Kembali ke AuthGate — akan routing otomatis sesuai status
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);

    } catch (e) {
      if (mounted) _showSnackError('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Langkah 2: Data Toko & Biodata",
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

              // Info banner sesuai tipe user
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    _existingApprovalStatus == 'APPROVED'
                        ? 'Akun Anda sudah disetujui. Lengkapi data toko untuk mulai menggunakan aplikasi.'
                        : 'Silakan lengkapi data toko dan biodata. Data akan diverifikasi oleh admin.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), height: 1.5),
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
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!) as ImageProvider
                              : const AssetImage('assets/images/logo.png'),
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
              const Center(child: Text("Ketuk foto untuk mengubah",
                  style: TextStyle(fontSize: 12, color: Colors.grey))),
              const SizedBox(height: 24),

              // ── Badge Accurate ───────────────────────────────
              if (_accurateCustomerId != null && _accurateCustomerId!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Terkoneksi dengan Accurate',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      Text('No. Pelanggan: $_accurateCustomerId',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF064E3B))),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
              ],

              // ════════════════════════════════════════════════
              // SECTION: DATA TOKO
              // ════════════════════════════════════════════════
              _sectionHeader(Icons.store_rounded, 'Data Toko'),
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
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'Nomor KTP digunakan untuk proses verifikasi identitas saat Anda melakukan klaim hadiah.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), height: 1.5),
                  )),
                ]),
              ),
              const SizedBox(height: 20),

              // Email read-only
              IgnorePointer(
                child: Opacity(
                  opacity: 0.5,
                  child: CustomTextField(label: "Email", hint: "Email", controller: _emailController),
                ),
              ),
              const SizedBox(height: 40),

              PrimaryButton(text: "SIMPAN & SELESAI", isLoading: _isLoading, onPressed: _updateProfile),
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
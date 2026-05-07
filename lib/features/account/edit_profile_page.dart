import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  // ── Controllers — nama persis sama dengan RegisterPage ──
  final _namaTokoController     = TextEditingController(); // → full_name di DB
  final _picNameController      = TextEditingController(); // → pic_name di DB
  final _emailController        = TextEditingController();
  final _phoneController        = TextEditingController();
  final _ktpNumberController    = TextEditingController(); // → nik di DB
  final _storeAddressController = TextEditingController(); // → address di DB

  // Domisili — identik dengan RegisterPage
  String? _selectedDomisili;
  final List<String> _listDomisili = [
    'Surabaya', 'Sidoarjo', 'Gresik', 'Malang',
    'Jakarta', 'Bandung', 'Semarang', 'Lainnya',
  ];

  // Foto profil
  bool       _isLoading = false;
  XFile?     _imageFile;
  Uint8List? _imageBytes;
  String?    _avatarUrl;
  String?    _accurateCustomerId;

  // Foto KTP — identik dengan RegisterPage Step 3
  XFile?     _ktpFile;
  Uint8List? _ktpBytes;
  String?    _ktpImageUrl; // URL tersimpan di DB

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
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _emailController.text = user.email ?? '');

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (!mounted) return;
      setState(() {
        _namaTokoController.text     = data['full_name']   ?? '';
        _picNameController.text      = data['pic_name']    ?? '';
        _phoneController.text        = data['phone']       ?? '';
        _ktpNumberController.text    = data['nik']         ?? '';
        _storeAddressController.text = data['address']     ?? '';
        _avatarUrl                   = data['avatar_url'];
        _ktpImageUrl                 = data['ktp_image_url'];
        _accurateCustomerId          = data['accurate_customer_id'];

        final dbDomisili = data['domisili'] as String?;
        _selectedDomisili = _listDomisili.contains(dbDomisili) ? dbDomisili : null;
      });
    } catch (e) {
      debugPrint('Gagal load profil: $e');
    }
  }

  // ─────────────────────────────────────────────
  // FOTO PROFIL
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
  // FOTO KTP — identik dengan RegisterPage
  // ─────────────────────────────────────────────
  bool get _isCameraAvailable {
    if (kIsWeb) return false;
    try { return Platform.isAndroid || Platform.isIOS; } catch (_) { return false; }
  }

  Future<void> _pickKtpImage() async {
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _ktpFile = picked; _ktpBytes = bytes; });
      }
    } catch (e) { _showSnackError('Gagal memilih gambar: $e'); }
  }

  Future<void> _takeKtpPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1200, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _ktpFile = picked; _ktpBytes = bytes; });
      }
    } catch (_) { _showSnackError('Kamera tidak tersedia. Gunakan Galeri.'); }
  }

  void _showImageSourceDialog() {
    if (!_isCameraAvailable) { _pickKtpImage(); return; }
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Pilih Sumber Foto',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _sourceButton(Icons.photo_library_rounded, 'Galeri',
                () { Navigator.pop(ctx); _pickKtpImage(); })),
            const SizedBox(width: 12),
            Expanded(child: _sourceButton(Icons.camera_alt_rounded, 'Kamera',
                () { Navigator.pop(ctx); _takeKtpPhoto(); })),
          ]),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _sourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
            color: const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!)),
        child: Column(children: [
          Container(width: 48, height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, size: 24, color: const Color(0xFFB71C1C))),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

 Future<String?> _uploadKtpImage(String userId) async {
    if (_ktpBytes == null || _ktpFile == null) return _ktpImageUrl;
    try {
      final ext      = _ktpFile!.name.split('.').last;
      final fileName = '$userId-ktp-${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      // [UPDATE] Ganti 'ktp-images' menjadi 'upsol-assets'
      await _supabase.storage.from('upsol-assets').uploadBinary(
        fileName, _ktpBytes!,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      
      // [UPDATE] Ganti 'ktp-images' menjadi 'upsol-assets'
      return _supabase.storage.from('upsol-assets').getPublicUrl(fileName);
    } catch (_) { 
      return _ktpImageUrl; 
    }
  }

  // ─────────────────────────────────────────────
  // VALIDASI
  // ─────────────────────────────────────────────
  bool _validate() {
    if (_namaTokoController.text.trim().isEmpty)     return _showSnackError('Nama Toko wajib diisi');
    if (_picNameController.text.trim().isEmpty)       return _showSnackError('Nama PIC wajib diisi');
    if (_storeAddressController.text.trim().isEmpty)  return _showSnackError('Alamat Toko wajib diisi');
    if (_selectedDomisili == null)                    return _showSnackError('Domisili wajib dipilih');
    if (_phoneController.text.trim().isEmpty)         return _showSnackError('Nomor HP wajib diisi');
    if (_ktpNumberController.text.trim().isEmpty)     return _showSnackError('Nomor KTP wajib diisi');
    if (_ktpNumberController.text.trim().length < 16) return _showSnackError('Nomor KTP harus 16 digit');
    // Foto KTP wajib ada (baru dipilih ATAU sudah ada di DB)
    if (_ktpBytes == null && (_ktpImageUrl == null || _ktpImageUrl!.isEmpty)) {
      return _showSnackError('Foto KTP wajib diunggah');
    }
    return true;
  }

  bool _showSnackError(String msg) {
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(width: 24, height: 24,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6)),
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
      final String? newKtpUrl    = await _uploadKtpImage(user.id);

      final namaToko = _namaTokoController.text.trim();
      final picName  = _picNameController.text.trim();
      final phone    = _phoneController.text.trim();
      final nik      = _ktpNumberController.text.trim();
      final address  = _storeAddressController.text.trim();
      final email    = _emailController.text.trim();

      // 1. UPDATE PROFILES
      await _supabase.from('profiles').update({
        'full_name'           : namaToko,
        'pic_name'            : picName,
        'phone'               : phone,
        'ktp_number'          : nik,
        'store_address'       : address,
        'domisili'            : _selectedDomisili,
        'avatar_url'          : newAvatarUrl,
        'ktp_image_url'       : newKtpUrl,
        'is_profile_completed': true,
        'approval_status'     : 'APPROVED',
        'updated_at'          : DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // 2. UPDATE AUTH METADATA
      await _supabase.auth.updateUser(UserAttributes(
          data: {'full_name': namaToko, 'avatar_url': newAvatarUrl}));

      // 3. SYNC KE ACCURATE
      if (_accurateCustomerId != null && _accurateCustomerId!.isNotEmpty) {
        await _accurateService.updateCustomerToAccurate(
          customerId: _accurateCustomerId!, name: namaToko,
          email: email, phone: phone, address: address,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')));
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
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
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              const Text("Silakan lengkapi data toko dan biodata untuk menyelesaikan registrasi.",
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                          decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2)),
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
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5))),
                  child: Row(children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Terkoneksi dengan Accurate',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      Text('ID Pelanggan: $_accurateCustomerId',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF064E3B))),
                    ])),
                  ]),
                ),
                const SizedBox(height: 20),
              ],

              // ════════════════════════════════════════════════
              // SECTION: DATA TOKO  (= Step 2 Register)
              // ════════════════════════════════════════════════
              _sectionHeader(Icons.store_rounded, 'Data Toko'),
              const SizedBox(height: 16),

              CustomTextField(label: "Nama Toko", hint: "Contoh: Toko Jaya Motor",
                  controller: _namaTokoController),
              const SizedBox(height: 16),

              CustomTextField(label: "Nama PIC (Penanggung Jawab)",
                  hint: "Contoh: Budi Santoso", controller: _picNameController),
              const SizedBox(height: 16),

              CustomTextField(label: "Alamat Toko",
                  hint: "Jl. Raya No. 123, Surabaya",
                  controller: _storeAddressController),
              const SizedBox(height: 16),

              const Text("Domisili *",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: _inputDecoration(hint: 'Pilih Kota', prefixIcon: Icons.map_outlined),
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                value: _selectedDomisili,
                items: _listDomisili
                    .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedDomisili = v),
              ),
              const SizedBox(height: 28),

              // ════════════════════════════════════════════════
              // SECTION: DATA PRIBADI  (= Step 1 & 3 Register)
              // ════════════════════════════════════════════════
              _sectionHeader(Icons.badge_rounded, 'Data Pribadi'),
              const SizedBox(height: 16),

              CustomTextField(label: "Nomor HP", hint: "Contoh: 08123456789",
                  controller: _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),

              CustomTextField(label: "Nomor KTP", hint: "16 digit nomor KTP",
                  controller: _ktpNumberController, keyboardType: TextInputType.number),
              const SizedBox(height: 16),

              // ── FOTO KTP — identik dengan Register Step 3 ───
              const Text("Foto KTP *",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity, height: 180,
                  decoration: BoxDecoration(
                    color: _hasKtpPhoto ? Colors.transparent : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasKtpPhoto ? const Color(0xFF10B981) : Colors.grey[300]!,
                      width: _hasKtpPhoto ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_hasKtpPhoto ? 14 : 15),
                    child: _buildKtpPreview(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildTipsCard(),
              const SizedBox(height: 20),

              // Email read-only
              IgnorePointer(
                child: Opacity(opacity: 0.5,
                    child: CustomTextField(label: "Email", hint: "Email",
                        controller: _emailController)),
              ),
              const SizedBox(height: 40),

              PrimaryButton(text: "SIMPAN & SELESAI",
                  isLoading: _isLoading, onPressed: _updateProfile),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }

  bool get _hasKtpPhoto =>
      _ktpBytes != null || (_ktpImageUrl != null && _ktpImageUrl!.isNotEmpty);

  Widget _buildKtpPreview() {
    // File baru dipilih dari galeri/kamera
    if (_ktpBytes != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.memory(_ktpBytes!, fit: BoxFit.cover),
        Positioned(top: 10, right: 10,
            child: Container(width: 32, height: 32,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20))),
        Positioned(bottom: 10, right: 10, child: _gantiLabel()),
      ]);
    }
    // URL yang sudah tersimpan di DB
    if (_ktpImageUrl != null && _ktpImageUrl!.isNotEmpty) {
      return Stack(fit: StackFit.expand, children: [
        Image.network(_ktpImageUrl!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _ktpEmptyWidget()),
        Positioned(top: 10, right: 10,
            child: Container(width: 32, height: 32,
                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20))),
        Positioned(bottom: 10, right: 10, child: _gantiLabel()),
      ]);
    }
    return _ktpEmptyWidget();
  }

  Widget _gantiLabel() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.edit_rounded, color: Colors.white, size: 14),
      SizedBox(width: 4),
      Text('Ganti', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _ktpEmptyWidget() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 56, height: 56,
        decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_a_photo_rounded, size: 28, color: Color(0xFFB71C1C))),
    const SizedBox(height: 12),
    const Text('Tap untuk unggah foto KTP',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
    const SizedBox(height: 4),
    Text('Dari galeri atau kamera', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
  ]);

  Widget _buildTipsCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.tips_and_updates_rounded, size: 14, color: Color(0xFFB71C1C))),
        const SizedBox(width: 10),
        const Text('Tips Foto KTP',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB71C1C))),
      ]),
      const SizedBox(height: 12),
      _tipItem('Pastikan foto tidak buram / blur'),
      _tipItem('Seluruh bagian KTP terlihat jelas'),
      _tipItem('Hindari pantulan cahaya (glare)'),
    ]),
  );

  Widget _tipItem(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    ]),
  );

  Widget _sectionHeader(IconData icon, String title) => Row(children: [
    Container(width: 32, height: 32,
        decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: const Color(0xFFB71C1C))),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    const SizedBox(width: 8),
    Expanded(child: Divider(color: Colors.grey[200])),
  ]);

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) =>
      InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey[400]),
        filled: true, fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
      );
}
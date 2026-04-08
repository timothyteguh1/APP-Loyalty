import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart';
import '../admin_supabase.dart';

class AdminRegisterUserPage extends StatefulWidget {
  const AdminRegisterUserPage({super.key});

  @override
  State<AdminRegisterUserPage> createState() => _AdminRegisterUserPageState();
}

class _AdminRegisterUserPageState extends State<AdminRegisterUserPage> {
  final _admin = AdminSupabase.client;
  bool _isSaving = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _namaTokoCtrl = TextEditingController();
  final _picNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _selectedDomisili;
  bool _autoApprove = true;

  final _domList = ['Surabaya', 'Sidoarjo', 'Gresik', 'Malang', 'Jakarta', 'Bandung', 'Semarang', 'Lainnya'];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _namaTokoCtrl.dispose();
    _picNameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validasi
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) return _err('Email tidak valid');
    if (_passwordCtrl.text.trim().length < 6) return _err('Password minimal 6 karakter');
    if (_namaTokoCtrl.text.trim().isEmpty) return _err('Nama toko wajib diisi');
    if (_phoneCtrl.text.trim().isEmpty) return _err('No HP wajib diisi');
    if (_selectedDomisili == null) return _err('Domisili wajib dipilih');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add_rounded, color: Color(0xFF10B981), size: 20)),
          const SizedBox(width: 12),
          const Text('Daftarkan User?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nama: ${_namaTokoCtrl.text.trim()}', style: const TextStyle(fontSize: 14)),
          Text('Email: ${_emailCtrl.text.trim()}', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Text('Status: ${_autoApprove ? "Langsung APPROVED" : "PENDING (perlu review)"}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _autoApprove ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Daftarkan', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      // 1. Create user via Supabase Admin Auth API (service role)
      final res = await _admin.auth.admin.createUser(AdminUserAttributes(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        emailConfirm: true,
        userMetadata: {'full_name': _namaTokoCtrl.text.trim()},
      ));

      if (res.user == null) throw 'Gagal membuat akun user';
      final userId = res.user!.id;

      // 2. Update profiles table
      await _admin.from('profiles').upsert({
        'id': userId,
        'full_name': _namaTokoCtrl.text.trim(),
        'pic_name': _picNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'store_address': _addressCtrl.text.trim(),
        'domisili': _selectedDomisili,
        'approval_status': _autoApprove ? 'APPROVED' : 'PENDING',
        'points': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      if (!mounted) return;

      // Success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 500), curve: Curves.elasticOut,
                builder: (_, v, c) => Transform.scale(scale: v, child: c),
                child: Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40)),
              ),
              const SizedBox(height: 16),
              const Text('User Berhasil Didaftarkan!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${_namaTokoCtrl.text.trim()} (${_emailCtrl.text.trim()})', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
              )),
            ]),
          ),
        ),
      );

      // Reset form
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _phoneCtrl.clear();
      _namaTokoCtrl.clear();
      _picNameCtrl.clear();
      _addressCtrl.clear();
      setState(() => _selectedDomisili = null);
    } catch (e) {
      _err('Gagal: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _err(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)), backgroundColor: const Color(0xFFEF4444), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E))),
        title: const Text('Daftarkan User Baru', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBAE6FD))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF3B82F6)),
              SizedBox(width: 10),
              Expanded(child: Text('Daftarkan toko kecil yang tidak bisa registrasi sendiri. User akan langsung bisa login dengan email & password yang Anda buat.', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4))),
            ]),
          ),
          const SizedBox(height: 24),

          // Form card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Informasi Akun', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 16),
              _field('Email *', _emailCtrl, Icons.email_outlined, hint: 'toko@email.com', kb: TextInputType.emailAddress),
              _field('Password *', _passwordCtrl, Icons.lock_outline_rounded, hint: 'Minimal 6 karakter'),
              _field('No HP *', _phoneCtrl, Icons.phone_android_rounded, hint: '08xxxxxxxxxx', kb: TextInputType.phone),

              const Divider(height: 32),
              const Text('Data Toko', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 16),
              _field('Nama Toko *', _namaTokoCtrl, Icons.storefront_rounded, hint: 'Contoh: Toko Jaya Motor'),
              _field('Nama PIC', _picNameCtrl, Icons.person_outline_rounded, hint: 'Penanggung jawab'),
              _field('Alamat Toko', _addressCtrl, Icons.location_on_outlined, hint: 'Jl. Raya No. 123', lines: 2),

              // Domisili
              const SizedBox(height: 4),
              const Text('Domisili *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedDomisili,
                decoration: _dec(Icons.map_outlined),
                items: _domList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedDomisili = v),
              ),
              const SizedBox(height: 20),

              // Auto approve toggle
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _autoApprove ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: _autoApprove ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A))),
                child: Row(children: [
                  Icon(_autoApprove ? Icons.check_circle_rounded : Icons.schedule_rounded, color: _autoApprove ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_autoApprove ? 'Langsung Approved' : 'Status Pending', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _autoApprove ? const Color(0xFF065F46) : const Color(0xFF92400E))),
                    Text(_autoApprove ? 'User langsung bisa pakai aplikasi' : 'Perlu di-approve manual dari KYC', style: TextStyle(fontSize: 11, color: _autoApprove ? const Color(0xFF6B7280) : const Color(0xFFA16207))),
                  ])),
                  Switch(
                    value: _autoApprove,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (v) => setState(() => _autoApprove = v),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.person_add_rounded, size: 20),
              label: Text(_isSaving ? 'Mendaftarkan...' : 'Daftarkan User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFB71C1C).withOpacity(0.5), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {String hint = '', TextInputType kb = TextInputType.text, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl, keyboardType: kb, maxLines: lines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: _dec(icon, hint: hint),
        ),
      ]),
    );
  }

  InputDecoration _dec(IconData icon, {String hint = ''}) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
    prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
    filled: true, fillColor: const Color(0xFFF8F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
  );
}
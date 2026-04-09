import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/layout_state.dart'; // <-- IMPORT GLOBAL STATE
import 'login_page.dart';

class RejectedPage extends StatefulWidget {
  final Map<String, dynamic> profileData;
  const RejectedPage({super.key, required this.profileData});

  @override
  State<RejectedPage> createState() => _RejectedPageState();
}

class _RejectedPageState extends State<RejectedPage> with TickerProviderStateMixin {
  final _auth = AuthController();
  bool _isEditing = false;
  bool _isSaving = false;

  late final TextEditingController _namaTokoCtrl;
  late final TextEditingController _picNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _ktpCtrl;
  String? _domisili;
  Uint8List? _newKtpBytes;
  XFile? _newKtpFile;
  String? _existingKtpUrl;

  final _domList = ['Surabaya', 'Sidoarjo', 'Gresik', 'Malang', 'Jakarta', 'Bandung', 'Semarang', 'Lainnya'];

  late AnimationController _entryAnim;
  late Animation<double> _iconScale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final p = widget.profileData;
    _namaTokoCtrl = TextEditingController(text: p['full_name'] ?? '');
    _picNameCtrl = TextEditingController(text: p['pic_name'] ?? '');
    _phoneCtrl = TextEditingController(text: p['phone'] ?? '');
    _addressCtrl = TextEditingController(text: p['store_address'] ?? '');
    _ktpCtrl = TextEditingController(text: p['ktp_number'] ?? '');
    _domisili = p['domisili'] ?? p['domicile'];
    _existingKtpUrl = p['ktp_image_url'];

    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _iconScale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.2, 0.6, curve: Curves.easeOut)));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)));
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _namaTokoCtrl.dispose(); _picNameCtrl.dispose(); _phoneCtrl.dispose(); _addressCtrl.dispose(); _ktpCtrl.dispose();
    super.dispose();
  }

  Future<void> _resubmit() async {
    if (_namaTokoCtrl.text.trim().isEmpty || _picNameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty || _ktpCtrl.text.trim().isEmpty || _domisili == null) {
      _snack('Semua field wajib diisi', Colors.red); return;
    }
    setState(() => _isSaving = true);
    showLoading(context);
    try {
      await _auth.updateProfileForResubmit(fullName: _namaTokoCtrl.text.trim(), picName: _picNameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), storeAddress: _addressCtrl.text.trim(), domisili: _domisili!, ktpNumber: _ktpCtrl.text.trim(), ktpImageBytes: _newKtpBytes, ktpFileName: _newKtpFile?.name);
      if (!mounted) return;
      hideLoading(context);
      _showSuccess();
    } catch (e) {
      if (mounted) hideLoading(context);
      _snack(e.toString(), Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccess() {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 600), curve: Curves.elasticOut, builder: (_, v, c) => Transform.scale(scale: v, child: c),
          child: Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40))),
        const SizedBox(height: 18),
        const Text('Data Dikirim Ulang!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Akun kembali ke status PENDING dan akan diverifikasi ulang.', style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: () { Navigator.pop(ctx); Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false); },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w600)),
        )),
      ])),
    ));
  }

  Future<void> _pickKtp() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (p != null) { final b = await p.readAsBytes(); setState(() { _newKtpFile = p; _newKtpBytes = b; }); }
  }

  void _snack(String msg, Color c) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)), backgroundColor: c, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))); }

  Future<void> _logout() async { await _auth.signOut(); if (!mounted) return; Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false); }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim), child: child)),
            child: _isEditing ? _buildEditView(isDesktop) : _buildInfoView(isDesktop),
          ),
        );
      }
    );
  }

  // ==================== INFO VIEW ====================
  Widget _buildInfoView(bool isDesktop) {
    final reason = widget.profileData['rejection_reason'] ?? 'Tidak ada alasan spesifik dari admin.';
    return Stack(key: const ValueKey('info'), children: [
      Container(height: 280, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB71C1C), Color(0xFFE53935)]))),

      SafeArea(
        child: Stack(
          children: [
            // --- KONTEN UTAMA ---
            Positioned.fill(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
                    child: Column(children: [
                      const SizedBox(height: 50), // Spasi tombol switch

                      // Icon
                      ScaleTransition(scale: _iconScale, child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))]),
                        child: const Icon(Icons.cancel_rounded, size: 52, color: Color(0xFFEF4444)),
                      )),
                      const SizedBox(height: 24),

                      FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: Column(children: [
                        const Text('Pendaftaran Ditolak', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text('Mohon maaf, data Anda belum bisa disetujui', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                      ]))),
                      const SizedBox(height: 32),

                      // Content
                      FadeTransition(opacity: _fade, child: SlideTransition(position: _slide, child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))]),
                        child: Column(children: [
                          // Reason box
                          Container(
                            width: double.infinity, padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFE082))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF59E0B))),
                                const SizedBox(width: 10),
                                Text('Alasan Penolakan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange[900])),
                              ]),
                              const SizedBox(height: 10),
                              Text(reason, style: TextStyle(fontSize: 14, color: Colors.brown[700], height: 1.6)),
                            ]),
                          ),
                          const SizedBox(height: 28),

                          // Fix button
                          SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                            onPressed: () => setState(() => _isEditing = true),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.edit_rounded, size: 20), SizedBox(width: 10), Text('Perbaiki Data & Kirim Ulang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))]),
                          )),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, height: 48, child: OutlinedButton(
                            onPressed: _logout,
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6B7280), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
                          )),
                        ]),
                      ))),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ),

            // --- TOMBOL SWITCH MODE ---
            Positioned(
              top: 16, right: 24,
              child: InkWell(
                onTap: () => LayoutState().toggleMode(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                  child: Row(
                    children: [
                      Icon(isDesktop ? Icons.phone_android_rounded : Icons.computer_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(isDesktop ? "Mode HP" : "Mode Web", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  // ==================== EDIT VIEW ====================
  Widget _buildEditView(bool isDesktop) {
    return Scaffold(
      key: const ValueKey('edit'),
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(children: [
        Container(height: 140, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]))),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
              child: Column(children: [
                // Header
                Padding(padding: const EdgeInsets.fromLTRB(8, 4, 20, 0), child: Row(children: [
                  IconButton(onPressed: () => setState(() => _isEditing = false), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                  const SizedBox(width: 4),
                  const Expanded(child: Text('Perbaiki Data', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
                  
                  // Tombol Switch di Edit View
                  InkWell(
                    onTap: () => LayoutState().toggleMode(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                      child: Row(
                        children: [
                          Icon(isDesktop ? Icons.phone_android_rounded : Icons.computer_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(isDesktop ? "HP" : "Web", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ])),
                const SizedBox(height: 12),

                // Form
                Expanded(child: Container(
                  decoration: const BoxDecoration(color: Color(0xFFF5F5F5), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
                    _editCard([
                      _f('Nama Toko *', _namaTokoCtrl, Icons.storefront_rounded),
                      _f('Nama PIC *', _picNameCtrl, Icons.person_outline_rounded),
                      _f('No HP *', _phoneCtrl, Icons.phone_android_rounded, kb: TextInputType.phone),
                      _f('Alamat Toko *', _addressCtrl, Icons.location_on_outlined, lines: 2),
                      // Domisili
                      Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Domisili *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _domisili,
                          decoration: _dec(Icons.map_outlined),
                          items: _domList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _domisili = v),
                        ),
                      ])),
                      _f('Nomor KTP *', _ktpCtrl, Icons.credit_card_rounded, kb: TextInputType.number),
                    ]),
                    const SizedBox(height: 16),

                    // KTP Image
                    _editCard([
                      const Text('Foto KTP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                      const SizedBox(height: 10),
                      GestureDetector(onTap: _pickKtp, child: Container(
                        width: double.infinity, height: 160,
                        decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(14), border: Border.all(color: _newKtpBytes != null ? const Color(0xFF10B981) : Colors.grey[300]!, width: _newKtpBytes != null ? 2 : 1)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(13),
                          child: _newKtpBytes != null
                            ? Stack(fit: StackFit.expand, children: [Image.memory(_newKtpBytes!, fit: BoxFit.cover), Positioned(top: 8, right: 8, child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 18)))])
                            : _existingKtpUrl != null && _existingKtpUrl!.isNotEmpty
                              ? Stack(fit: StackFit.expand, children: [Image.network(_existingKtpUrl!, fit: BoxFit.cover), Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Text('Tap untuk ganti', style: TextStyle(color: Colors.white, fontSize: 11))))])
                              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.grey[400]), const SizedBox(height: 8), Text('Tap untuk upload', style: TextStyle(color: Colors.grey[500], fontSize: 13))]),
                        ),
                      )),
                    ]),
                    const SizedBox(height: 30),
                  ])),
                )),

                // Bottom
                Container(
                  color: const Color(0xFFF5F5F5),
                  padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                    onPressed: _isSaving ? null : _resubmit,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFB71C1C).withOpacity(0.5), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: _isSaving
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white.withOpacity(0.9), strokeWidth: 2.5)), const SizedBox(width: 12), const Text('Mengirim...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))])
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.send_rounded, size: 20), SizedBox(width: 10), Text('Kirim Ulang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))]),
                  )),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _editCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _f(String label, TextEditingController c, IconData icon, {TextInputType kb = TextInputType.text, int lines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      const SizedBox(height: 8),
      TextFormField(controller: c, keyboardType: kb, maxLines: lines, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: _dec(icon)),
    ]));
  }

  InputDecoration _dec(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
    filled: true, fillColor: const Color(0xFFF8F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
  );
}
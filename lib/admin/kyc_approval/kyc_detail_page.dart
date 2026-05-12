import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';
import '../../utils/email_notification_service.dart';
import '../accurate/accurate_service.dart';

class KycDetailPage extends StatefulWidget {
  final Map<String, dynamic> store;
  const KycDetailPage({super.key, required this.store});

  @override
  State<KycDetailPage> createState() => _KycDetailPageState();
}

class _KycDetailPageState extends State<KycDetailPage> with SingleTickerProviderStateMixin {
  final _admin = AdminSupabase.client;
  bool _isProcessing = false;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Controller untuk Form Kiri (Murni Data Supabase)
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _accIdCtrl;

  // State & Controller untuk Pencarian Kanan (Accurate)
  final _accurateService = AccurateService();
  final _searchAccurateIdCtrl = TextEditingController();
  bool _isSearchingAccurate = false;
  bool _isLoadingAccurate = false;
  Map<String, dynamic>? _selectedAccurate;
  String? _accurateError;

  @override
  void initState() {
    super.initState();
    // Isi form kiri dengan data dari database
    _nameCtrl = TextEditingController(text: widget.store['full_name'] ?? '');
    _emailCtrl = TextEditingController(text: widget.store['email'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.store['phone'] ?? '');
    _accIdCtrl = TextEditingController(text: widget.store['accurate_customer_id']?.toString() ?? '');

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
    
    // Auto load data kanan jika Accurate ID sudah terisi
    if (_accIdCtrl.text.trim().isNotEmpty && _accIdCtrl.text.trim() != '-') {
      _searchAccurateIdCtrl.text = _accIdCtrl.text.trim();
      _searchAccurateById(silent: true);
    }
  }

  @override
  void dispose() { 
    _animController.dispose(); 
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _accIdCtrl.dispose();
    _searchAccurateIdCtrl.dispose();
    super.dispose(); 
  }

  // --- FUNGSI MENCARI ID KE ACCURATE (SISI KANAN) ---
  Future<void> _searchAccurateById({bool silent = false}) async {
    final id = _searchAccurateIdCtrl.text.trim();
    if (id.isEmpty) {
      if (!silent) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan ID Accurate yang ingin dicari')));
      return;
    }

    setState(() {
      _isSearchingAccurate = true;
      _isLoadingAccurate = true; 
      _accurateError = null;
      _selectedAccurate = null;
    });

    final result = await _accurateService.getCustomerById(id);

    if (mounted) {
      setState(() {
        _isSearchingAccurate = false;
        _isLoadingAccurate = false;
        if (result != null) {
          _selectedAccurate = result;
        } else {
          if (!silent) _accurateError = 'Data dengan ID $id tidak ditemukan di Accurate';
        }
      });
    }
  }

  // --- FUNGSI SALIN DATA DARI KANAN KE KIRI ---
  void _overwriteLocalData() {
    if (_selectedAccurate == null) return;
    setState(() {
      _nameCtrl.text = _selectedAccurate!['name'] ?? _nameCtrl.text;
      _emailCtrl.text = _selectedAccurate!['email'] ?? _emailCtrl.text;
      _phoneCtrl.text = _selectedAccurate!['mobilePhone'] ?? _phoneCtrl.text;
      _accIdCtrl.text = _selectedAccurate!['id']?.toString() ?? _accIdCtrl.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil disalin ke form sebelah kiri!'), backgroundColor: Color(0xFF10B981)));
  }

  // --- FUNGSI SIMPAN DATA LOKAL (TOMBOL DI BAWAH FORM KIRI) ---
  Future<void> _saveLocalData() async {
    setState(() => _isProcessing = true);
    try {
      final updateData = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'accurate_customer_id': _accIdCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String()
      };
      
      await _admin.from('profiles').update(updateData).eq('id', widget.store['id']);

      // Update state lokal agar UI merefleksikan perubahan
      setState(() {
        widget.store['full_name'] = updateData['full_name'];
        widget.store['email'] = updateData['email'];
        widget.store['phone'] = updateData['phone'];
        widget.store['accurate_customer_id'] = updateData['accurate_customer_id'];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Data berhasil disimpan!'), 
          backgroundColor: Color(0xFF10B981)
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally { 
      if (mounted) setState(() => _isProcessing = false); 
    }
  }

  // --- FUNGSI SIMPAN STATUS APPROVE / REJECT (TOMBOL BAWAH) ---
  Future<void> _updateStatus(String status, String? reason) async {
    setState(() => _isProcessing = true);
    try {
      final updateData = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'accurate_customer_id': _accIdCtrl.text.trim(),
        'approval_status': status, 
        'updated_at': DateTime.now().toIso8601String()
      };
      
      if (status == 'REJECTED' && reason != null && reason.isNotEmpty) updateData['rejection_reason'] = reason;
      else if (status == 'APPROVED' || status == 'PENDING') updateData['rejection_reason'] = null;
      
      await _admin.from('profiles').update(updateData).eq('id', widget.store['id']);

      final userName = _nameCtrl.text.trim();
      final userId = widget.store['id'] as String;
      String? userEmail;
      try { final userData = await _admin.auth.admin.getUserById(userId); userEmail = userData.user?.email; } catch (_) {}
      
      if (userEmail != null) {
        if (status == 'APPROVED') EmailNotificationService.sendApproved(toEmail: userEmail, userName: userName);
        else if (status == 'REJECTED') EmailNotificationService.sendRejected(toEmail: userEmail, userName: userName, reason: reason ?? '-');
      }

      if (!mounted) return;

      if (status == 'PENDING') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status berhasil dikembalikan ke PENDING'), backgroundColor: Color(0xFFF59E0B)));
        setState(() {
           widget.store['approval_status'] = 'PENDING';
           widget.store['rejection_reason'] = null;
        });
      } else {
        await showDialog(context: context, barrierDismissible: false, builder: (context) => _SuccessDialog(status: status, userName: userName));
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  Future<void> _approveUser() async {
    final confirm = await _showConfirmDialog(title: 'Simpan & Approve User', message: 'Yakin ingin menyimpan data form kiri dan menyetujui user ini?', confirmText: 'Simpan & Approve', confirmColor: const Color(0xFF10B981), icon: Icons.check_circle_rounded);
    if (confirm != true) return;
    await _updateStatus('APPROVED', null);
  }

  Future<void> _rejectUser() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20)), const SizedBox(width: 12), const Text('Tolak User', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('User ini akan ditolak.', style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        const SizedBox(height: 16), const Text('Alasan penolakan *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
        TextField(controller: reasonController, maxLines: 3, enableInteractiveSelection: true, decoration: InputDecoration(hintText: 'Contoh: Foto KTP buram...', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13), filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () { if (reasonController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alasan wajib diisi'), backgroundColor: Color(0xFFEF4444))); return; } Navigator.pop(context, true); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Tolak', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm != true) return;
    await _updateStatus('REJECTED', reasonController.text.trim());
  }

  Future<bool?> _showConfirmDialog({required String title, required String message, required String confirmText, required Color confirmColor, required IconData icon}) {
    return showDialog<bool>(context: context, builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: confirmColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: confirmColor, size: 20)), const SizedBox(width: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: Text(message, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: confirmColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: Text(confirmText, style: const TextStyle(color: Colors.white)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final String status = store['approval_status'] ?? 'PENDING';
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    Color statusColor; String statusLabel; IconData statusIcon;
    switch (status) {
      case 'APPROVED': statusColor = const Color(0xFF10B981); statusLabel = 'Disetujui'; statusIcon = Icons.check_circle_rounded; break;
      case 'REJECTED': statusColor = const Color(0xFFEF4444); statusLabel = 'Ditolak'; statusIcon = Icons.cancel_rounded; break;
      default: statusColor = const Color(0xFFF59E0B); statusLabel = 'Menunggu Verifikasi'; statusIcon = Icons.schedule_rounded;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      body: Stack(children: [
        Container(height: 200, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                const Expanded(child: Text('Review User', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, color: Colors.white, size: 14), const SizedBox(width: 4), Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))])),
                const SizedBox(width: 8),
              ]),
            ),
            Expanded(
              child: FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _slideAnim,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      child: _buildMainContent(isDesktop, store),
                    ),
                  ),
                ),
              )),
            ),
          ]),
        ),
        
        // Bottom Action Bar
        if (status == 'PENDING' || status == 'REJECTED')
          Positioned(bottom: 0, left: 0, right: 0,
            child: Center(child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))]),
                child: Row(children: [
                  if (status == 'PENDING') ...[
                    Expanded(child: SizedBox(height: 50, child: OutlinedButton.icon(onPressed: _isProcessing ? null : _rejectUser, icon: const Icon(Icons.close_rounded, size: 18), label: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444), side: const BorderSide(color: Color(0xFFEF4444)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _isProcessing ? null : _approveUser, icon: _isProcessing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_rounded, size: 20), label: Text(_isProcessing ? 'Memproses...' : 'Simpan & Approve', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))))),
                  ] else if (status == 'REJECTED') ...[
                    Expanded(
                      child: SizedBox(
                        height: 50, 
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : () => _updateStatus('PENDING', null), 
                          icon: const Icon(Icons.refresh_rounded, size: 20), 
                          label: const Text('Reset ke PENDING', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), 
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF59E0B), side: const BorderSide(color: Color(0xFFF59E0B)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))
                        )
                      )
                    )
                  ]
                ]),
              ),
            )),
          ),
      ]),
    );
  }

  Widget _buildMainContent(bool isDesktop, Map<String, dynamic> store) {
    return Column(children: [
      _buildSideBySideCard(isDesktop),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildSection('Dokumen KYC', [_infoRow(Icons.badge_outlined, 'No. KTP', store['ktp_number'] ?? '-')])),
        if (isDesktop) const SizedBox(width: 16),
        if (isDesktop) Expanded(child: _buildSection('Info Lokasi', [
             _infoRow(Icons.person_outline_rounded, 'Nama PIC', store['pic_name'] ?? '-'),
             _infoRow(Icons.location_on_outlined, 'Alamat', store['store_address'] ?? '-'),
             _infoRow(Icons.map_outlined, 'Domisili', store['domisili'] ?? '-'),
        ])),
      ]),
      if (!isDesktop) ...[
        const SizedBox(height: 16), 
        _buildSection('Info Lokasi', [
             _infoRow(Icons.person_outline_rounded, 'Nama PIC', store['pic_name'] ?? '-'),
             _infoRow(Icons.location_on_outlined, 'Alamat', store['store_address'] ?? '-'),
             _infoRow(Icons.map_outlined, 'Domisili', store['domisili'] ?? '-'),
        ])
      ],
    ]);
  }

  // ====================================================================
  // UI Card Perbandingan Side-by-Side Kiri Kanan
  // ====================================================================
  Widget _buildSideBySideCard(bool isDesktop) {
    if (!isDesktop) {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          children: [
            _buildLeftForm(),
            Divider(height: 1, color: Colors.grey.shade200, thickness: 1),
            _buildRightReference(),
            if (_selectedAccurate != null && !_isLoadingAccurate)
              _buildCopyButton(),
          ]
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kiri (Border kanan sebagai pengganti IntrinsicHeight & VerticalDivider)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade200))
                  ),
                  child: _buildLeftForm(),
                )
              ),
              // Kanan
              Expanded(child: _buildRightReference()),
            ],
          ),
          
          if (_selectedAccurate != null && !_isLoadingAccurate)
            _buildCopyButton()
        ],
      )
    );
  }

  // --- WIDGET KIRI: FORM MURNI SUPABASE (DITAMBAH TOMBOL SIMPAN DATA) ---
  Widget _buildLeftForm() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20), SizedBox(width: 8), Text('Data User Aplikasi (Supabase)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
          const Divider(height: 32),
          _buildEditBox('Nama Lengkap', _nameCtrl),
          _buildEditBox('Email Akun', _emailCtrl),
          _buildEditBox('No. WhatsApp', _phoneCtrl),
          _buildEditBox('Accurate ID', _accIdCtrl), 
          
          // [FITUR BARU] Tombol Simpan Data spesifik untuk update form kiri
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _saveLocalData,
              icon: _isProcessing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isProcessing ? 'Menyimpan...' : 'Simpan Data', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8), 
                foregroundColor: Colors.white, 
                elevation: 0, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET KANAN: ALAT PENCARI ACCURATE BERDASARKAN ID ---
  Widget _buildRightReference() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(20),
      // Set height minimal agar seimbang dengan form kiri
      constraints: const BoxConstraints(minHeight: 460),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.search_rounded, color: Color(0xFF1D4ED8), size: 18), SizedBox(width: 8), Text('Cari Referensi P2T (Accurate)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontSize: 13))]),
          const SizedBox(height: 12),
          
          // Form Pencarian HANYA berdasarkan ID
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchAccurateIdCtrl,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Ketik ID Accurate...',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                  )
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearchingAccurate ? null : _searchAccurateById,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                child: _isSearchingAccurate 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Cari ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),

          const Divider(height: 32),
          
          // Hasil Penampilan Data Accurate
          if (_isLoadingAccurate)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
          else if (_accurateError != null)
              Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off_rounded, color: Colors.red.shade300, size: 40), const SizedBox(height: 8), Text(_accurateError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)])))
          else if (_selectedAccurate != null) ...[
            _buildRefBox('Nama', _selectedAccurate!['name'], compareWith: _nameCtrl.text),
            _buildRefBox('Email', _selectedAccurate!['email'], compareWith: _emailCtrl.text),
            _buildRefBox('No. HP', _selectedAccurate!['mobilePhone'], compareWith: _phoneCtrl.text),
            _buildRefBox('ID Accurate', _selectedAccurate!['id']?.toString(), compareWith: _accIdCtrl.text),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.grey.shade400, size: 36),
                    const SizedBox(height: 8),
                    Text('Gunakan fitur pencarian di atas\nuntuk menarik data referensi P2T.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ]
                )
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildCopyButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _overwriteLocalData,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Salin Data Kanan ke Form Kiri', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4ED8), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
    );
  }

  Widget _buildEditBox(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl, 
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: Colors.white, 
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), 
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1D4ED8)))
            )
          ),
        ]
      )
    );
  }

  Widget _buildRefBox(String label, dynamic value, {dynamic compareWith}) {
    final String valStr = (value?.toString() ?? '-').trim();
    final String compStr = (compareWith?.toString() ?? '').trim();
    final bool isDiff = valStr.toLowerCase() != compStr.toLowerCase() && valStr.isNotEmpty && valStr != '-';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDiff ? const Color(0xFFDCFCE7) : Colors.white, 
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDiff ? const Color(0xFF86EFAC) : Colors.grey.shade200)
            ),
            child: Text(
              valStr, 
              style: TextStyle(
                fontSize: 13, 
                fontWeight: isDiff ? FontWeight.w700 : FontWeight.w600,
                color: isDiff ? const Color(0xFF166534) : Colors.black87
              )
            ),
          )
        ],
      ),
    );
  }

  Future<void> _resetUserPassword() async {
    final userId = widget.store['id'];
    String? userEmail;
    try { final userData = await _admin.auth.admin.getUserById(userId); userEmail = userData.user?.email; } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal ambil data user: $e'), backgroundColor: const Color(0xFFEF4444))); return; }
    if (userEmail == null || userEmail.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email user tidak ditemukan'), backgroundColor: Color(0xFFEF4444))); return; }

    final passCtrl = TextEditingController();
    bool showPass = false;
    final newPass = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B), size: 20)), const SizedBox(width: 12), const Text('Set Password Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('User: ${_nameCtrl.text}', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('Email: $userEmail', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))), const SizedBox(height: 16),
        TextField(controller: passCtrl, obscureText: !showPass, decoration: InputDecoration(hintText: 'Password baru (min 6 karakter)', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13), prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey[400]), suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: Colors.grey[400]), onPressed: () => setD(() => showPass = !showPass)), filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () { if (passCtrl.text.trim().length < 6) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Minimal 6 karakter'), backgroundColor: Color(0xFFEF4444))); return; } Navigator.pop(ctx, passCtrl.text.trim()); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      ],
    )));
    if (newPass == null) return;
    setState(() => _isProcessing = true);
    try {
      await _admin.auth.admin.updateUserById(userId, attributes: AdminUserAttributes(password: newPass));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Password berhasil diubah!'), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444))); }
    finally { if (mounted) setState(() => _isProcessing = false); }
  }

  Widget _buildAdminTools() {
    return Column(children: [
      GestureDetector(onTap: _isProcessing ? null : _resetUserPassword,
        child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFDE68A))),
          child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFF59E0B), size: 20)), const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Set Password Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E))), Text('Admin langsung tentukan password baru user', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)))])), const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B), size: 20)]))),
    ]);
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))), const SizedBox(height: 14), ...children]));
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: const Color(0xFF6B7280))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))])),
    ]));
  }

}

class _SuccessDialog extends StatefulWidget {
  final String status; final String userName;
  const _SuccessDialog({required this.status, required this.userName});
  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pop(context); });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isApproved = widget.status == 'APPROVED';
    final color = isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final icon = isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final text = isApproved ? 'User Disetujui!' : 'User Ditolak';
    return Center(child: ScaleTransition(scale: _scale, child: Container(
      margin: const EdgeInsets.all(40), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 36)), const SizedBox(height: 16), Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)), const SizedBox(height: 8), Text(widget.userName, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)), textAlign: TextAlign.center)]))));
  }
}
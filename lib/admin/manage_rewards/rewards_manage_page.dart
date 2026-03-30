import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../admin_supabase.dart';

class RewardsManagePage extends StatefulWidget {
  const RewardsManagePage({super.key});

  @override
  State<RewardsManagePage> createState() => _RewardsManagePageState();
}

class _RewardsManagePageState extends State<RewardsManagePage> {
  final _admin = AdminSupabase.client;
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRewards();
  }

  Future<void> _fetchRewards() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin
          .from('rewards')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rewards = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> reward) async {
    final newStatus = !(reward['is_active'] ?? true);
    try {
      await _admin.from('rewards').update({'is_active': newStatus}).eq('id', reward['id']);
      _fetchRewards();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Hadiah diaktifkan' : 'Hadiah dinonaktifkan'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _deleteReward(Map<String, dynamic> reward) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Hadiah', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Text('Yakin ingin menghapus "${reward['name']}"?', style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      // Auto-delete file gambar di Storage jika ada
      final imageUrl = reward['image_url'] as String?;
      if (imageUrl != null && imageUrl.contains('upsol-assets')) {
        final fileName = imageUrl.split('/').last;
        await _admin.storage.from('upsol-assets').remove([fileName]);
      }

      await _admin.from('rewards').delete().eq('id', reward['id']);
      _fetchRewards();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _showRewardForm({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final pointsCtrl = TextEditingController(text: existing?['points_required']?.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing?['stock']?.toString() ?? '100');
    final termsCtrl = TextEditingController(text: existing?['terms_condition'] ?? '');
    
    File? selectedImage; // Menyimpan file gambar baru
    String? existingImageUrl = existing?['image_url'];
    String selectedType = existing?['type'] ?? 'VOUCHER';
    bool isSaving = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.9,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(existing == null ? Icons.add_rounded : Icons.edit_rounded, color: const Color(0xFFB71C1C), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        existing == null ? 'Tambah Hadiah' : 'Edit Hadiah',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _formField('Nama Hadiah *', nameCtrl, 'Contoh: Voucher Oli 5L'),
                        const SizedBox(height: 16),
                        _formField('Deskripsi', descCtrl, 'Deskripsi singkat hadiah', maxLines: 2),
                        const SizedBox(height: 16),

                        // Type selector
                        const Text('Tipe *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: ['VOUCHER', 'PRODUCT'].map((type) {
                            final isSelected = selectedType == type;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => selectedType = type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: EdgeInsets.only(right: type == 'VOUCHER' ? 8 : 0, left: type == 'PRODUCT' ? 8 : 0),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFB71C1C).withOpacity(0.08) : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFB71C1C) : Colors.grey[200]!,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        type == 'VOUCHER' ? Icons.confirmation_number_rounded : Icons.inventory_2_rounded,
                                        size: 18,
                                        color: isSelected ? const Color(0xFFB71C1C) : const Color(0xFF9CA3AF),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        type == 'VOUCHER' ? 'Voucher' : 'Produk',
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected ? const Color(0xFFB71C1C) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(child: _formField('Poin Diperlukan *', pointsCtrl, '100', keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _formField('Stok *', stockCtrl, '100', keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // --- [UI UPLOAD GAMBAR] ---
                        const Text('Gambar Hadiah', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setModalState(() => selectedImage = File(pickedFile.path));
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 140,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: selectedImage != null
                                  ? Image.file(selectedImage!, fit: BoxFit.cover)
                                  : existingImageUrl != null && existingImageUrl!.isNotEmpty
                                      ? Image.network(existingImageUrl!, fit: BoxFit.cover)
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.grey[400]),
                                            const SizedBox(height: 8),
                                            Text('Tap untuk pilih gambar', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                          ],
                                        ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _formField('Syarat & Ketentuan', termsCtrl, 'Opsional', maxLines: 3),
                        const SizedBox(height: 24),

                        // --- [TOMBOL SIMPAN] ---
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : () async {
                              if (nameCtrl.text.trim().isEmpty || pointsCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Nama dan Poin wajib diisi'), backgroundColor: Color(0xFFEF4444)),
                                );
                                return;
                              }
                              
                              setModalState(() => isSaving = true);
                              try {
                                String? finalImageUrl = existingImageUrl;

                                // Upload ke storage jika admin memilih gambar baru
                                if (selectedImage != null) {
                                  final ext = selectedImage!.path.split('.').last;
                                  final fileName = 'reward_${DateTime.now().millisecondsSinceEpoch}.$ext';
                                  
                                  await _admin.storage.from('upsol-assets').upload(fileName, selectedImage!);
                                  finalImageUrl = _admin.storage.from('upsol-assets').getPublicUrl(fileName);
                                }

                                final data = {
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'type': selectedType,
                                  'points_required': int.parse(pointsCtrl.text.trim()),
                                  'stock': int.tryParse(stockCtrl.text.trim()) ?? 100,
                                  'image_url': finalImageUrl,
                                  'terms_condition': termsCtrl.text.trim().isEmpty ? null : termsCtrl.text.trim(),
                                  'is_active': true,
                                };

                                if (existing != null) {
                                  await _admin.from('rewards').update(data).eq('id', existing['id']);
                                } else {
                                  await _admin.from('rewards').insert(data);
                                }

                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: isSaving
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text(existing == null ? 'Tambah Hadiah' : 'Simpan Perubahan', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result == true) _fetchRewards();
  }

  Widget _formField(String label, TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          enableInteractiveSelection: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
        ),
        title: const Text('Kelola Hadiah', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: Text('${_rewards.length} hadiah', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRewardForm(),
        backgroundColor: const Color(0xFFB71C1C),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
          : _rewards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(18)),
                        child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFB71C1C), size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text('Belum ada hadiah', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Tap + untuk menambahkan', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFB71C1C),
                  onRefresh: _fetchRewards,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    itemCount: _rewards.length,
                    itemBuilder: (context, i) {
                      final r = _rewards[i];
                      final bool isActive = r['is_active'] ?? true;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 400 + (i * 60)),
                        curve: Curves.easeOutCubic,
                        builder: (_, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 16 * (1 - val)), child: child)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isActive ? const Color(0xFFF0F0F0) : const Color(0xFFEF4444).withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              // Image
                              if (r['image_url'] != null && r['image_url'].toString().isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Image.network(
                                    r['image_url'],
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 60,
                                      color: const Color(0xFFF3F4F6),
                                      child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFFD1D5DB))),
                                    ),
                                  ),
                                ),

                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title row
                                    Row(
                                      children: [
                                        // Type badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: r['type'] == 'VOUCHER'
                                                ? const Color(0xFF3B82F6).withOpacity(0.1)
                                                : const Color(0xFF10B981).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            r['type'] == 'VOUCHER' ? 'Voucher' : 'Produk',
                                            style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.w600,
                                              color: r['type'] == 'VOUCHER' ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                        if (!isActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Nonaktif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                          ),
                                        ],
                                        const Spacer(),
                                        // Points
                                        Row(
                                          children: [
                                            const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16),
                                            const SizedBox(width: 4),
                                            Text('${r['points_required']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Name
                                    Text(r['name'] ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                                    if (r['description'] != null && r['description'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(r['description'], style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                    const SizedBox(height: 10),

                                    // Stock
                                    Text('Stok: ${r['stock'] ?? 0}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                    const Divider(height: 20),

                                    // Actions
                                    Row(
                                      children: [
                                        _actionBtn(Icons.edit_rounded, 'Edit', const Color(0xFF3B82F6), () => _showRewardForm(existing: r)),
                                        const SizedBox(width: 8),
                                        _actionBtn(
                                          isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                          isActive ? 'Nonaktifkan' : 'Aktifkan',
                                          const Color(0xFFF59E0B),
                                          () => _toggleActive(r),
                                        ),
                                        const SizedBox(width: 8),
                                        _actionBtn(Icons.delete_rounded, 'Hapus', const Color(0xFFEF4444), () => _deleteReward(r)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
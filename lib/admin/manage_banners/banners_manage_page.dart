import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../admin_supabase.dart';

class BannersManagePage extends StatefulWidget {
  const BannersManagePage({super.key});

  @override
  State<BannersManagePage> createState() => _BannersManagePageState();
}

class _BannersManagePageState extends State<BannersManagePage> {
  final _admin = AdminSupabase.client;
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  // ... [FUNGSI FETCH, TOGGLE, DELETE, DAN SHOW FORM 100% TETAP SAMA SEPERTI ASLINYA] ...
  Future<void> _fetchBanners() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin.from('banners').select().order('created_at', ascending: false);
      if (mounted) setState(() { _banners = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> banner) async {
    final newStatus = !(banner['is_active'] ?? true);
    try {
      await _admin.from('banners').update({'is_active': newStatus}).eq('id', banner['id']);
      _fetchBanners();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newStatus ? 'Banner diaktifkan' : 'Banner dinonaktifkan'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20)), const SizedBox(width: 12), const Text('Hapus Banner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))]),
        content: Text('Yakin ingin menghapus "${banner['title'] ?? 'Banner ini'}"?', style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: const Text('Hapus', style: TextStyle(color: Colors.white)))],
      ),
    );
    if (confirm != true) return;
    try {
      final imageUrl = banner['image_url'] as String?;
      if (imageUrl != null && imageUrl.contains('upsol-assets')) {
        final fileName = imageUrl.split('/').last;
        await _admin.storage.from('upsol-assets').remove([fileName]);
      }
      await _admin.from('banners').delete().eq('id', banner['id']);
      _fetchBanners();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  Future<void> _showBannerForm({Map<String, dynamic>? existing}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    File? selectedImage; String? existingImageUrl = existing?['image_url']; bool isSaving = false;

    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.7, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(existing == null ? Icons.add_rounded : Icons.edit_rounded, color: const Color(0xFF8B5CF6), size: 20)),
                  const SizedBox(width: 12), Text(existing == null ? 'Tambah Banner' : 'Edit Banner', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(), IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF))),
                ]),
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _formField('Judul Banner', titleCtrl, 'Contoh: Promo Akhir Tahun'), const SizedBox(height: 16),
                    const Text('Gambar Banner *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker(); final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) setModalState(() => selectedImage = File(pickedFile.path));
                      },
                      child: Container(
                        width: double.infinity, height: 160, decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: selectedImage != null ? Image.file(selectedImage!, fit: BoxFit.cover) : existingImageUrl != null && existingImageUrl!.isNotEmpty ? Image.network(existingImageUrl!, fit: BoxFit.cover) : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey[400]), const SizedBox(height: 8), Text('Tap untuk pilih gambar', style: TextStyle(color: Colors.grey[500], fontSize: 13))]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          if (selectedImage == null && (existingImageUrl == null || existingImageUrl!.isEmpty)) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Gambar banner wajib dipilih'), backgroundColor: Color(0xFFEF4444))); return; }
                          setModalState(() => isSaving = true);
                          try {
                            String finalImageUrl = existingImageUrl ?? '';
                            if (selectedImage != null) {
                              final ext = selectedImage!.path.split('.').last; final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}.$ext';
                              await _admin.storage.from('upsol-assets').upload(fileName, selectedImage!);
                              finalImageUrl = _admin.storage.from('upsol-assets').getPublicUrl(fileName);
                            }
                            final data = {'title': titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(), 'image_url': finalImageUrl, 'is_active': true};
                            if (existing != null) { await _admin.from('banners').update(data).eq('id', existing['id']); } else { await _admin.from('banners').insert(data); }
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: isSaving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Text(existing == null ? 'Tambah Banner' : 'Simpan', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) _fetchBanners();
  }

  Widget _formField(String label, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), const SizedBox(height: 6), TextField(controller: ctrl, enableInteractiveSelection: true, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14), filled: true, fillColor: const Color(0xFFF9FAFB), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5))))]);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E))),
        title: const Text('Kelola Banner', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [Container(margin: const EdgeInsets.only(right: 16), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: Text('${_banners.length} banner', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBannerForm(),
        backgroundColor: const Color(0xFF8B5CF6), elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white), label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : _banners.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.image_rounded, color: Color(0xFF8B5CF6), size: 32)), const SizedBox(height: 16), const Text('Belum ada banner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 4), const Text('Tap + untuk menambahkan', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13))]))
              : RefreshIndicator(
                  color: const Color(0xFF8B5CF6),
                  onRefresh: _fetchBanners,
                  child: isDesktop
                      // WIDGET DESKTOP: GridView
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 500, crossAxisSpacing: 24, mainAxisSpacing: 24, mainAxisExtent: 240),
                          itemCount: _banners.length,
                          itemBuilder: (context, i) => _buildBannerCard(_banners[i], i, true),
                        )
                      // WIDGET MOBILE: ListView
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          itemCount: _banners.length,
                          itemBuilder: (context, i) => _buildBannerCard(_banners[i], i, false),
                        ),
                ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> b, int index, bool isDesktop) {
    final bool isActive = b['is_active'] ?? true;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 400 + (index * 60)), curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 16 * (1 - val)), child: child)),
      child: Container(
        margin: EdgeInsets.only(bottom: isDesktop ? 0 : 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isActive ? const Color(0xFFF0F0F0) : const Color(0xFFEF4444).withOpacity(0.2))),
        child: Column(children: [
          if (b['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(children: [
                Image.network(b['image_url'], height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 160, color: const Color(0xFFF3F4F6), child: const Center(child: Icon(Icons.broken_image_rounded, color: Color(0xFFD1D5DB))))),
                if (!isActive) Container(height: 160, color: Colors.black.withOpacity(0.4), child: const Center(child: Text('NONAKTIF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 2)))),
              ]),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: Text(b['title'] ?? 'Tanpa judul', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _actionIcon(Icons.edit_rounded, const Color(0xFF3B82F6), () => _showBannerForm(existing: b)), const SizedBox(width: 6),
                _actionIcon(isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, const Color(0xFFF59E0B), () => _toggleActive(b)), const SizedBox(width: 6),
                _actionIcon(Icons.delete_rounded, const Color(0xFFEF4444), () => _deleteBanner(b)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: color)));
  }
}
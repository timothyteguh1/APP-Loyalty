import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';

class ConversionPage extends StatefulWidget {
  const ConversionPage({super.key});
  

  @override
  State<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends State<ConversionPage> {
  final _supabase = Supabase.instance.client;
  final _admin = AdminSupabase.client;
  bool _isLoading = true;
  String _globalRate = '10000';
  List<Map<String, dynamic>> _approvedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Global rate
      final config = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', 'default_conversion_rate')
          .maybeSingle();

      if (config != null) _globalRate = config['value'];

      // Approved users
      final users = await _supabase
          .from('profiles')
          .select()
          .eq('approval_status', 'APPROVED')
          .order('full_name');

      if (mounted) {
        setState(() {
          _approvedUsers = List<Map<String, dynamic>>.from(users);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editGlobalRate() async {
    final controller = TextEditingController(text: _globalRate);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.public_rounded, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Rate Global', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Setiap berapa Rupiah = 1 poin?\nBerlaku untuk semua user yang tidak punya rate khusus.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              enableInteractiveSelection: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                suffixText: '= 1 poin',
                suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty || int.tryParse(val) == null || int.parse(val) <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Masukkan angka valid'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await _admin.from('app_config').update({'value': result}).eq('key', 'default_conversion_rate');
      setState(() => _globalRate = result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate global berhasil diupdate'), backgroundColor: Color(0xFF10B981)),
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

  Future<void> _editUserRate(Map<String, dynamic> user) async {
    final currentRate = user['point_conversion_rate'];
    final controller = TextEditingController(text: currentRate?.toString() ?? '');
    final name = user['full_name'] ?? 'User';

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate Khusus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kosongkan untuk pakai rate global (Rp $_globalRate)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              enableInteractiveSelection: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Kosongkan = pakai global',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w400),
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                suffixText: '= 1 poin',
                suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          if (currentRate != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'CLEAR'),
              child: const Text('Hapus Rate Khusus', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
            ),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty) {
                Navigator.pop(context, 'CLEAR');
                return;
              }
              if (int.tryParse(val) == null || int.parse(val) <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Masukkan angka valid'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      if (result == 'CLEAR') {
        await _admin.from('profiles').update({'point_conversion_rate': null}).eq('id', user['id']);
      } else {
        await _admin.from('profiles').update({'point_conversion_rate': int.parse(result)}).eq('id', user['id']);
      }
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result == 'CLEAR' ? 'Rate khusus dihapus, kembali ke global' : 'Rate khusus berhasil diupdate'),
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

  String _formatRupiah(dynamic value) {
    if (value == null) return '-';
    final n = int.tryParse(value.toString()) ?? 0;
    return n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    }

    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ======= HEADER =======
            const Text('Konversi Poin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Atur berapa Rupiah = 1 poin', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 20),

            // ======= GLOBAL RATE CARD =======
            GestureDetector(
              onTap: _editGlobalRate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.public_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Rate Global', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rp ${_formatRupiah(_globalRate)}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'per 1 poin · berlaku untuk semua user',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Rumus visual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Contoh: Faktur Rp 5.000.000 ÷ ${_formatRupiah(_globalRate)} = ${(5000000 / (int.tryParse(_globalRate) ?? 10000)).floor()} poin',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ======= PER USER RATES =======
            Row(
              children: [
                const Expanded(
                  child: Text('Rate Per User', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_approvedUsers.length} user approved',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_approvedUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.person_off_rounded, size: 36, color: Color(0xFFD1D5DB)),
                    SizedBox(height: 8),
                    Text('Belum ada user approved', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                  ],
                ),
              )
            else
              ...List.generate(_approvedUsers.length, (i) {
                final user = _approvedUsers[i];
                final String name = user['full_name'] ?? 'Tanpa Nama';
                final int? customRate = user['point_conversion_rate'];
                final bool hasCustom = customRate != null;
                final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 400 + (i * 80)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
                    );
                  },
                  child: GestureDetector(
                    onTap: () => _editUserRate(user),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hasCustom ? const Color(0xFFF59E0B).withOpacity(0.3) : const Color(0xFFF0F0F0)),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: hasCustom ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(initial, style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: hasCustom ? const Color(0xFFD97706) : const Color(0xFF6B7280),
                              )),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (hasCustom) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Rp ${_formatRupiah(customRate)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('rate khusus', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                    ] else ...[
                                      Text(
                                        'Rp ${_formatRupiah(_globalRate)} (global)',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Edit icon
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';

class ConversionPage extends StatefulWidget {
  const ConversionPage({super.key});

  @override
  State<ConversionPage> createState() => _ConversionPageState();
}

class _ConversionPageState extends State<ConversionPage> {
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
      final config = await _admin.from('app_config').select('value').eq('key', 'default_conversion_rate').maybeSingle();
      if (config != null) _globalRate = config['value'];

      final users = await _admin.from('profiles').select().eq('approval_status', 'APPROVED').order('full_name');

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
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: 'Rp ', prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                suffixText: '= 1 poin', suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                filled: true, fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty || int.tryParse(val) == null || int.parse(val) <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan angka valid'), backgroundColor: Color(0xFFEF4444)));
                return;
              }
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      await _admin.from('app_config').update({'value': result}).eq('key', 'default_conversion_rate');
      setState(() => _globalRate = result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate global berhasil diupdate'), backgroundColor: Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
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
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_rounded, color: Color(0xFFF59E0B), size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Rate Khusus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)), Text(name, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w400))])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8F8FB), borderRadius: BorderRadius.circular(10)), child: Row(children: [const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9CA3AF)), const SizedBox(width: 8), Expanded(child: Text('Kosongkan untuk pakai rate global (Rp ${_formatRupiah(_globalRate)})', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))))])),
            const SizedBox(height: 16),
            TextField(
              controller: controller, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(hintText: 'Kosongkan = pakai global', hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.w400), prefixText: 'Rp ', prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)), suffixText: '= 1 poin', suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)), filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5))),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          if (currentRate != null) TextButton(onPressed: () => Navigator.pop(context, 'CLEAR'), child: const Text('Hapus Khusus', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isEmpty) { Navigator.pop(context, 'CLEAR'); return; }
              if (int.tryParse(val) == null || int.parse(val) <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan angka valid'), backgroundColor: Color(0xFFEF4444))); return; }
              Navigator.pop(context, val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result == 'CLEAR' ? 'Rate khusus dihapus' : 'Rate khusus diupdate'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
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

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ======= HEADER =======
            const Text('Konversi Poin', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 4),
            const Text('Atur rasio nilai tukar (Rupiah ke Poin) untuk toko.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            const SizedBox(height: 24),

            // ======= DESAIN RESPONSIF HERO CARD =======
            // Di Laptop: Berjejer kiri (Global) dan Kanan (Simulasi) agar full width.
            // Di HP: Susun atas bawah.
            if (isDesktop)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: _buildGlobalRateCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildSimulationCard()),
                  ],
                ),
              )
            else
              Column(
                children: [
                  _buildGlobalRateCard(),
                  const SizedBox(height: 12),
                  _buildSimulationCard(),
                ],
              ),
            
            const SizedBox(height: 40),

            // ======= PER USER RATES =======
            Row(
              children: [
                const Expanded(
                  child: Text('Rate Per Toko / User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                  child: Text('${_approvedUsers.length} user', style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_approvedUsers.isEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF3F4F6))),
                child: const Column(children: [Icon(Icons.store_outlined, size: 48, color: Color(0xFFD1D5DB)), SizedBox(height: 12), Text('Belum ada toko yang di-approve.', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14))]),
              )
            else if (isDesktop)
              _buildDesktopTable()
            else
              _buildMobileList(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HERO: KARTU GLOBAL RATE ---
  Widget _buildGlobalRateCard() {
    return GestureDetector(
      onTap: _editGlobalRate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.public_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('Rate Utama (Global)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rp ${_formatRupiah(_globalRate)}',
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.0),
                ),
                const SizedBox(height: 4),
                Text(
                  '= 1 poin (Berlaku otomatis untuk semua user)',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HERO: KARTU SIMULASI ---
  Widget _buildSimulationCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calculate_rounded, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Simulasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Contoh Faktur: Rp 5.000.000', style: TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('÷ ${_formatRupiah(_globalRate)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E40AF))),
              const Divider(color: Color(0xFFBAE6FD), height: 24, thickness: 1.5),
              Text(
                '= ${(5000000 / (int.tryParse(_globalRate) ?? 10000)).floor()} Poin',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
              ),
            ],
          ),
        ],
      ),
    );
  }

// --- TABEL UNTUK DESKTOP ---
  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // RAHASIANYA DI SINI: Kita hitung pasti sisa ruang kosong.
            // Angka 450 adalah perkiraan lebar untuk 3 kolom lainnya (Status, Nilai, Aksi) + jarak antar kolom.
            // Kolom pertama (Nama Toko) akan dipaksa melebar memakan sisa ruang tersebut.
            final double firstColWidth = (constraints.maxWidth - 450).clamp(200.0, double.infinity);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                // Memaksa background abu-abu tabel penuh 100% mengikuti lebar layar
                constraints: BoxConstraints(minWidth: constraints.maxWidth), 
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 64,
                  horizontalMargin: 24,
                  columnSpacing: 32,
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: firstColWidth, // Memaksa judul kolom melar
                        child: const Text('Nama Toko / User', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                      ),
                    ),
                    const DataColumn(label: Text('Status Rate', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    const DataColumn(label: Text('Nilai Konversi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                    const DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  ],
                  rows: _approvedUsers.map((user) {
                    final String name = user['full_name'] ?? 'Tanpa Nama';
                    final int? customRate = user['point_conversion_rate'];
                    final bool hasCustom = customRate != null;
                    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                    return DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: firstColWidth, // Memaksa isi baris melar
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: hasCustom ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                                  child: Center(child: Text(initial, style: TextStyle(fontWeight: FontWeight.w700, color: hasCustom ? const Color(0xFFD97706) : const Color(0xFF6B7280)))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E), fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasCustom ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hasCustom ? 'Spesial' : 'Global',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hasCustom ? const Color(0xFFD97706) : const Color(0xFF6B7280)),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            'Rp ${_formatRupiah(hasCustom ? customRate : _globalRate)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _editUserRate(user),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Edit Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F4F6),
                              foregroundColor: const Color(0xFF1A1A2E),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- LIST UNTUK MOBILE ---
  Widget _buildMobileList() {
    return Column(
      children: List.generate(_approvedUsers.length, (i) {
        final user = _approvedUsers[i];
        final String name = user['full_name'] ?? 'Tanpa Nama';
        final int? customRate = user['point_conversion_rate'];
        final bool hasCustom = customRate != null;
        final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hasCustom ? const Color(0xFFF59E0B).withOpacity(0.3) : const Color(0xFFF0F0F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: hasCustom ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(initial, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: hasCustom ? const Color(0xFFD97706) : const Color(0xFF6B7280))),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (hasCustom) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                            child: Text('Rp ${_formatRupiah(customRate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                          ),
                          const SizedBox(width: 8),
                          const Text('Rate Spesial', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
                        ] else ...[
                          Text('Rp ${_formatRupiah(_globalRate)} (Global)', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _editUserRate(user),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF4B5563)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
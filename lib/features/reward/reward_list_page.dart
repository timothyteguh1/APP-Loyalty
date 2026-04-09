import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/layout_state.dart'; // <-- IMPORT GLOBAL STATE
import 'detail_reward_page.dart';

class RewardListPage extends StatefulWidget {
  final String type;
  final String title;

  const RewardListPage({super.key, required this.type, required this.title});

  @override
  State<RewardListPage> createState() => _RewardListPageState();
}

class _RewardListPageState extends State<RewardListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;
  String? _error;

  // =======================================================================
  // LOGIKA DATA (TIDAK ADA YANG BERUBAH)
  // =======================================================================
  @override
  void initState() {
    super.initState();
    _fetchRewards();
  }

  Future<void> _fetchRewards() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final data = await _supabase
          .from('rewards')
          .select()
          .eq('type', widget.type)
          .eq('is_active', true)
          .order('points_required', ascending: true);

      if (!mounted) return;

      // Filter stok > 0 di client-side (aman dari null)
      final filtered = List<Map<String, dynamic>>.from(data).where((item) {
        final stock = (item['stock'] as num?)?.toInt() ?? 0;
        return stock > 0;
      }).toList();

      setState(() {
        _rewards = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Gagal memuat data. Tarik untuk refresh.';
      });
    }
  }

  // =======================================================================
  // UI RENDERER: MENDETEKSI MODE WEB / HP
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _fetchRewards, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white), child: const Text("Coba Lagi")),
                ]))
              : _rewards.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.card_giftcard_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      const Text("Belum ada hadiah tersedia.", style: TextStyle(color: Colors.grey)),
                    ]))
                  : ValueListenableBuilder<bool>(
                      valueListenable: LayoutState().isDesktopMode,
                      builder: (context, isDesktop, child) {
                        return RefreshIndicator(
                          color: const Color(0xFFD32F2F),
                          onRefresh: _fetchRewards,
                          // PENENTU LAYOUT: Web = Grid, HP = List
                          child: isDesktop ? _buildDesktopGrid() : _buildMobileList(),
                        );
                      },
                    ),
    );
  }

  // -------------------------------------------------------------------------
  // TAMPILAN MOBILE (ListView - Persis Seperti Kodemu Sebelumnya)
  // -------------------------------------------------------------------------
  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _rewards.length,
      itemBuilder: (context, index) {
        final item = _rewards[index];
        final stock = (item['stock'] as num?)?.toInt() ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['image_url'] ?? '', width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.image)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(item['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text('Stok: $stock', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.stars, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text("${item['points_required'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _navigateToDetail(item),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text("Klaim", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            ])),
          ]),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // TAMPILAN WEB/DESKTOP (GridView - Desain Kotak E-commerce)
  // -------------------------------------------------------------------------
  Widget _buildDesktopGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      // Mengatur ukuran dan jarak grid secara dinamis
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300, // Lebar maksimal 1 kotak adalah 300 pixel
        mainAxisExtent: 340,     // Tinggi pasti 1 kotak adalah 340 pixel
        crossAxisSpacing: 24,    // Jarak horizontal antar kotak
        mainAxisSpacing: 24,     // Jarak vertikal antar kotak
      ),
      itemCount: _rewards.length,
      itemBuilder: (context, index) {
        final item = _rewards[index];
        final stock = (item['stock'] as num?)?.toInt() ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian Atas: Gambar Full Width
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  item['image_url'] ?? '', 
                  width: double.infinity, 
                  height: 150, 
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: double.infinity, height: 150, color: Colors.grey[200], child: const Icon(Icons.image, size: 40, color: Colors.grey)),
                ),
              ),
              // Bagian Bawah: Detail Teks
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Text(item['description'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text('Sisa Stok: $stock', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.amber[50], shape: BoxShape.circle),
                            child: const Icon(Icons.stars, color: Colors.amber, size: 16),
                          ),
                          const SizedBox(width: 6),
                          Text("${item['points_required'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => _navigateToDetail(item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F), 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text("Klaim", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Fungsi navigasi yang sama persis agar kode lebih bersih
  Future<void> _navigateToDetail(Map<String, dynamic> item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailRewardPage(item: item)));
    // Refresh setelah kembali
    _fetchRewards();
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/layout_state.dart'; // <-- IMPORT GLOBAL STATE
import 'reward_list_page.dart';
import 'detail_reward_page.dart';

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final _supabase = Supabase.instance.client;

  int _currentPoints = 0;
  List<Map<String, dynamic>> _bestDeals = [];
  bool _isLoadingDeals = true;
  bool _isLoadingPoints = true;

  // =======================================================================
  // LOGIKA DATA (TIDAK ADA YANG BERUBAH)
  // =======================================================================
  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchPoints(), _fetchBestDeals()]);
  }

  Future<void> _fetchPoints() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase.from('profiles').select('points').eq('id', userId).maybeSingle();
      if (mounted && data != null) {
        setState(() {
          _currentPoints = (data['points'] as num?)?.toInt() ?? 0;
          _isLoadingPoints = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPoints = false);
    }
  }

  Future<void> _fetchBestDeals() async {
    try {
      final data = await _supabase
          .from('rewards')
          .select()
          .eq('is_active', true)
          .order('points_required', ascending: true)
          .limit(1);

      if (mounted) {
        final filtered = List<Map<String, dynamic>>.from(data).where((item) {
          return ((item['stock'] as num?)?.toInt() ?? 0) > 0;
        }).toList();

        setState(() {
          _bestDeals = filtered;
          _isLoadingDeals = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDeals = false);
    }
  }

  // =======================================================================
  // UI RENDERER: MENDETEKSI MODE WEB / HP
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: RefreshIndicator(
            color: const Color(0xFFD32F2F),
            onRefresh: _fetchAll,
            // Jika Desktop, bungkus dengan Center agar tidak melebar ke ujung layar
            child: isDesktop ? Center(child: _buildContent(isDesktop: true)) : _buildContent(isDesktop: false),
          ),
        );
      },
    );
  }

  // =======================================================================
  // KONTEN UTAMA (Satu Kode untuk Keduanya, hanya dibatasi lebarnya di Web)
  // =======================================================================
  Widget _buildContent({required bool isDesktop}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 120),
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        // BATAS LEBAR: Jika Web maksimal 800px, jika HP bebas (karena layar HP kecil)
        constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
        child: Column(
          children: [
            // --- HEADER & CARD POIN ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 200, width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Reward", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text("Scan QR Code untuk mendapatkan poin.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
                Positioned(
                  top: 130, left: 24, right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Poin anda saat ini", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _isLoadingPoints
                            ? const Text("... Points", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))
                            : Text("$_currentPoints Points", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                        InkWell(
                          onTap: () async {
                            await _fetchPoints();
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saldo diperbarui"), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFD32F2F).withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.refresh, color: Color(0xFFD32F2F), size: 20),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 90),

            // --- TUKAR POIN ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Tukar Poin", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  _catCard("Voucher", Icons.confirmation_number_outlined, Colors.red[50]!, () {
                    navigateTo(context, const RewardListPage(type: 'VOUCHER', title: 'Voucher'));
                  }),
                  const SizedBox(width: 16),
                  _catCard("Produk", Icons.inventory_2_outlined, Colors.red[50]!, () {
                    navigateTo(context, const RewardListPage(type: 'PRODUCT', title: 'Produk'));
                  }),
                ]),
              ]),
            ),
            const SizedBox(height: 30),

            // --- BEST DEAL ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Best Deal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _isLoadingDeals
                    ? Container(
                        width: double.infinity, padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
                      )
                    : _bestDeals.isEmpty
                        ? Container(
                            width: double.infinity, padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: const Text("Nantikan promo menarik segera!", style: TextStyle(color: Colors.grey)),
                          )
                        : _dealCard(_bestDeals[0]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dealCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Image.asset('assets/images/logo.png', height: 20, errorBuilder: (c, e, s) => const Icon(Icons.local_offer, color: Colors.red, size: 20)),
          const SizedBox(width: 8),
          const Text("UPSOL OFFICIAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),
        Text(item['description'] ?? item['name'] ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.amber[50], shape: BoxShape.circle), child: const Icon(Icons.stars, color: Colors.amber, size: 18)),
            const SizedBox(width: 8),
            Text("${item['points_required'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ]),
          ElevatedButton(
            onPressed: () => navigateTo(context, DetailRewardPage(item: item)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), elevation: 0),
            child: const Text("Klaim", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }

  Widget _catCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(color: Colors.white, borderRadius: BorderRadius.circular(16),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
            child: Row(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: const Color(0xFFD32F2F), size: 20)),
            ]),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui_helpers.dart'; // [PENTING] Import Helper
import 'reward_list_page.dart';
import 'detail_reward_page.dart';

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final _supabase = Supabase.instance.client;

  // Fungsi Refresh Manual
  void _refreshPoints() {
    setState(() {}); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saldo poin diperbarui"), 
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        // [PADDING BAWAH] Agar konten tidak ketutup tombol Scan QR di Home
        padding: const EdgeInsets.only(bottom: 120), 
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // --- HEADER MERAH & CARD POIN ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Merah
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Reward", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text("Scan QR Code untuk mendapatkan poin.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                
                // CARD POIN (Melayang)
                Positioned(
                  top: 130, left: 24, right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Poin anda saat ini", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Stream Poin Realtime
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user?.id ?? ''),
                              builder: (context, snapshot) {
                                String points = "0";
                                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                  points = snapshot.data![0]['points'].toString();
                                }
                                return Text("$points Points", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900));
                              },
                            ),
                            
                            // Tombol Refresh
                            InkWell(
                              onTap: _refreshPoints,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32F2F).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.refresh, color: Color(0xFFD32F2F), size: 20),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Spasi untuk kompensasi Card yang melayang
            const SizedBox(height: 90),

            // --- MENU TUKAR POIN ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tukar Poin", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // [NAVIGASI ANIMASI] Menggunakan navigateTo
                      _buildCategoryCard("Voucher", Icons.confirmation_number_outlined, Colors.red[50]!, () {
                        navigateTo(context, const RewardListPage(type: 'VOUCHER', title: 'Voucher'));
                      }),
                      const SizedBox(width: 16),
                      _buildCategoryCard("Produk", Icons.inventory_2_outlined, Colors.red[50]!, () {
                        navigateTo(context, const RewardListPage(type: 'PRODUCT', title: 'Produk'));
                      }),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- BEST DEAL SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text("Best Deal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 12),
                   
                   // Stream Builder untuk Best Deal Item
                   StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _supabase
                        .from('rewards')
                        .stream(primaryKey: ['id'])
                        .map((items) => items.where((i) => i['name'].toString().contains('Oli Matic Impero') && i['type'] == 'VOUCHER').take(1).toList()),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                         // Fallback jika tidak ada promo oli
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: const Text("Nantikan promo menarik segera!", style: TextStyle(color: Colors.grey)),
                        );
                      }

                      final item = snapshot.data![0];

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo Brand
                            Row(
                              children: [
                                Image.asset('assets/images/logo.png', height: 20, errorBuilder: (c,e,s) => const Icon(Icons.local_offer, color: Colors.red, size: 20)),
                                const SizedBox(width: 8),
                                const Text("UPSOL OFFICIAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Judul Promo
                            Text(
                              item['description'] ?? item['name'], 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.3),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 16),

                            // Harga & Tombol
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.amber[50], shape: BoxShape.circle),
                                      child: const Icon(Icons.stars, color: Colors.amber, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${item['points_required']}",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    // [NAVIGASI ANIMASI] Ke Detail
                                    navigateTo(context, DetailRewardPage(item: item));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                    elevation: 0,
                                  ),
                                  child: const Text("Klaim", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: const Color(0xFFD32F2F), size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
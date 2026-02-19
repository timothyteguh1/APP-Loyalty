import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import halaman list yang akan kita buat nanti
import 'reward_list_page.dart';
// import 'reward_list_page.dart';

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});

  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER MERAH & CARD POIN ---
            Stack(
              clipBehavior: Clip.none,
              children: [
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
                      Text(
                        "Reward",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Scan QR Code untuk mendapatkan poin.",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // CARD POIN
                Positioned(
                  top: 130,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Poin anda saat ini",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _supabase
                                  .from('profiles')
                                  .stream(primaryKey: ['id'])
                                  .eq('id', user?.id ?? ''),
                              builder: (context, snapshot) {
                                String points = "0";
                                if (snapshot.hasData &&
                                    snapshot.data!.isNotEmpty) {
                                  points = snapshot.data![0]['points']
                                      .toString();
                                }
                                return Text(
                                  "$points Points",
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                );
                              },
                            ),
                            const CircleAvatar(
                              backgroundColor: Color(0xFFD32F2F),
                              child: Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 80),

            // --- MENU TUKAR POIN (VOUCHER & PRODUK) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tukar Poin",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildCategoryCard(
                        "Voucher",
                        Icons.confirmation_number_outlined,
                        Colors.red[50]!,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RewardListPage(
                                type: 'VOUCHER',
                                title: 'Voucher',
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 16),

                      _buildCategoryCard(
                        "Produk",
                        Icons.inventory_2_outlined,
                        Colors.red[50]!,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RewardListPage(
                                type: 'PRODUCT',
                                title: 'Produk',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- BEST DEAL (DUMMY) ---
            const Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Best Deal",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Nanti di sini kita buat widget card item tunggal
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFFD32F2F), size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

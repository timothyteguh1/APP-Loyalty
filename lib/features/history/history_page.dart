import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _supabase = Supabase.instance.client;

  // Fungsi Refresh Manual
  void _refreshHistory() {
    setState(() {}); 
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Riwayat diperbarui"), duration: Duration(seconds: 1)),
    );
  }

  String _formatDate(String dateString) {
    try {
      DateTime dt = DateTime.parse(dateString).toLocal();
      List<String> months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // HEADER MERAH
          Container(
            height: 220,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("History", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Riwayat scan dan penggunaan poin", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),

          // CARD POIN
          Positioned(
            top: 130, left: 24, right: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Poin anda saat ini", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', user?.id ?? ''),
                        builder: (context, snapshot) {
                          String points = "...";
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            points = snapshot.data![0]['points'].toString();
                          }
                          return Text("$points Points", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900));
                        },
                      ),
                      
                      // TOMBOL REFRESH
                      InkWell(
                        onTap: _refreshHistory,
                        borderRadius: BorderRadius.circular(20),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFFD32F2F),
                          child: Icon(Icons.refresh, color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),

          // LIST HISTORY
          Padding(
            padding: const EdgeInsets.only(top: 250),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase.from('point_history').stream(primaryKey: ['id']).eq('user_id', user?.id ?? '').order('created_at'), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada riwayat", style: TextStyle(color: Colors.grey)));

                final historyList = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final item = historyList[index];
                    final int amount = item['amount'];
                    final bool isPositive = amount > 0;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['description'] ?? 'Transaksi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(_formatDate(item['created_at']), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            isPositive ? "+$amount" : "$amount",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isPositive ? Colors.green : const Color(0xFFD32F2F)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
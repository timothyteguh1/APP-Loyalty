import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../admin_supabase.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with SingleTickerProviderStateMixin {
  final _admin = AdminSupabase.client;
  late TabController _tabController;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyData = [];
  
  // Tab 2 (Pendapatan)
  String _searchInQuery = '';
  final _searchInCtrl = TextEditingController();

  // Tab 3 (Penukaran)
  String _searchOutQuery = '';
  String? _selectedItemFilter;
  List<String> _redeemedItems = [];
  final _searchOutCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchInCtrl.dispose();
    _searchOutCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      // Mengambil data riwayat dan join dengan nama dari tabel profiles
      final response = await _admin
          .from('point_history')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);

      if (mounted) {
        final data = List<Map<String, dynamic>>.from(response);
        
        // Ekstrak nama unik dari barang yang ditukar (untuk filter Tab 3)
        final Set<String> items = {};
        for (var item in data) {
          final int amount = (item['amount'] as num?)?.toInt() ?? 0;
          if (amount < 0) {
            // Asumsi deskripsi penukaran mengandung nama barang, atau kita ambil dari deskripsi
            items.add(item['description'] ?? 'Lainnya');
          }
        }

        setState(() {
          _historyData = data;
          _redeemedItems = items.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  // FUNGSI CUT OFF 1 JANUARI
  Future<void> _resetAnnualPoints() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Reset Poin Tahunan', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Text(
          'Tindakan ini akan MENGHANGUSKAN (menjadi 0) semua poin milik seluruh toko saat ini sesuai aturan Cut Off 1 Januari.\n\nApakah Anda sangat yakin?',
          style: TextStyle(height: 1.5, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0),
            child: const Text('Ya, Reset Poin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // 1. Ambil semua user yang punya poin > 0
      final users = await _admin.from('profiles').select('id, points').gt('points', 0);
      
      // 2. Reset semua poin jadi 0 di tabel profiles
      await _admin.from('profiles').update({'points': 0}).neq('id', 'dummy'); // Update massal
      
      // 3. Catat di riwayat agar ada jejak audit
      final List<Map<String, dynamic>> historyLogs = [];
      final now = DateTime.now().toIso8601String();
      for (var u in users) {
        historyLogs.add({
          'user_id': u['id'],
          'amount': -(u['points'] as num).toInt(),
          'description': 'Cut Off Poin Tahunan (1 Januari)',
          'reference_type': 'SYSTEM_RESET',
          'created_at': now,
        });
      }
      if (historyLogs.isNotEmpty) {
        await _admin.from('point_history').insert(historyLogs);
      }

      await _fetchReportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poin tahunan berhasil direset!'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal reset: $e'), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E))),
        title: const Text('Laporan & Analytics', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFB71C1C),
          labelColor: const Color(0xFFB71C1C),
          unselectedLabelColor: Colors.grey[500],
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Pendapatan'),
            Tab(text: 'Penukaran'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildIncomeTab(),
                _buildRedeemTab(),
              ],
            ),
    );
  }

  // ================= TAB 1: DASHBOARD =================
  Widget _buildDashboardTab() {
    int totalIn = 0;
    int totalOut = 0;
    Map<String, int> itemStats = {};

    for (var item in _historyData) {
      final int amount = (item['amount'] as num?)?.toInt() ?? 0;
      if (amount > 0) {
        totalIn += amount;
      } else if (amount < 0) {
        totalOut += amount.abs();
        final desc = item['description'] ?? 'Lainnya';
        itemStats[desc] = (itemStats[desc] ?? 0) + 1; // Menghitung jumlah kali ditukar
      }
    }

    // Urutkan barang paling sering ditukar
    var sortedItems = itemStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cards Highlight
          Row(
            children: [
              Expanded(child: _statCard('Total Poin Masuk', '+$totalIn', const Color(0xFF10B981), Icons.arrow_downward_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Total Poin Ditukar', '-$totalOut', const Color(0xFFEF4444), Icons.arrow_upward_rounded)),
            ],
          ),
          const SizedBox(height: 24),

          // Poin Cut Off Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFCA5A5))),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.date_range_rounded, color: Color(0xFFEF4444))),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tutup Buku Tahunan', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
                      Text('Reset semua poin toko menjadi 0', style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _resetAnnualPoints,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0, foregroundColor: Colors.white),
                  child: const Text('Eksekusi'),
                )
              ],
            ),
          ),
          const SizedBox(height: 32),

          const Text('Top Hadiah Ditukar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          if (sortedItems.isEmpty)
            const Text('Belum ada data penukaran hadiah.', style: TextStyle(color: Colors.grey))
          else
            ...sortedItems.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF6B7280), size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                  Text('${e.value}x Ditukar', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB71C1C))),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ================= TAB 2: PENDAPATAN (POIN MASUK) =================
  Widget _buildIncomeTab() {
    final incomeData = _historyData.where((item) {
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      if (amount <= 0) return false;
      
      if (_searchInQuery.isEmpty) return true;
      final name = (item['profiles']?['full_name'] ?? '').toString().toLowerCase();
      return name.contains(_searchInQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchInCtrl,
            onChanged: (v) => setState(() => _searchInQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama toko...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: incomeData.isEmpty
              ? const Center(child: Text('Tidak ada data pendapatan poin.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: incomeData.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (ctx, i) => _historyTile(incomeData[i], true),
                ),
        ),
      ],
    );
  }

  // ================= TAB 3: PENUKARAN (POIN KELUAR) =================
  Widget _buildRedeemTab() {
    final redeemData = _historyData.where((item) {
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      if (amount >= 0) return false;
      
      final name = (item['profiles']?['full_name'] ?? '').toString().toLowerCase();
      final desc = item['description'] ?? '';

      // Text Search Filter
      if (_searchOutQuery.isNotEmpty && !name.contains(_searchOutQuery.toLowerCase())) return false;
      
      // Dropdown Item Filter
      if (_selectedItemFilter != null && _selectedItemFilter != 'Semua Barang' && desc != _selectedItemFilter) return false;

      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchOutCtrl,
                  onChanged: (v) => setState(() => _searchOutQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari toko...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // FILTER BARANG
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedItemFilter,
                  decoration: InputDecoration(
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  hint: const Text('Semua Barang', style: TextStyle(fontSize: 13)),
                  isExpanded: true,
                  icon: const Icon(Icons.filter_list_rounded, size: 20),
                  items: ['Semua Barang', ..._redeemedItems].map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedItemFilter = newValue == 'Semua Barang' ? null : newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: redeemData.isEmpty
              ? const Center(child: Text('Tidak ada riwayat penukaran sesuai filter.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: redeemData.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemBuilder: (ctx, i) => _historyTile(redeemData[i], false),
                ),
        ),
      ],
    );
  }

  // WIDGET TILE UNTUK LIST
  Widget _historyTile(Map<String, dynamic> item, bool isIn) {
    final amount = (item['amount'] as num?)?.toInt() ?? 0;
    final name = item['profiles']?['full_name'] ?? 'User Tidak Diketahui';
    final desc = item['description'] ?? '-';
    
    String dateStr = '';
    if (item['created_at'] != null) {
      final dt = DateTime.parse(item['created_at']).toLocal();
      dateStr = DateFormat('dd MMM yyyy, HH:mm').format(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isIn ? Icons.arrow_downward_rounded : Icons.card_giftcard_rounded, color: isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(dateStr, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isIn ? '+$amount' : '$amount',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
          )
        ],
      ),
    );
  }
}
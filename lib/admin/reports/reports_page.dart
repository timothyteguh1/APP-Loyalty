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
  
  String _searchInQuery = '';
  final _searchInCtrl = TextEditingController();
  DateTimeRange? _dateRangeIn;

  String _searchOutQuery = '';
  String? _selectedItemFilter;
  List<String> _redeemedItems = [];
  final _searchOutCtrl = TextEditingController();
  DateTimeRange? _dateRangeOut;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchReportData();
  }

  @override
  void dispose() { _tabController.dispose(); _searchInCtrl.dispose(); _searchOutCtrl.dispose(); super.dispose(); }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _admin.from('point_history').select('*, profiles(full_name)').order('created_at', ascending: false);
      if (mounted) {
        final data = List<Map<String, dynamic>>.from(response);
        final Set<String> items = {};
        for (var item in data) { if ((item['amount'] as num? ?? 0) < 0) items.add(item['description'] ?? 'Lainnya'); }
        setState(() { _historyData = data; _redeemedItems = items.toList()..sort(); _isLoading = false; });
      }
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e'), backgroundColor: const Color(0xFFEF4444))); }
    }
  }

  Future<void> _pickDateRange(bool isIncome) async {
    final now = DateTime.now();
    final initial = isIncome ? _dateRangeIn : _dateRangeOut;
    final result = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: now, initialDateRange: initial ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFFB71C1C), onPrimary: Colors.white, surface: Colors.white)), child: child!));
    if (result != null) setState(() { if (isIncome) { _dateRangeIn = result; } else { _dateRangeOut = result; } });
  }

  // [FIX] Reset tahunan sekarang pakai RPC — tidak lagi error PostgreSQL
  Future<void> _resetAnnualPoints() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [Icon(Icons.warning_rounded, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Reset Poin Tahunan', style: TextStyle(fontWeight: FontWeight.w700))]),
      content: const Text('Tindakan ini akan MENGHANGUSKAN (menjadi 0) semua poin milik seluruh toko saat ini sesuai aturan Cut Off 1 Januari.\n\nApakah Anda sangat yakin?', style: TextStyle(height: 1.5, color: Color(0xFF4B5563))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0), child: const Text('Ya, Reset Poin', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // [FIX] Gunakan RPC function yang sudah dibuat di migration
      final result = await _admin.rpc('admin_annual_reset');
      
      await _fetchReportData();
      
      if (mounted) {
        final message = result?['message'] ?? 'Reset berhasil';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF10B981)));
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
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Laporan & Analytics', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w800, fontSize: 24)),
                const SizedBox(height: 4),
                const Text('Rekapitulasi pendapatan dan penukaran poin.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                  padding: const EdgeInsets.all(6),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    indicatorSize: TabBarIndicatorSize.tab, dividerColor: Colors.transparent,
                    labelColor: const Color(0xFFB71C1C), unselectedLabelColor: Colors.grey[500],
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    tabs: const [Tab(text: 'Dashboard'), Tab(text: 'Pendapatan'), Tab(text: 'Penukaran')],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
                  : TabBarView(controller: _tabController, children: [_buildDashboardTab(), _buildIncomeTab(), _buildRedeemTab()]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    int totalIn = 0; int totalOut = 0; Map<String, int> itemStats = {};
    for (var item in _historyData) {
      final int amount = (item['amount'] as num?)?.toInt() ?? 0;
      if (amount > 0) { totalIn += amount; } else if (amount < 0) { totalOut += amount.abs(); final desc = item['description'] ?? 'Lainnya'; itemStats[desc] = (itemStats[desc] ?? 0) + 1; }
    }
    var sortedItems = itemStats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _statCard('Total Poin Masuk', '+$totalIn', const Color(0xFF10B981), Icons.arrow_downward_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Total Poin Ditukar', '-$totalOut', const Color(0xFFEF4444), Icons.arrow_upward_rounded)),
      ]),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFCA5A5))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.date_range_rounded, color: Color(0xFFEF4444))),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tutup Buku Tahunan', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF991B1B))),
            Text('Reset semua poin toko menjadi 0', style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
          ])),
          ElevatedButton(onPressed: _resetAnnualPoints, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0, foregroundColor: Colors.white), child: const Text('Eksekusi')),
        ]),
      ),
      const SizedBox(height: 32),
      const Text('Top Hadiah Ditukar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 12),
      if (sortedItems.isEmpty) const Text('Belum ada data penukaran hadiah.', style: TextStyle(color: Colors.grey))
      else ...sortedItems.take(10).map((e) => Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF6B7280), size: 20)), const SizedBox(width: 12), Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)), Text('${e.value}x', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB71C1C)))]),
      )),
    ]));
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500))]),
        const SizedBox(height: 12), Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      ]));
  }

  Widget _buildIncomeTab() {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    final incomeData = _historyData.where((item) {
      if ((item['amount'] as num? ?? 0) <= 0) return false;
      if (_searchInQuery.isNotEmpty) { final name = (item['profiles']?['full_name'] ?? '').toString().toLowerCase(); if (!name.contains(_searchInQuery.toLowerCase())) return false; }
      if (_dateRangeIn != null && item['created_at'] != null) { try { final dt = DateTime.parse(item['created_at']).toLocal(); if (dt.isBefore(_dateRangeIn!.start) || dt.isAfter(_dateRangeIn!.end.add(const Duration(days: 1)))) return false; } catch (_) {} }
      return true;
    }).toList();
    return Column(children: [
      _buildFilterBar(searchCtrl: _searchInCtrl, searchQuery: _searchInQuery, onSearchChanged: (v) => setState(() => _searchInQuery = v), dateRange: _dateRangeIn, onPickDate: () => _pickDateRange(true), onClearDate: () => setState(() => _dateRangeIn = null), resultCount: incomeData.length),
      Expanded(child: incomeData.isEmpty ? const Center(child: Text('Tidak ada data pendapatan poin.', style: TextStyle(color: Colors.grey))) : isDesktop ? _buildDesktopTable(incomeData, true) : ListView.builder(itemCount: incomeData.length, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemBuilder: (ctx, i) => _historyTile(incomeData[i], true))),
    ]);
  }

  Widget _buildRedeemTab() {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    final redeemData = _historyData.where((item) {
      if ((item['amount'] as num? ?? 0) >= 0) return false;
      final name = (item['profiles']?['full_name'] ?? '').toString().toLowerCase();
      final desc = item['description'] ?? '';
      if (_searchOutQuery.isNotEmpty && !name.contains(_searchOutQuery.toLowerCase())) return false;
      if (_selectedItemFilter != null && _selectedItemFilter != 'Semua Barang' && desc != _selectedItemFilter) return false;
      if (_dateRangeOut != null && item['created_at'] != null) { try { final dt = DateTime.parse(item['created_at']).toLocal(); if (dt.isBefore(_dateRangeOut!.start) || dt.isAfter(_dateRangeOut!.end.add(const Duration(days: 1)))) return false; } catch (_) {} }
      return true;
    }).toList();
    return Column(children: [
      _buildFilterBar(searchCtrl: _searchOutCtrl, searchQuery: _searchOutQuery, onSearchChanged: (v) => setState(() => _searchOutQuery = v), dateRange: _dateRangeOut, onPickDate: () => _pickDateRange(false), onClearDate: () => setState(() => _dateRangeOut = null), resultCount: redeemData.length,
        extraWidget: SizedBox(width: 180, child: DropdownButtonFormField<String>(value: _selectedItemFilter, decoration: InputDecoration(filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), hint: const Text('Semua Barang', style: TextStyle(fontSize: 13)), isExpanded: true, icon: const Icon(Icons.filter_list_rounded, size: 18), items: ['Semua Barang', ..._redeemedItems].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _selectedItemFilter = v == 'Semua Barang' ? null : v)))),
      Expanded(child: redeemData.isEmpty ? const Center(child: Text('Tidak ada riwayat penukaran.', style: TextStyle(color: Colors.grey))) : isDesktop ? _buildDesktopTable(redeemData, false) : ListView.builder(itemCount: redeemData.length, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemBuilder: (ctx, i) => _historyTile(redeemData[i], false))),
    ]);
  }

  Widget _buildFilterBar({required TextEditingController searchCtrl, required String searchQuery, required ValueChanged<String> onSearchChanged, required DateTimeRange? dateRange, required VoidCallback onPickDate, required VoidCallback onClearDate, required int resultCount, Widget? extraWidget}) {
    final fmt = DateFormat('dd MMM yyyy');
    return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Column(children: [
      Row(children: [
        Expanded(child: TextField(controller: searchCtrl, onChanged: onSearchChanged, decoration: InputDecoration(hintText: 'Cari nama toko...', hintStyle: const TextStyle(fontSize: 13), prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20), suffixIcon: searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { searchCtrl.clear(); onSearchChanged(''); }) : null, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
        const SizedBox(width: 10),
        GestureDetector(onTap: onPickDate, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), decoration: BoxDecoration(color: dateRange != null ? const Color(0xFFB71C1C).withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: dateRange != null ? const Color(0xFFB71C1C).withOpacity(0.3) : Colors.transparent)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.date_range_rounded, size: 18, color: dateRange != null ? const Color(0xFFB71C1C) : Colors.grey), const SizedBox(width: 6), Text(dateRange != null ? '${fmt.format(dateRange.start)} - ${fmt.format(dateRange.end)}' : 'Tanggal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dateRange != null ? const Color(0xFFB71C1C) : const Color(0xFF6B7280))), if (dateRange != null) ...[const SizedBox(width: 6), GestureDetector(onTap: onClearDate, child: const Icon(Icons.close, size: 16, color: Color(0xFFB71C1C)))]]))),
        if (extraWidget != null) ...[const SizedBox(width: 10), extraWidget],
      ]),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Text('$resultCount hasil', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        if (dateRange != null || searchQuery.isNotEmpty) ...[const SizedBox(width: 8), GestureDetector(onTap: () { searchCtrl.clear(); onSearchChanged(''); onClearDate(); }, child: const Text('Reset filter', style: TextStyle(fontSize: 12, color: Color(0xFFB71C1C), fontWeight: FontWeight.w600)))],
      ])),
    ]));
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> data, bool isIn) {
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), child: Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: ConstrainedBox(constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 290),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)), dataRowMinHeight: 64, dataRowMaxHeight: 64, horizontalMargin: 24, columnSpacing: 32,
          columns: const [
            DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
            DataColumn(label: Expanded(child: Text('Nama Toko', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
            DataColumn(label: Expanded(child: Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
            DataColumn(label: Text('Jumlah Poin', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
          ],
          rows: data.map((item) {
            final amount = (item['amount'] as num?)?.toInt() ?? 0;
            final name = item['profiles']?['full_name'] ?? '-';
            final desc = item['description'] ?? '-';
            String dateStr = '';
            if (item['created_at'] != null) { final dt = DateTime.parse(item['created_at']).toLocal(); dateStr = DateFormat('dd MMM yyyy, HH:mm').format(dt); }
            return DataRow(cells: [
              DataCell(Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
              DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
              DataCell(Text(desc, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
              DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(isIn ? '+$amount' : '$amount', style: TextStyle(fontWeight: FontWeight.w800, color: isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444))))),
            ]);
          }).toList(),
        ))))));
  }

  Widget _historyTile(Map<String, dynamic> item, bool isIn) {
    final amount = (item['amount'] as num?)?.toInt() ?? 0;
    final name = item['profiles']?['full_name'] ?? '-';
    final desc = item['description'] ?? '-';
    String dateStr = '';
    if (item['created_at'] != null) { final dt = DateTime.parse(item['created_at']).toLocal(); dateStr = DateFormat('dd MMM yyyy, HH:mm').format(dt); }
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: (isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isIn ? Icons.arrow_downward_rounded : Icons.card_giftcard_rounded, color: isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 4), Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(dateStr, style: TextStyle(color: Colors.grey[400], fontSize: 11))])),
        const SizedBox(width: 10),
        Text(isIn ? '+$amount' : '$amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
      ]));
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_supabase.dart';

class AdminManagePage extends StatefulWidget {
  const AdminManagePage({super.key});

  @override
  State<AdminManagePage> createState() => _AdminManagePageState();
}

class _AdminManagePageState extends State<AdminManagePage> with SingleTickerProviderStateMixin {
  final _admin = AdminSupabase.client;
  late TabController _tabController;

  // Admin list
  List<String> _adminEmails = [];
  bool _isLoading = true;

  // Activity log
  List<Map<String, dynamic>> _logs = [];
  bool _isLoadingLogs = true;
  String _logSearch = '';
  final _logSearchCtrl = TextEditingController();

  // [NEW] Date range filter for log
  DateTimeRange? _logDateRange;

  // [NEW] Store name filter
  String? _selectedStoreName;
  List<String> _storeNames = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAdmins();
    _fetchLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _logSearchCtrl.dispose();
    super.dispose();
  }

  // ======= FETCH ADMIN LIST =======
  Future<void> _fetchAdmins() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin.from('app_config').select('value').eq('key', 'admin_emails').maybeSingle();
      if (mounted) {
        final String raw = data?['value'] ?? '';
        setState(() {
          _adminEmails = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ======= FETCH ACTIVITY LOG =======
  Future<void> _fetchLogs() async {
    setState(() => _isLoadingLogs = true);
    try {
      final data = await _admin
          .from('point_history')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(200);
      if (mounted) {
        final logs = List<Map<String, dynamic>>.from(data);
        // Extract unique store names for filter dropdown
        final Set<String> names = {};
        for (var item in logs) {
          final name = item['profiles']?['full_name']?.toString() ?? '';
          if (name.isNotEmpty) names.add(name);
        }
        setState(() {
          _logs = logs;
          _storeNames = names.toList()..sort();
          _isLoadingLogs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLogs = false);
    }
  }

  // ======= DATE RANGE PICKER =======
  Future<void> _pickLogDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _logDateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFFB71C1C), onPrimary: Colors.white, surface: Colors.white)),
        child: child!,
      ),
    );
    if (result != null) setState(() => _logDateRange = result);
  }

  // ======= ADD ADMIN =======
  Future<void> _addAdmin() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.person_add_rounded, color: Color(0xFF3B82F6), size: 20)),
          const SizedBox(width: 12),
          const Text('Tambah Admin', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Masukkan email yang sudah terdaftar di Supabase Auth.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'admin@email.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              filled: true, fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final email = ctrl.text.trim().toLowerCase();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Email tidak valid'), backgroundColor: Color(0xFFEF4444)));
                return;
              }
              Navigator.pop(ctx, email);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Tambah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (_adminEmails.contains(result)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sudah terdaftar sebagai admin'), backgroundColor: Color(0xFFF59E0B)));
      return;
    }

    try {
      final newList = [..._adminEmails, result];
      await _admin.from('app_config').update({'value': newList.join(',')}).eq('key', 'admin_emails');
      _fetchAdmins();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$result ditambahkan sebagai admin'), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  // ======= REMOVE ADMIN =======
  Future<void> _removeAdmin(String email) async {
    if (_adminEmails.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal harus ada 1 admin'), backgroundColor: Color(0xFFF59E0B)));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Admin?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Yakin ingin menghapus "$email" dari daftar admin?', style: const TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0), child: const Text('Hapus', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final newList = _adminEmails.where((e) => e != email).toList();
      await _admin.from('app_config').update({'value': newList.join(',')}).eq('key', 'admin_emails');
      _fetchAdmins();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$email dihapus dari admin'), backgroundColor: const Color(0xFF10B981)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E))),
        title: const Text('Admin & Log', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFFB71C1C),
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Daftar Admin'), Tab(text: 'Log Aktivitas')],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(controller: _tabController, children: [
            _buildAdminTab(),
            _buildLogTab(),
          ]),
        ),
      ]),
    );
  }

  // ======= TAB 1: DAFTAR ADMIN =======
  Widget _buildAdminTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBAE6FD))),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF3B82F6)),
            SizedBox(width: 10),
            Expanded(child: Text('Admin yang terdaftar bisa login ke panel ini. Pastikan email sudah terdaftar di Supabase Auth.', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4))),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton.icon(
            onPressed: _addAdmin,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Tambah Admin Baru', style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF3B82F6), side: const BorderSide(color: Color(0xFF3B82F6)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        const SizedBox(height: 20),
        Text('${_adminEmails.length} Admin Terdaftar', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        ...List.generate(_adminEmails.length, (i) {
          final email = _adminEmails[i];
          final isFirst = i == 0;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 400 + i * 80),
            curve: Curves.easeOutCubic,
            builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: c)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isFirst ? const Color(0xFFB71C1C).withOpacity(0.2) : const Color(0xFFF0F0F0)),
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isFirst ? const Color(0xFFB71C1C).withOpacity(0.08) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(isFirst ? Icons.shield_rounded : Icons.person_rounded, color: isFirst ? const Color(0xFFB71C1C) : const Color(0xFF6B7280), size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text(isFirst ? 'Admin Utama' : 'Admin', style: TextStyle(fontSize: 11, color: isFirst ? const Color(0xFFB71C1C) : const Color(0xFF9CA3AF))),
                ])),
                if (!isFirst)
                  IconButton(
                    onPressed: () => _removeAdmin(email),
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Hapus admin',
                  ),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  // ======= TAB 2: LOG AKTIVITAS (WITH DATE + STORE FILTER) =======
  Widget _buildLogTab() {
    if (_isLoadingLogs) return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));

    final filtered = _logs.where((item) {
      // Text search
      if (_logSearch.isNotEmpty) {
        final name = (item['profiles']?['full_name'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        if (!name.contains(_logSearch.toLowerCase()) && !desc.contains(_logSearch.toLowerCase())) return false;
      }
      // Store name filter
      if (_selectedStoreName != null && _selectedStoreName!.isNotEmpty) {
        final name = item['profiles']?['full_name']?.toString() ?? '';
        if (name != _selectedStoreName) return false;
      }
      // Date range filter
      if (_logDateRange != null && item['created_at'] != null) {
        try {
          final dt = DateTime.parse(item['created_at']).toLocal();
          if (dt.isBefore(_logDateRange!.start) || dt.isAfter(_logDateRange!.end.add(const Duration(days: 1)))) return false;
        } catch (_) {}
      }
      return true;
    }).toList();

    final bool isDesktop = MediaQuery.of(context).size.width >= 800;
    final fmt = DateFormat('dd MMM yyyy');
    final bool hasActiveFilter = _logSearch.isNotEmpty || _logDateRange != null || _selectedStoreName != null;

    return Column(children: [
      // ======= FILTER BAR =======
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(children: [
          Row(children: [
            // Search
            Expanded(
              child: TextField(
                controller: _logSearchCtrl,
                onChanged: (v) => setState(() => _logSearch = v),
                decoration: InputDecoration(
                  hintText: 'Cari nama toko atau deskripsi...', hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                  suffixIcon: _logSearch.isNotEmpty ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { _logSearchCtrl.clear(); setState(() => _logSearch = ''); }) : null,
                  filled: true, fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // [NEW] Date picker button
            GestureDetector(
              onTap: _pickLogDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: _logDateRange != null ? const Color(0xFFB71C1C).withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _logDateRange != null ? const Color(0xFFB71C1C).withOpacity(0.3) : Colors.transparent),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.date_range_rounded, size: 18, color: _logDateRange != null ? const Color(0xFFB71C1C) : Colors.grey),
                  if (_logDateRange != null) ...[
                    const SizedBox(width: 6),
                    Text('${fmt.format(_logDateRange!.start)} - ${fmt.format(_logDateRange!.end)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFB71C1C))),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _logDateRange = null),
                      child: const Icon(Icons.close, size: 14, color: Color(0xFFB71C1C)),
                    ),
                  ],
                ]),
              ),
            ),
          ]),

          // [NEW] Store filter + result count row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Text('${filtered.length} aktivitas', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              if (hasActiveFilter) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () { _logSearchCtrl.clear(); setState(() { _logSearch = ''; _logDateRange = null; _selectedStoreName = null; }); },
                  child: const Text('Reset filter', style: TextStyle(fontSize: 12, color: Color(0xFFB71C1C), fontWeight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              // Store dropdown
              if (_storeNames.isNotEmpty)
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStoreName,
                    decoration: InputDecoration(filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                    hint: const Text('Semua Toko', style: TextStyle(fontSize: 12)),
                    isExpanded: true,
                    icon: const Icon(Icons.filter_list_rounded, size: 16),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Toko', style: TextStyle(fontSize: 12))),
                      ..._storeNames.map((n) => DropdownMenuItem(value: n, child: Text(n, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() => _selectedStoreName = v),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _fetchLogs,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF3B82F6)),
                  SizedBox(width: 4),
                  Text('Refresh', style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ]),
      ),

      // ======= LOG CONTENT =======
      Expanded(
        child: filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('Tidak ada log', style: TextStyle(color: Colors.grey)),
              ]))
            : isDesktop
                ? _buildLogTable(filtered)
                : RefreshIndicator(
                    color: const Color(0xFFB71C1C),
                    onRefresh: _fetchLogs,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _logTile(filtered[i], i),
                    ),
                  ),
      ),
    ]);
  }

  Widget _buildLogTable(List<Map<String, dynamic>> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 290),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
                dataRowMinHeight: 56, dataRowMaxHeight: 56,
                horizontalMargin: 24, columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Nama Toko', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  DataColumn(label: Expanded(child: Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  DataColumn(label: Text('Poin', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                ],
                rows: data.map((item) {
                  final amount = (item['amount'] as num?)?.toInt() ?? 0;
                  final name = item['profiles']?['full_name'] ?? '-';
                  final desc = item['description'] ?? '-';
                  final type = item['reference_type'] ?? 'MANUAL';
                  String dateStr = '';
                  if (item['created_at'] != null) dateStr = DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(item['created_at']).toLocal());
                  final isPos = amount > 0;

                  return DataRow(cells: [
                    DataCell(Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                    DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                    DataCell(_typeBadge(type)),
                    DataCell(Text(desc, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DataCell(Text('${isPos ? "+" : ""}$amount', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444)))),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logTile(Map<String, dynamic> item, int index) {
    final amount = (item['amount'] as num?)?.toInt() ?? 0;
    final isPos = amount > 0;
    final name = item['profiles']?['full_name'] ?? '-';
    final desc = item['description'] ?? '-';
    final type = item['reference_type'] ?? 'MANUAL';
    String dateStr = '';
    if (item['created_at'] != null) dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item['created_at']).toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3F4F6))),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: (isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Icon(isPos ? Icons.add_rounded : Icons.remove_rounded, color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            _typeBadge(type),
          ]),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFFD1D5DB))),
        ])),
        const SizedBox(width: 8),
        Text('${isPos ? "+" : ""}$amount', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
      ]),
    );
  }

  Widget _typeBadge(String type) {
    Color c; String label;
    switch (type) {
      case 'INVOICE': c = const Color(0xFF3B82F6); label = 'Faktur'; break;
      case 'REWARD_CLAIM': c = const Color(0xFFB71C1C); label = 'Klaim'; break;
      case 'SYSTEM_CUTOFF': c = const Color(0xFF6B7280); label = 'Cutoff'; break;
      case 'QR_SCAN': c = const Color(0xFF8B5CF6); label = 'QR'; break;
      default: c = const Color(0xFFF59E0B); label = 'Manual';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
    );
  }
}
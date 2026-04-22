import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_supabase.dart';

class VoucherManagePage extends StatefulWidget {
  const VoucherManagePage({super.key});

  @override
  State<VoucherManagePage> createState() => _VoucherManagePageState();
}

class _VoucherManagePageState extends State<VoucherManagePage> with SingleTickerProviderStateMixin {
  final _admin = AdminSupabase.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _allClaims = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchClaims();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchClaims() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin
          .from('user_rewards')
          .select('*, profiles(full_name, phone), rewards(name, type, points_required, image_url)')
          .order('claimed_at', ascending: false);

      if (mounted) {
        setState(() {
          _allClaims = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Gagal memuat data: $e', false);
      }
    }
  }

  List<Map<String, dynamic>> _filteredList(String status) {
    return _allClaims.where((c) {
      final matchStatus = c['status'] == status;
      if (_searchQuery.isEmpty) return matchStatus;
      final userName = (c['profiles']?['full_name'] ?? '').toString().toLowerCase();
      final rewardName = (c['rewards']?['name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return matchStatus && (userName.contains(q) || rewardName.contains(q));
    }).toList();
  }

  Future<void> _updateStatus(Map<String, dynamic> claim, String newStatus) async {
    final userName = claim['profiles']?['full_name'] ?? 'User';
    final rewardName = claim['rewards']?['name'] ?? 'Hadiah';
    final statusLabel = newStatus == 'USED' ? 'Berhasil Ditukar' : newStatus == 'EXPIRED' ? 'Kedaluwarsa' : 'Aktif';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _statusColor(newStatus).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon(newStatus), color: _statusColor(newStatus), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Ubah ke "$statusLabel"?', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('User: $userName', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('Hadiah: $rewardName', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _statusColor(newStatus), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Ya, Ubah', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final updateData = <String, dynamic>{'status': newStatus};
      if (newStatus == 'USED') updateData['used_at'] = DateTime.now().toIso8601String();

      await _admin.from('user_rewards').update(updateData).eq('id', claim['id']);
      _showSnack('Status berhasil diubah ke "$statusLabel"', true);
      _fetchClaims();
    } catch (e) {
      _showSnack('Gagal: $e', false);
    }
  }

  void _showSnack(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE': return const Color(0xFFF59E0B);
      case 'USED': return const Color(0xFF10B981);
      case 'EXPIRED': return const Color(0xFF6B7280);
      default: return const Color(0xFF9CA3AF);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'ACTIVE': return Icons.schedule_rounded;
      case 'USED': return Icons.check_circle_rounded;
      case 'EXPIRED': return Icons.cancel_rounded;
      default: return Icons.help_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ACTIVE': return 'Menunggu';
      case 'USED': return 'Ditukar';
      case 'EXPIRED': return 'Kedaluwarsa';
      default: return status;
    }
  }

  int _countByStatus(String status) => _allClaims.where((c) => c['status'] == status).length;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E))),
        title: const Text('Kelola Penukaran', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
            child: Text('${_allClaims.length} klaim', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(children: [
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))]),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari nama user atau hadiah...', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                    suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null,
                    filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  tabs: [
                    Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Menunggu'),
                      if (_countByStatus('ACTIVE') > 0) ...[
                        const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(10)),
                          child: Text('${_countByStatus('ACTIVE')}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                      ],
                    ])),
                    const Tab(text: 'Ditukar'),
                    const Tab(text: 'Kedaluwarsa'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
                  : TabBarView(controller: _tabController, children: [
                      _buildClaimList('ACTIVE', isDesktop),
                      _buildClaimList('USED', isDesktop),
                      _buildClaimList('EXPIRED', isDesktop),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildClaimList(String status, bool isDesktop) {
    final list = _filteredList(status);

    if (list.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(status == 'ACTIVE' ? Icons.hourglass_empty_rounded : status == 'USED' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(_searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"' : 'Belum ada data', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
      ]));
    }

    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _fetchClaims,
      child: isDesktop ? _buildDesktopTable(list, status) : ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: list.length,
        itemBuilder: (_, i) => _buildClaimCard(list[i], status, i),
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> list, String status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
            dataRowMinHeight: 68, dataRowMaxHeight: 68,
            horizontalMargin: 24, columnSpacing: 24,
            columns: const [
              DataColumn(label: Expanded(child: Text('User', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
              DataColumn(label: Expanded(child: Text('Hadiah', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
              DataColumn(label: Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
              DataColumn(label: Text('Tanggal Klaim', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
              DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
            ],
            rows: list.map((claim) {
              final userName = claim['profiles']?['full_name'] ?? '-';
              final rewardName = claim['rewards']?['name'] ?? '-';
              final rewardType = claim['rewards']?['type'] ?? '-';
              final claimStatus = claim['status'] ?? 'ACTIVE';

              String dateStr = '-';
              if (claim['claimed_at'] != null) {
                try { dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(claim['claimed_at']).toLocal()); } catch (_) {}
              }

              return DataRow(cells: [
                DataCell(Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                DataCell(Text(rewardName, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(_typeBadge(rewardType)),
                DataCell(Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                DataCell(_statusBadge(claimStatus)),
                DataCell(_buildActionButtons(claim, claimStatus)),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim, String status, int index) {
    final userName = claim['profiles']?['full_name'] ?? 'User';
    final phone = claim['profiles']?['phone'] ?? '';
    final rewardName = claim['rewards']?['name'] ?? 'Hadiah';
    final rewardType = claim['rewards']?['type'] ?? 'VOUCHER';
    final claimStatus = claim['status'] ?? 'ACTIVE';

    String dateStr = '-';
    if (claim['claimed_at'] != null) {
      try { dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(claim['claimed_at']).toLocal()); } catch (_) {}
    }

    String usedStr = '';
    if (claim['used_at'] != null) {
      try { usedStr = 'Ditukar: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(claim['used_at']).toLocal())}'; } catch (_) {}
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 400 + (index * 60)), curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: claimStatus == 'ACTIVE' ? const Color(0xFFF59E0B).withOpacity(0.3) : const Color(0xFFF0F0F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _statusColor(claimStatus).withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(_statusIcon(claimStatus), color: _statusColor(claimStatus), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
              if (phone.isNotEmpty) Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ])),
            _statusBadge(claimStatus),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.card_giftcard_rounded, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(child: Text(rewardName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              _typeBadge(rewardType),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Text('Diklaim: $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            if (usedStr.isNotEmpty) ...[
              const SizedBox(width: 12),
              Icon(Icons.check_rounded, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(usedStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ]),
          if (claimStatus == 'ACTIVE') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: SizedBox(height: 40, child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(claim, 'USED'),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Tandai Ditukar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
              ),
              const SizedBox(width: 8),
              SizedBox(height: 40, child: OutlinedButton(
                onPressed: () => _updateStatus(claim, 'EXPIRED'),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6B7280), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Expired', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              )),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> claim, String status) {
    if (status == 'ACTIVE') {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        _actionBtn(Icons.check_circle_rounded, 'Ditukar', const Color(0xFF10B981), () => _updateStatus(claim, 'USED')),
        const SizedBox(width: 6),
        _actionBtn(Icons.cancel_rounded, 'Expired', const Color(0xFF6B7280), () => _updateStatus(claim, 'EXPIRED')),
      ]);
    }
    if (status == 'USED' || status == 'EXPIRED') {
      return _actionBtn(Icons.undo_rounded, 'Aktifkan', const Color(0xFFF59E0B), () => _updateStatus(claim, 'ACTIVE'));
    }
    return const SizedBox.shrink();
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))]),
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(status))),
      ]),
    );
  }

  Widget _typeBadge(String type) {
    final isVoucher = type == 'VOUCHER';
    final color = isVoucher ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      child: Text(isVoucher ? 'Voucher' : 'Produk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
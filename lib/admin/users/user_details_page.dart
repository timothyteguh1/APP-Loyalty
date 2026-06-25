import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../admin_supabase.dart';

class UserDetailsPage extends StatefulWidget {
  const UserDetailsPage({super.key});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _admin = AdminSupabase.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final _searchCtrl = TextEditingController();

  int _baseAmount = 100000;
  List<dynamic> _tiers = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final int currentYear = DateTime.now().year;

      // 1. Tarik Aturan Tiering dari Config
      final config = await _admin
          .from('app_config')
          .select('value')
          .eq('key', 'point_tiering_rules')
          .maybeSingle();
      if (config != null && config['value'] != null) {
        final data = jsonDecode(config['value'].toString());
        _baseAmount = data['base_amount'] ?? 100000;
        _tiers = data['tiers'] ?? [];
      }

      // 2. Tarik Data Profil User
      final profilesData = await _admin
          .from('profiles')
          .select()
          .eq('approval_status', 'APPROVED');

      // 3. Tarik Data Memori Akumulasi Tahun Ini
      final accumulationsData = await _admin
          .from('yearly_accumulations')
          .select()
          .eq('year', currentYear);

      // 4. Tarik Histori Poin Tahun Ini untuk isolasi Poin Manual dan Hitung Total Poin
      final historyRes = await _admin
          .from('point_history')
          .select('user_id, amount, reference_id, reference_type, created_at')
          .gte('created_at', '$currentYear-01-01T00:00:00.000Z');

      // 4a. Cari batas waktu "Reset" terakhir per user (Sistem Epoch)
      Map<String, DateTime> lastResetMap = {};
      for(var h in historyRes) {
          String uid = h['user_id']?.toString() ?? '';
          String refId = (h['reference_id'] ?? '').toString().toUpperCase();
          if (refId.startsWith('RESET_')) {
              DateTime dt = DateTime.parse(h['created_at']);
              if (!lastResetMap.containsKey(uid) || dt.isAfter(lastResetMap[uid]!)) {
                  lastResetMap[uid] = dt;
              }
          }
      }

      // 4b. Filter histori yang terjadi SETELAH reset
      Map<String, int> manualPointsMap = {};
      Map<String, int> totalPosMap = {};
      
      for(var h in historyRes) {
          String uid = h['user_id']?.toString() ?? '';
          DateTime dt = DateTime.parse(h['created_at']);
          
          if (lastResetMap.containsKey(uid) && dt.isBefore(lastResetMap[uid]!)) {
              continue; // Abaikan sejarah masa lalu jika pernah direset
          }
          
          int amt = (h['amount'] as num?)?.toInt() ?? 0;
          String refId = (h['reference_id'] ?? '').toString().toUpperCase();
          String refType = (h['reference_type'] ?? '').toString().toUpperCase();
          
          if (!manualPointsMap.containsKey(uid)) manualPointsMap[uid] = 0;
          if (!totalPosMap.containsKey(uid)) totalPosMap[uid] = 0;
          
          // Total Poin = Semua poin masuk (Faktur + Bonus + Manual Positif)
          if (amt > 0 && !refId.startsWith('RESET_')) {
              totalPosMap[uid] = totalPosMap[uid]! + amt;
          }
          
          // Deteksi Poin Manual (Bukan dari Faktur/Retur Accurate, Reset, atau Tukar Hadiah)
          bool isAccurate = refId.startsWith('FP') || refId.startsWith('SI') || refId.startsWith('SR') || refId.startsWith('BONUS_');
          bool isReset = refId.startsWith('RESET_');
          bool isRedeem = refType == 'REDEEM' || refId.startsWith('RDM');
          
          if (!isAccurate && !isReset && !isRedeem) {
              manualPointsMap[uid] = manualPointsMap[uid]! + amt;
          }
      }

      // 5. Gabungkan Data (Merge) & Kalkulasi Tier Akhir
      final List<Map<String, dynamic>> mergedList = [];
      for (var profile in profilesData) {
        final p = Map<String, dynamic>.from(profile);
        final uid = p['id']?.toString() ?? '';
        
        final userAccData = accumulationsData.where((a) => a['user_id'] == uid);
        final acc = userAccData.isNotEmpty ? userAccData.first : null;

        int accuratePoints = (acc?['accurate_points'] as num?)?.toInt() ?? 0;
        int manualPoints = manualPointsMap[uid] ?? 0;
        
        // Poin Accurate Efektif (Murni + Manual) untuk landasan Tier
        int effectiveAccurate = accuratePoints + manualPoints;
        if (effectiveAccurate < 0) effectiveAccurate = 0;
        
        int tierLevel = 1;
        double multiplier = 0.0;
        
        double currentRupiah = effectiveAccurate * _baseAmount.toDouble();
        for (int i = 0; i < _tiers.length; i++) {
          double min = (_tiers[i]['min'] as num?)?.toDouble() ?? 0;
          double? max = _tiers[i]['max'] != null ? (_tiers[i]['max'] as num).toDouble() : null;
          if (currentRupiah >= min && (max == null || currentRupiah <= max)) {
            tierLevel = i + 1; 
            multiplier = (_tiers[i]['multiplier'] as num?)?.toDouble() ?? 0.0;
            break;
          }
        }

        p['accurate_points'] = accuratePoints; // Murni Poin Accurate
        p['total_poin'] = totalPosMap[uid] ?? 0; // Total semua poin masuk
        p['tier'] = tierLevel;
        p['multiplier'] = multiplier;
        
        mergedList.add(p);
      }

      mergedList.sort((a, b) => ((b['points'] as num?)?.toInt() ?? 0).compareTo((a['points'] as num?)?.toInt() ?? 0));
      
      if (mounted) {
        setState(() {
          _users = mergedList;
          _filteredUsers = _users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _filterUsers(String query) {
    final q = query.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['full_name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final accId = (user['accurate_customer_id'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || accId.contains(q);
      }).toList();
    });
  }

  void _showHistoryDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => _UserHistoryDialog(
        userId: user['id'],
        userName: user['full_name'] ?? 'User',
        baseAmount: _baseAmount,
        tiers: _tiers,
      ),
    );
  }

  Future<void> _showResetDialog(Map<String, dynamic> user) async {
    await showDialog(
      context: context,
      builder: (context) => _ResetPointsDialog(
        user: user,
        onReset: _fetchUsers,
      ),
    );
  }

  // ── Tier badge ──────────────────────────────────────────────────────
  Widget _tierBadge(int tier, double multiplier) {
    final colors = [
      const Color(0xFF9E9E9E),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFFB71C1C),
    ];
    final color = tier <= colors.length ? colors[tier - 1] : colors.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        'T$tier · ${multiplier}x',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Rincian Poin User', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E), fontSize: 22)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _filterUsers,
                  decoration: InputDecoration(
                    hintText: 'Cari Nama, Email, atau ID Accurate...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)))
                      : _filteredUsers.isEmpty
                          ? const Center(child: Text('Tidak ada data user.', style: TextStyle(color: Colors.grey)))
                          : isDesktop
                              ? _buildDesktopTable()
                              : _buildMobileList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
            showCheckboxColumn: false,
            dataRowMaxHeight: 70,
            columns: const [
              DataColumn(label: Text('Nama Toko', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Email / Kontak', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ID Accurate', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Poin Terkini', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Total Poin', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Tier', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Poin Accurate', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _filteredUsers.map((user) {
              final tier = (user['tier'] as int?) ?? 1;
              final multiplier = (user['multiplier'] as double?) ?? 0.0;
              return DataRow(
                onSelectChanged: (_) => _showHistoryDialog(user),
                cells: [
                  DataCell(Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text('${user['email'] ?? '-'}\n${user['phone'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                  DataCell(Text(user['accurate_customer_id'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text('${user['points'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  DataCell(Text('${user['total_poin'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)))),
                  DataCell(_tierBadge(tier, multiplier)),
                  DataCell(Text('${user['accurate_points'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history_rounded, color: Color(0xFF3B82F6), size: 20),
                        tooltip: 'Lihat Histori',
                        onPressed: () => _showHistoryDialog(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFB71C1C), size: 20),
                        tooltip: 'Reset Poin',
                        onPressed: () => _showResetDialog(user),
                      ),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final tier = (user['tier'] as int?) ?? 1;
        final multiplier = (user['multiplier'] as double?) ?? 0.0;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFF0F0F0))),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            onTap: () => _showHistoryDialog(user),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFB71C1C).withOpacity(0.1),
              child: const Icon(Icons.storefront_rounded, color: Color(0xFFB71C1C)),
            ),
            title: Text(user['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${user['accurate_customer_id'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  _tierBadge(tier, multiplier),
                  const SizedBox(width: 8),
                  Text('Total: ${user['total_poin'] ?? 0}p', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Saldo', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${user['points'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFB71C1C)),
                  onPressed: () => _showResetDialog(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// DIALOG: HISTORY POIN
// =====================================================================
class _UserHistoryDialog extends StatefulWidget {
  final String userId;
  final String userName;
  final int baseAmount;
  final List<dynamic> tiers;

  const _UserHistoryDialog({
    required this.userId,
    required this.userName,
    required this.baseAmount,
    required this.tiers,
  });

  @override
  State<_UserHistoryDialog> createState() => _UserHistoryDialogState();
}

class _UserHistoryDialogState extends State<_UserHistoryDialog> {
  final _admin = AdminSupabase.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _histories = [];
  bool _showBonus = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final data = await _admin
          .from('point_history')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _histories = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mengambil poin MURNI (tanpa pengali bonus)
  int _basePoin(Map<String, dynamic> h) {
    final type = h['reference_type']?.toString() ?? '';
    final ref = h['reference_id']?.toString() ?? '';

    // Reset dan Bonus Row tidak memiliki base poin
    if (type.startsWith('RESET') || ref.startsWith('RESET')) return 0;
    if (ref.startsWith('BONUS_')) return 0;

    // Poin Manual dianggap sebagai base poin murni
    if (type == 'MANUAL') return (h['amount'] as num?)?.toInt() ?? 0;

    final double nominal = (h['base_nominal'] as num?)?.toDouble() ?? 0;
    if (nominal <= 0) return (h['amount'] as num?)?.toInt() ?? 0;

    final int base = (nominal / widget.baseAmount).floor();
    return type == 'RETURN' ? -base : base;
  }

  bool _isResetEntry(Map<String, dynamic> h) {
    final type = h['reference_type']?.toString() ?? '';
    final ref = h['reference_id']?.toString() ?? '';
    return type.startsWith('RESET') || ref.startsWith('RESET');
  }

  @override
  Widget build(BuildContext context) {
    int totalDenganBonus = 0;
    int totalTanpaBonus = 0;
    DateTime? latestDate;

    // Kalkulasi Total Poin
    for (final h in _histories) {
      if (_isResetEntry(h)) continue;
      
      totalDenganBonus += (h['amount'] as num?)?.toInt() ?? 0;
      
      if (!h['reference_id'].toString().startsWith('BONUS_')) {
        totalTanpaBonus += _basePoin(h);
      }

      if (latestDate == null && h['created_at'] != null && !h['reference_id'].toString().startsWith('BONUS_')) {
        latestDate = DateTime.parse(h['created_at']).toLocal();
      }
    }
    
    final int bonusPoin = totalDenganBonus - totalTanpaBonus;

    // Filter histori untuk ditampilkan (Sembunyikan baris BONUS_ mentah dari DB)
    final displayHistories = _histories.where((h) {
      if (h['reference_id'].toString().startsWith('BONUS_')) return false;
      return true;
    }).toList();

    final bool showSyntheticBonus = _showBonus && bonusPoin != 0;
    final int itemCount = displayHistories.length + (showSyntheticBonus ? 1 : 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 640,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),

            // Ringkasan Poin
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Row(
                children: [
                  _summaryChip('Total Poin', '${_showBonus ? totalDenganBonus : totalTanpaBonus}', const Color(0xFFD32F2F)),
                  const SizedBox(width: 12),
                  _summaryChip('Tanpa Bonus', '$totalTanpaBonus', const Color(0xFF555555)),
                  const SizedBox(width: 12),
                  _summaryChip('Bonus Tier', bonusPoin >= 0 ? '+$bonusPoin' : '$bonusPoin', const Color(0xFF2196F3)),
                ],
              ),
            ),

            // Toggle Mode
            Row(
              children: [
                const Text('Tampilan:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(width: 8),
                _toggleChip('Dengan Bonus', _showBonus, () => setState(() => _showBonus = true)),
                const SizedBox(width: 6),
                _toggleChip('Tanpa Bonus', !_showBonus, () => setState(() => _showBonus = false)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayHistories.isEmpty && !showSyntheticBonus
                      ? const Center(child: Text('Belum ada histori poin.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            
                            // 1. Render Baris Bonus Akumulasi (Jika mode Dengan Bonus aktif)
                            if (showSyntheticBonus) {
                              if (index == 0) {
                                String dateStr = latestDate != null ? DateFormat('dd MMM yyyy, HH:mm').format(latestDate) : '';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.add_rounded, color: Colors.green, size: 16),
                                  ),
                                  title: const Text('Akumulasi Bonus Tier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Text('${bonusPoin > 0 ? "+" : ""}$bonusPoin', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                );
                              }
                              index--; // Geser index untuk list sisanya
                            }

                            final h = displayHistories[index];
                            final bool isReset = _isResetEntry(h);

                            // 2. Render Baris Reset
                            if (isReset) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.restart_alt_rounded, color: Colors.orange, size: 16),
                                ),
                                title: Text(h['description'] ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.orange)),
                                subtitle: Text(
                                  h['created_at'] != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(h['created_at']).toLocal()) : '',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: const Icon(Icons.admin_panel_settings_rounded, color: Colors.orange, size: 16),
                              );
                            }

                            // 3. Render Baris Faktur / Manual
                            // SELALU TAMPILKAN BASE POIN SAJA SESUAI DESAIN BARU
                            final int displayAmount = _basePoin(h); 
                            final bool isPos = displayAmount > 0;
                            final Color color = displayAmount == 0 ? Colors.grey : (isPos ? Colors.green : Colors.red);

                            String dateStr = '';
                            if (h['created_at'] != null) {
                              dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(h['created_at']).toLocal());
                            }

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(
                                  displayAmount == 0 ? Icons.remove_circle_outline : (isPos ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                                  color: color,
                                  size: 16,
                                ),
                              ),
                              title: Text(h['description'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Text(
                                '${displayAmount == 0 ? "" : (isPos ? "+" : "")}$displayAmount',
                                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD32F2F) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : Colors.grey)),
      ),
    );
  }
}

// =====================================================================
// DIALOG: RESET POIN
// =====================================================================
class _ResetPointsDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onReset;

  const _ResetPointsDialog({required this.user, required this.onReset});

  @override
  State<_ResetPointsDialog> createState() => _ResetPointsDialogState();
}

class _ResetPointsDialogState extends State<_ResetPointsDialog> {
  final _admin = AdminSupabase.client;
  bool _isLoading = false;
  bool _resetTerkini = false;
  bool _resetAccurate = false;

  Future<void> _doReset() async {
    if (!_resetTerkini && !_resetAccurate) return;
    setState(() => _isLoading = true);
    try {
      final String userId = widget.user['id'];
      final String userName = widget.user['full_name'] ?? 'User';
      final int currentYear = DateTime.now().year;
      final String now = DateTime.now().toIso8601String();
      final String ts = DateTime.now().millisecondsSinceEpoch.toString();

      if (_resetTerkini) {
        final int currentPoints = (widget.user['points'] as num?)?.toInt() ?? 0;
        await _admin.from('profiles').update({'points': 0, 'updated_at': now}).eq('id', userId);

        await _admin.from('point_history').insert({
          'user_id': userId,
          'amount': currentPoints > 0 ? -currentPoints : 0,
          'base_nominal': 0,
          'description': 'Reset Poin Terkini oleh Admin',
          'reference_type': 'INVOICE',
          'reference_id': 'RESET-$ts',
          'created_at': now,
        });
      }

      if (_resetAccurate) {
        await _admin
            .from('yearly_accumulations')
            .update({'accurate_points': 0, 'updated_at': now})
            .eq('user_id', userId)
            .eq('year', currentYear);

        await _admin.from('point_history').insert({
          'user_id': userId,
          'amount': 0,
          'base_nominal': 0,
          'description': 'Reset Poin Accurate (Akumulasi) oleh Admin — Tahun $currentYear',
          'reference_type': 'INVOICE',
          'reference_id': 'RESET-ACC-$ts',
          'created_at': now,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onReset();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset berhasil untuk $userName'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal reset: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userName = widget.user['full_name'] ?? 'User';
    final int currentPoints = (widget.user['points'] as num?)?.toInt() ?? 0;
    final int accuratePoints = (widget.user['accurate_points'] as num?)?.toInt() ?? 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.restart_alt_rounded, color: Color(0xFFB71C1C)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reset Poin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(userName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: _infoItem('Poin Terkini', '$currentPoints', Colors.black)),
                  Expanded(child: _infoItem('Poin Accurate', '$accuratePoints', const Color(0xFFD32F2F))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _resetOption(
              title: 'Reset Poin Terkini',
              subtitle: 'Saldo poin jadi 0. Histori faktur tetap tersimpan,\nsync tidak akan re-insert faktur lama.',
              value: _resetTerkini,
              onChanged: (v) => setState(() => _resetTerkini = v ?? false),
              color: const Color(0xFFD32F2F),
            ),
            const SizedBox(height: 12),
            _resetOption(
              title: 'Reset Poin Accurate (Akumulasi)',
              subtitle: 'Akumulasi omzet tahun ini jadi 0, tier kembali ke awal.\nHistori tetap tersimpan.',
              value: _resetAccurate,
              onChanged: (v) => setState(() => _resetAccurate = v ?? false),
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 24),

            if (_resetTerkini || _resetAccurate)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Aksi ini tidak dapat dibatalkan. Jejak reset dicatat di histori.', style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
                  ],
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_resetTerkini || _resetAccurate) && !_isLoading ? _doReset : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Konfirmasi Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _resetOption({required String title, required String subtitle, required bool value, required ValueChanged<bool?> onChanged, required Color color}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? color.withOpacity(0.4) : const Color(0xFFE8E8E8), width: value ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: value, onChanged: onChanged, activeColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: value ? color : Colors.black)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
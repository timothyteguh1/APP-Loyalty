import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Filtering TextInput
import 'package:intl/intl.dart';
import '../accurate/accurate_service.dart';
import '../admin_supabase.dart';

class AccurateSyncHistoryPage extends StatefulWidget {
  const AccurateSyncHistoryPage({super.key});

  @override
  State<AccurateSyncHistoryPage> createState() =>
      _AccurateSyncHistoryPageState();
}

class _AccurateSyncHistoryPageState extends State<AccurateSyncHistoryPage> {
  final _supabase = AdminSupabase.client;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isSavingGrace = false; // Status loading saat simpan Grace Period
  String _syncProgress = '';
  List<Map<String, dynamic>> _historyData = [];
  SyncResult? _lastSyncResult;

  // Variabel untuk Filter Tanggal Sync
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  // Variabel untuk Grace Period
  final _graceCtrl = TextEditingController(text: '0');

  // Filter Search & Dropdown
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String? _selectedType; // 'INVOICE' or 'RETURN'

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _fetchHistory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _graceCtrl.dispose();
    super.dispose();
  }

  // --- MENGAMBIL DATA GRACE PERIOD DARI DATABASE ---
  Future<void> _loadConfig() async {
    try {
      final res = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', 'grace_period_days')
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _graceCtrl.text = res['value']?.toString() ?? '0';
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat Grace Period: $e');
    }
  }

  // --- MENYIMPAN DATA GRACE PERIOD KE DATABASE ---
  Future<void> _saveGracePeriod() async {
    final val = _graceCtrl.text.trim();
    if (val.isEmpty) {
      _showSnack('Grace Period tidak boleh kosong', false);
      return;
    }

    setState(() => _isSavingGrace = true);
    try {
      await _supabase.from('app_config').upsert(
        {'key': 'grace_period_days', 'value': val},
        onConflict: 'key',
      );
      _showSnack('Grace Period berhasil diperbarui menjadi $val hari!', true);
    } catch (e) {
      _showSnack('Gagal menyimpan Grace Period: $e', false);
    } finally {
      if (mounted) setState(() => _isSavingGrace = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('point_history')
          .select('*, profiles(full_name)')
          .inFilter('reference_type', ['INVOICE', 'RETURN'])
          .order('created_at', ascending: false)
          .limit(200);

      if (mounted) {
        setState(() {
          _historyData = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Gagal memuat histori: $e', false);
      }
    }
  }

  // Fungsi memunculkan Kalender Date Picker
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncProgress = 'Memulai sinkronisasi...';
      _lastSyncResult = null;
    });

    try {
      final config = await AccurateService.loadConfig(_supabase);
      final host = config['accurate_db_host'];
      final session = config['accurate_db_session'];

      if (host == null || host.isEmpty || session == null || session.isEmpty) {
        throw 'Kredensial Accurate kosong. Pastikan sudah login di menu Koneksi Accurate.';
      }

      final result = await AccurateService.syncInvoicesToPoints(
        admin: _supabase,
        host: host,
        session: session,
        startDate: _startDate, 
        endDate: _endDate,     
        onProgress: (msg) {
          if (mounted) setState(() => _syncProgress = msg);
        },
      );

      if (mounted) {
        setState(() => _lastSyncResult = result);
        _showSnack('Sync selesai! ${result.totalPointsAdded} poin ditambahkan.', true);
      }

      await _fetchHistory();
    } catch (e) {
      if (mounted) _showSnack('Error: $e', false);
    } finally {
      if (mounted) setState(() { _isSyncing = false; _syncProgress = ''; });
    }
  }

  void _showSnack(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  List<Map<String, dynamic>> get _filteredHistory {
    return _historyData.where((item) {
      if (_selectedType != null && item['reference_type'] != _selectedType) return false;
      if (_searchQuery.isNotEmpty) {
        final name = (item['profiles']?['full_name'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !desc.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  int get _totalPointsIn => _historyData.where((h) => (h['amount'] as num? ?? 0) > 0).fold(0, (sum, h) => sum + ((h['amount'] as num?)?.toInt() ?? 0));
  int get _totalPointsOut => _historyData.where((h) => (h['amount'] as num? ?? 0) < 0).fold(0, (sum, h) => sum + ((h['amount'] as num?)?.toInt() ?? 0).abs());
  int get _invoiceCount => _historyData.where((h) => h['reference_type'] == 'INVOICE').length;
  int get _returnCount => _historyData.where((h) => h['reference_type'] == 'RETURN').length;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            color: const Color(0xFFB71C1C),
            onRefresh: () async {
              await _loadConfig();
              await _fetchHistory();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ======= HEADER =======
                  const Text('Sync & Histori Poin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  const Text('Tarik data Faktur & Retur dari Accurate, konversi otomatis ke poin toko.', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 24),

                  // ======= DATE FILTER & SYNC CARD =======
                  _buildSyncCard(),
                  const SizedBox(height: 16),

                  // ======= SYNC RESULT =======
                  if (_lastSyncResult != null) ...[
                    _buildSyncResultCard(_lastSyncResult!),
                    const SizedBox(height: 16),
                  ],

                  // ======= STAT CARDS =======
                  if (!_isLoading && _historyData.isNotEmpty) ...[
                    if (isDesktop)
                      Row(children: [
                        Expanded(child: _buildStatCard('Faktur Masuk', '$_invoiceCount', '+$_totalPointsIn poin', const Color(0xFF10B981), Icons.receipt_long_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Retur Potong', '$_returnCount', '-$_totalPointsOut poin', const Color(0xFFEF4444), Icons.assignment_return_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildStatCard('Bersih', '${_totalPointsIn - _totalPointsOut}', 'total poin nett', const Color(0xFF3B82F6), Icons.balance_rounded)),
                      ])
                    else
                      Column(children: [
                        Row(children: [
                          Expanded(child: _buildStatCard('Faktur', '$_invoiceCount', '+$_totalPointsIn', const Color(0xFF10B981), Icons.receipt_long_rounded)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatCard('Retur', '$_returnCount', '-$_totalPointsOut', const Color(0xFFEF4444), Icons.assignment_return_rounded)),
                        ]),
                        const SizedBox(height: 12),
                        _buildStatCard('Poin Bersih', '${_totalPointsIn - _totalPointsOut}', 'total poin nett', const Color(0xFF3B82F6), Icons.balance_rounded),
                      ]),
                    const SizedBox(height: 28),
                  ],

                  // ======= GRACE PERIOD CARD =======
                  _buildGracePeriodCard(isDesktop),
                  const SizedBox(height: 16),

                  // ======= RULES INFO =======
                  _buildRulesCard(),
                  const SizedBox(height: 28),

                  // ======= HISTORY SECTION =======
                  Row(children: [
                    const Expanded(child: Text('Riwayat Sinkronisasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)))),
                    GestureDetector(
                      onTap: _fetchHistory,
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF3B82F6)),
                        SizedBox(width: 4),
                        Text('Refresh', style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ======= FILTER BAR =======
                  _buildFilterBar(),
                  const SizedBox(height: 16),

                  // ======= HISTORY LIST / TABLE =======
                  _isLoading
                      ? _buildLoadingShimmer()
                      : _filteredHistory.isEmpty
                          ? _buildEmptyState()
                          : isDesktop
                              ? _buildDesktopTable(_filteredHistory)
                              : _buildMobileList(_filteredHistory),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _buildSyncCard() {
    final startStr = DateFormat('dd MMM yyyy').format(_startDate);
    final endStr = DateFormat('dd MMM yyyy').format(_endDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF059669), Color(0xFF10B981)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.sync_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Accurate Online', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  const Text('Sinkronisasi Otomatis', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    _isSyncing ? _syncProgress : 'Tarik faktur lunas & retur → konversi ke poin',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 48, width: 140,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(_isSyncing ? 'Proses...' : 'Sync', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF059669),
                    disabledBackgroundColor: Colors.white.withOpacity(0.7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // TOMBOL PILIH RENTANG TANGGAL
          InkWell(
            onTap: _isSyncing ? null : _selectDateRange,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Rentang: $startStr  -  $endStr',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET GRACE PERIOD BARU ---
  Widget _buildGracePeriodCard(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.timer_rounded, size: 16, color: Color(0xFF3B82F6))),
              const SizedBox(width: 10),
              const Text('Grace Period (Toleransi Keterlambatan)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Kompensasi penambahan hari dari Tanggal Jatuh Tempo faktur agar user tetap mendapatkan poin jika melunasi dalam rentang waktu ini.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 44,
                child: TextField(
                  controller: _graceCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    suffixText: 'Hari',
                    suffixStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSavingGrace ? null : _saveGracePeriod,
                  icon: _isSavingGrace
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_isSavingGrace ? 'Menyimpan...' : 'Simpan', style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSyncResultCard(SyncResult result) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16)),
          const SizedBox(width: 10),
          const Text('Hasil Sync Terakhir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
          const Spacer(),
          GestureDetector(onTap: () => setState(() => _lastSyncResult = null), child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF9CA3AF))),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 24, runSpacing: 10, children: [
          _resultChip('Faktur Dicek', '${result.totalInvoicesChecked}', const Color(0xFF3B82F6)),
          _resultChip('Poin Ditambah', '+${result.totalPointsAdded}', const Color(0xFF10B981)),
          _resultChip('User Diupdate', '${result.totalUsersAffected}', const Color(0xFFF59E0B)),
          _resultChip('Dilewati', '${result.totalSkipped}', const Color(0xFF6B7280)),
        ]),
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...result.errors.take(3).map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.warning_rounded, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Expanded(child: Text(e, style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)))),
            ]),
          )),
        ],
      ]),
    );
  }

  Widget _resultChip(String label, String value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          Text(subtitle, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.gavel_rounded, size: 14, color: Color(0xFFF59E0B))),
          const SizedBox(width: 10),
          const Text('Aturan Poin Otomatis', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
        ]),
        const SizedBox(height: 14),
        _ruleItem('✅', 'Faktur LUNAS + bayar sebelum jatuh tempo', 'Dapat poin', const Color(0xFF10B981)),
        _ruleItem('❌', 'Faktur LUNAS + bayar setelah jatuh tempo (+ toleransi)', 'Tidak dapat poin', const Color(0xFFEF4444)),
        _ruleItem('❌', 'Faktur BELUM LUNAS (bayar sebagian)', 'Tidak dapat poin', const Color(0xFFEF4444)),
        _ruleItem('➖', 'Ada Retur Penjualan', 'Poin dipotong sesuai nominal', const Color(0xFFF59E0B)),
      ]),
    );
  }

  Widget _ruleItem(String emoji, String desc, String result, Color resultColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(desc, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4)),
          Text(result, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: resultColor)),
        ])),
      ]),
    );
  }

  Widget _buildFilterBar() {
    final hasFilter = _searchQuery.isNotEmpty || _selectedType != null;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cari nama toko atau deskripsi...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                : null,
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedType,
            hint: const Text('Semua', style: TextStyle(fontSize: 13)),
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            items: const [
              DropdownMenuItem(value: null, child: Text('Semua', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'INVOICE', child: Text('Faktur', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'RETURN', child: Text('Retur', style: TextStyle(fontSize: 13))),
            ],
            onChanged: (v) => setState(() => _selectedType = v),
          ),
        ),
      ),
      if (hasFilter) ...[
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _selectedType = null; }); },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.clear_all_rounded, size: 18, color: Color(0xFFB71C1C)),
          ),
        ),
      ],
    ]);
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> data) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
          dataRowMinHeight: 60, dataRowMaxHeight: 60,
          horizontalMargin: 24, columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
            DataColumn(label: Expanded(child: Text('Nama Toko', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
            DataColumn(label: Text('Tipe', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
            DataColumn(label: Expanded(child: Text('Deskripsi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
            DataColumn(label: Text('Poin', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
          ],
          rows: data.map((item) {
            final isReturn = item['reference_type'] == 'RETURN';
            final amount = (item['amount'] as num?)?.toInt() ?? 0;
            final isPos = amount > 0;
            final name = item['profiles']?['full_name'] ?? '-';
            final desc = item['description'] ?? '-';

            String dateStr = '';
            if (item['created_at'] != null) {
              try { dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item['created_at']).toLocal()); } catch (_) {}
            }

            final Color typeColor = isReturn ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
            final String typeLabel = isReturn ? 'Retur' : 'Faktur';

            return DataRow(cells: [
              DataCell(Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
              DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1A2E)))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: typeColor.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                child: Text(typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
              )),
              DataCell(Text(desc, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
              DataCell(Text(
                '${isPos ? "+" : ""}$amount',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> data) {
    return Column(children: data.map((item) {
      final isReturn = item['reference_type'] == 'RETURN';
      final amount = (item['amount'] as num?)?.toInt() ?? 0;
      final isPos = amount > 0;
      final name = item['profiles']?['full_name'] ?? 'Toko';
      final desc = item['description'] ?? '-';

      String dateStr = '';
      if (item['created_at'] != null) {
        try { dateStr = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(item['created_at']).toLocal()); } catch (_) {}
      }

      final Color tColor = isReturn ? const Color(0xFFEF4444) : const Color(0xFF10B981);

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isReturn ? const Color(0xFFFCA5A5).withOpacity(0.3) : const Color(0xFFF3F4F6)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Icon(isReturn ? Icons.assignment_return_rounded : Icons.receipt_long_rounded, color: tColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
            const SizedBox(height: 3),
            Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFFD1D5DB))),
          ])),
          const SizedBox(width: 10),
          Text('${isPos ? "+" : ""}$amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: tColor)),
        ]),
      );
    }).toList());
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.inbox_rounded, color: Color(0xFF9CA3AF), size: 28)),
        const SizedBox(height: 12),
        Text(_searchQuery.isNotEmpty || _selectedType != null ? 'Tidak ada hasil untuk filter ini' : 'Belum ada histori sinkronisasi', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        const Text('Klik Sync untuk mulai menarik data dari Accurate', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ]),
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(children: List.generate(4, (i) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.04, end: 0.08),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (_, val, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.black.withOpacity(val),
          ),
        ),
      ),
    )));
  }
}
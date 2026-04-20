import 'package:flutter/material.dart';
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
  String _syncProgress = '';
  List<Map<String, dynamic>> _historyData = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      // Ambil histori khusus Faktur dan Retur, di-join dengan tabel profiles untuk dapat nama toko
      final data = await _supabase
          .from('point_history')
          .select('*, profiles(full_name)')
          .inFilter('reference_type', ['INVOICE', 'RETURN'])
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _historyData = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat histori: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncProgress = 'Memulai sinkronisasi...';
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
        onProgress: (msg) {
          if (mounted) setState(() => _syncProgress = msg);
        },
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(
              'Laporan Sinkronisasi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(result.message, style: const TextStyle(height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }

      // Refresh list histori setelah sync
      await _fetchHistory();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Sync & Histori Accurate',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // Bagian Tombol Sync
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sinkronisasi Data Otomatis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tarik data Faktur Lunas dan Retur dari Accurate untuk diubah menjadi poin toko secara otomatis.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _handleSync,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    _isSyncing ? _syncProgress : 'Sync Sekarang',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(
                      0xFF059669,
                    ), // Warna Hijau Accurate
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Bagian Histori
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            alignment: Alignment.centerLeft,
            child: const Text(
              'Riwayat Penambahan & Pemotongan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB71C1C)),
                  )
                : _historyData.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada histori sinkronisasi.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _historyData.length,
                    itemBuilder: (context, index) {
                      final item = _historyData[index];
                      final isReturn = item['reference_type'] == 'RETURN';
                      final amount = item['amount'] ?? 0;
                      final desc = item['description'] ?? '-';
                      final storeName =
                          item['profiles']?['full_name'] ??
                          'Toko Tidak Diketahui';

                      DateTime? date;
                      try {
                        date = DateTime.parse(item['created_at']);
                      } catch (_) {}
                      final dateStr = date != null
                          ? DateFormat('dd MMM yyyy, HH:mm').format(date)
                          : '-';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isReturn
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                          ), // GANTI JADI 'side: BorderSide'
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isReturn
                                ? Colors.red.shade50
                                : Colors.green.shade50,
                            child: Icon(
                              isReturn
                                  ? Icons.assignment_return_rounded
                                  : Icons.receipt_long_rounded,
                              color: isReturn ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(
                            storeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '${isReturn ? '' : '+'}$amount Poin',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isReturn ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

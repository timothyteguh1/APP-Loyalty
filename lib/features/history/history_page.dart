import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoadingDetail = false;

  void _refreshHistory() {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Riwayat diperbarui"),
          duration: Duration(seconds: 1)),
    );
  }

  String _formatDate(String dateString) {
    try {
      DateTime dt = DateTime.parse(dateString).toLocal();
      List<String> months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _openRewardDetail(String userRewardId) async {
    if (_isLoadingDetail) return;
    setState(() => _isLoadingDetail = true);

    try {
      // Bersihkan ID — ambil angka saja (antisipasi data lama "REWARD-2")
      final cleanId = userRewardId.replaceAll(RegExp(r'[^0-9]'), '');
      final int searchId = int.tryParse(cleanId) ?? 0;

      if (searchId == 0) {
        throw Exception('ID voucher tidak valid: $userRewardId');
      }

      final data = await _supabase
          .from('user_rewards')
          .select('*, rewards(*)')
          .eq('id', searchId)
          .maybeSingle();

      if (!mounted) return;
      setState(() => _isLoadingDetail = false);

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Voucher tidak ditemukan atau sudah dihapus."),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ClaimedRewardDetailPage(data: data)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Gagal memuat detail: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // 1. HEADER MERAH
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
                Text("History",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Riwayat pemasukan dan penggunaan poin",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),

          // 2. CARD POIN
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
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Poin anda saat ini",
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _supabase
                            .from('profiles')
                            .stream(primaryKey: ['id']).eq(
                                'id', user?.id ?? ''),
                        builder: (context, snapshot) {
                          String points = "...";
                          if (snapshot.hasData &&
                              snapshot.data!.isNotEmpty) {
                            points =
                                snapshot.data![0]['points'].toString();
                          }
                          return Text("$points Points",
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900));
                        },
                      ),
                      InkWell(
                        onTap: _refreshHistory,
                        borderRadius: BorderRadius.circular(20),
                        child: const CircleAvatar(
                          backgroundColor: Color(0xFFD32F2F),
                          child: Icon(Icons.refresh,
                              color: Colors.white, size: 20),
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. LIST HISTORY
          Padding(
            padding: const EdgeInsets.only(top: 250),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _supabase
                  .from('point_history')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', user?.id ?? '')
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD32F2F)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text("Belum ada riwayat",
                          style: TextStyle(color: Colors.grey)));
                }

                final historyList = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 0),
                  itemCount: historyList.length,
                  itemBuilder: (context, index) {
                    final item = historyList[index];
                    final int amount = item['amount'] ?? 0;
                    final bool isPositive = amount > 0;
                    final bool isRewardClaim =
                        item['reference_type'] == 'REWARD_CLAIM' &&
                            item['reference_id'] != null;

                    return GestureDetector(
                      onTap: () {
                        if (isRewardClaim && !_isLoadingDetail) {
                          _openRewardDetail(
                              item['reference_id'].toString());
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2))
                          ],
                          border: isRewardClaim
                              ? Border.all(
                                  color: const Color(0xFFD32F2F)
                                      .withOpacity(0.15))
                              : null,
                        ),
                        child: Row(
                          children: [
                            if (isRewardClaim) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFD32F2F)
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle),
                                child: const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: Color(0xFFD32F2F),
                                    size: 20),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      item['description'] ?? 'Transaksi',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                      _formatDate(item['created_at']),
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12)),
                                  if (isRewardClaim) ...[
                                    const SizedBox(height: 4),
                                    const Text("Tap untuk lihat voucher",
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFD32F2F),
                                            fontWeight: FontWeight.w600)),
                                  ]
                                ],
                              ),
                            ),
                            Text(
                              isPositive ? "+$amount" : "$amount",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isPositive
                                      ? Colors.green
                                      : const Color(0xFFD32F2F)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 4. LOADING OVERLAY
          if (_isLoadingDetail)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
              ),
            ),
        ],
      ),
    );
  }
}

// =========================================================================
// WIDGET: HALAMAN DETAIL VOUCHER YANG SUDAH DIKLAIM
// =========================================================================
class ClaimedRewardDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const ClaimedRewardDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final reward = data['rewards'] ?? {};
    final String status = data['status'] ?? 'ACTIVE';
    final String uniqueCode = data['unique_code'] ?? 'UNKNOWN';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'ACTIVE') {
      statusColor = Colors.green;
      statusText = 'VOUCHER AKTIF';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'USED') {
      statusColor = Colors.grey[600]!;
      statusText = 'SUDAH DIPAKAI';
      statusIcon = Icons.task_alt_rounded;
    } else {
      statusColor = Colors.red;
      statusText = 'KEDALUWARSA';
      statusIcon = Icons.cancel_rounded;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Container(height: 200, color: const Color(0xFFD32F2F)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("Voucher Saya",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // KARTU UTAMA
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset('assets/images/logo.png',
                                  height: 30,
                                  errorBuilder: (c, e, s) =>
                                      const SizedBox()),
                              const SizedBox(height: 16),
                              Text(reward['name'] ?? 'Hadiah',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  reward['image_url'] ?? '',
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    height: 150,
                                    color: Colors.grey[200],
                                    child: const Center(
                                        child: Icon(Icons.card_giftcard,
                                            size: 40, color: Colors.grey)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // DESKRIPSI & S&K
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Deskripsi",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                  reward['description'] ??
                                      'Tidak ada deskripsi.',
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.5)),
                              const SizedBox(height: 24),
                              const Text("Syarat & Ketentuan",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                reward['terms_condition'] ??
                                    '1. Tunjukkan kode ke kasir.\n2. Berlaku untuk 1x penukaran.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 200),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM BAR KODE VOUCHER
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 6),
                        Text(statusText,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("KODE VOUCHER",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      uniqueCode,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: status == 'ACTIVE'
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey[400],
                        decoration: status == 'ACTIVE'
                            ? TextDecoration.none
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Tunjukkan kode ini kepada admin/kasir",
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';
import 'kyc_detail_page.dart';

class KycListPage extends StatefulWidget {
  const KycListPage({super.key});

  @override
  State<KycListPage> createState() => _KycListPageState();
}

class _KycListPageState extends State<KycListPage> with SingleTickerProviderStateMixin {
  final _admin = AdminSupabase.client;
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Data
  List<Map<String, dynamic>> _allProfiles = [];
  bool _isLoading = true;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // [PERBAIKAN] Beri jeda render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProfiles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      final data = await _admin
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allProfiles = List<Map<String, dynamic>>.from(data);
          _pendingCount = _allProfiles.where((p) => p['approval_status'] == 'PENDING').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      // [PERBAIKAN] Print error ke log
      debugPrint("ERROR FETCH KYC: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _filteredList(String status) {
    return _allProfiles.where((p) {
      final matchStatus = p['approval_status'] == status;
      if (_searchQuery.isEmpty) return matchStatus;
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final pic = (p['pic_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return matchStatus && (name.contains(query) || pic.contains(query));
    }).toList();
  }

  // Fungsi Navigasi ke Detail KYC (Bisa dipanggil dari Card maupun Table)
  void _openDetail(Map<String, dynamic> store) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => KycDetailPage(store: store),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    if (result == true) _fetchProfiles(); // Refresh jika ada perubahan status
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ======= SEARCH BAR =======
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Cari nama toko atau PIC...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ======= TAB BAR =======
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFFB71C1C),
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Pending'),
                      if (_pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFB71C1C), borderRadius: BorderRadius.circular(10)),
                          child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Approved'),
                const Tab(text: 'Rejected'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ======= TAB CONTENT =======
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildResponsiveList('PENDING'),
              _buildResponsiveList('APPROVED'),
              _buildResponsiveList('REJECTED'),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET: DETEKSI LAYAR (RESPONSIF) ---
  Widget _buildResponsiveList(String status) {
    if (_isLoading) return _buildShimmerList();

    final list = _filteredList(status);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'PENDING' ? Icons.hourglass_empty_rounded : status == 'APPROVED' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
              size: 48, color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? 'Tidak ada hasil untuk "$_searchQuery"'
                  : status == 'PENDING' ? 'Tidak ada user menunggu verifikasi'
                  : status == 'APPROVED' ? 'Belum ada user yang disetujui' : 'Belum ada user yang ditolak',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Cek lebar layar di sini
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _fetchProfiles,
      child: isDesktop 
          ? _buildDesktopTable(list) // Munculkan Tabel di PC
          : ListView.builder(        // Munculkan List Biasa di HP
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: list.length,
              itemBuilder: (context, index) {
                return _StoreCard(
                  store: list[index],
                  index: index,
                  onTap: () => _openDetail(list[index]),
                );
              },
            ),
    );
  }

// --- WIDGET: TABEL UNTUK DESKTOP (DIPERBAIKI) ---
  Widget _buildDesktopTable(List<Map<String, dynamic>> list) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Container(
        width: double.infinity, // [PENTING] Memaksa tabel agar memanjang penuh
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              // [PENTING] Memastikan lebar tabel minimal selebar layar meskipun isinya sedikit
              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 290), // Dikurangi lebar sidebar + padding
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8F9FC)),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 64,
                horizontalMargin: 24,
                columnSpacing: 32, // Jarak antar kolom
                columns: const [
                  DataColumn(label: Expanded(child: Text('Nama Toko', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  DataColumn(label: Expanded(child: Text('Penanggung Jawab', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  DataColumn(label: Expanded(child: Text('Domisili', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))))),
                  DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                  DataColumn(label: Text('Aksi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280)))),
                ],
                rows: list.map((store) {
                  final name = store['full_name'] ?? 'Tanpa Nama';
                  final pic = store['pic_name'] ?? '-';
                  final domisili = store['domisili'] ?? store['domicile'] ?? '-';
                  final status = store['approval_status'] ?? 'PENDING';
                  
                  String dateStr = '-';
                  if (store['created_at'] != null) {
                    try {
                      final dt = DateTime.parse(store['created_at']).toLocal();
                      dateStr = '${dt.day}/${dt.month}/${dt.year}';
                    } catch (_) {}
                  }

                  // Warna Badge Status
                  Color statusColor; Color statusBg; String statusLabel;
                  if (status == 'APPROVED') {
                    statusColor = const Color(0xFF059669); statusBg = const Color(0xFFECFDF5); statusLabel = 'Approved';
                  } else if (status == 'REJECTED') {
                    statusColor = const Color(0xFFDC2626); statusBg = const Color(0xFFFEF2F2); statusLabel = 'Rejected';
                  } else {
                    statusColor = const Color(0xFFD97706); statusBg = const Color(0xFFFFFBEB); statusLabel = 'Pending';
                  }

                  return DataRow(
                    cells: [
                      DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)))),
                      DataCell(Text(pic, style: TextStyle(color: Colors.grey[700]))),
                      DataCell(Text(domisili, style: TextStyle(color: Colors.grey[700]))),
                      DataCell(Text(dateStr, style: TextStyle(color: Colors.grey[600]))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      ),
                      DataCell(
                        ElevatedButton.icon(
                          onPressed: () => _openDetail(store),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('Review', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            foregroundColor: const Color(0xFF1A1A2E),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        )
                      ),
                    ]
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET: LOADING SHIMMER ---
  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              _shimmerBox(46, 46, radius: 12),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(14, 140),
                    const SizedBox(height: 8),
                    _shimmerBox(12, 100),
                  ],
                ),
              ),
              _shimmerBox(28, 28, radius: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double height, double width, {double radius = 6}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          height: height, width: width,
          decoration: BoxDecoration(color: Colors.grey[200]!.withOpacity(value), borderRadius: BorderRadius.circular(radius)),
        );
      },
      onEnd: () {}, 
    );
  }
}

// ======= STORE CARD WIDGET (UNTUK MOBILE) =======
class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final int index;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final String name = store['full_name'] ?? 'Tanpa Nama';
    final String pic = store['pic_name'] ?? '-';
    final String status = store['approval_status'] ?? 'PENDING';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    String dateStr = '-';
    if (store['created_at'] != null) {
      try {
        final dt = DateTime.parse(store['created_at']).toLocal();
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {}
    }

    Color statusColor; Color statusBg; IconData statusIcon;
    switch (status) {
      case 'APPROVED': statusColor = const Color(0xFF059669); statusBg = const Color(0xFFECFDF5); statusIcon = Icons.check_circle_rounded; break;
      case 'REJECTED': statusColor = const Color(0xFFDC2626); statusBg = const Color(0xFFFEF2F2); statusIcon = Icons.cancel_rounded; break;
      default: statusColor = const Color(0xFFD97706); statusBg = const Color(0xFFFFFBEB); statusIcon = Icons.schedule_rounded;
    }

    final List<List<Color>> gradients = [
      [const Color(0xFFB71C1C), const Color(0xFFE53935)],
      [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
      [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
      [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
      [const Color(0xFFE65100), const Color(0xFFFF9800)],
    ];
    final gradient = gradients[index % gradients.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey[400]), const SizedBox(width: 4),
                        Flexible(child: Text(pic, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey[400]), const SizedBox(width: 4),
                        Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)), child: Icon(statusIcon, color: statusColor, size: 18)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
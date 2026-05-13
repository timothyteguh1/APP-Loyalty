import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../accurate/accurate_service.dart';
import '../admin_supabase.dart';

class UnregisteredCustomersPage extends StatefulWidget {
  const UnregisteredCustomersPage({super.key});

  @override
  State<UnregisteredCustomersPage> createState() =>
      _UnregisteredCustomersPageState();
}

class _UnregisteredCustomersPageState extends State<UnregisteredCustomersPage> {
  final _supabase = AdminSupabase.client;
  final AccurateService _accurateService = AccurateService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  final TextEditingController _searchController = TextEditingController();

  // State untuk AJAX dan Filter
  String _searchKeyword = '';
  String _statusFilter = 'ALL';
  Timer? _debounceTimer;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fetchAndCompareCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAndCompareCustomers() async {
    if (!mounted) return;
    setState(() {
      if (_allCustomers.isEmpty) _isLoading = true;
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      if (_statusFilter == 'ACTIVE') {
        // ==============================================================
        // [LOGIKA PUTAR BALIK] - Khusus "Aktif Saja"
        // Ambil langsung dari Supabase, abaikan limit 100 dari Accurate!
        // accurate_customer_id sekarang sudah berisi customerNo (C.0001)
        // ==============================================================
        final registeredData = await _supabase
            .from('profiles')
            .select('full_name, accurate_customer_id')
            .not('accurate_customer_id', 'is', null)
            .neq('accurate_customer_id', '');

        List<Map<String, dynamic>> activeCustomers = registeredData.map((p) {
          // Normalisasi ke UPPERCASE untuk konsistensi
          final custNo = AccurateService.normalizeCustomerNo(
            p['accurate_customer_id']?.toString() ?? '',
          );
          return {
            'name': p['full_name'] ?? 'Tanpa Nama',
            'customerNo': custNo, // No. Pelanggan (C.0001)
            'id': custNo,         // id = customerNo agar konsisten
            'mobilePhone': '-',
            'isRegistered': true,
          };
        }).toList();

        // Jika ada pencarian, filter data Supabase secara lokal
        if (_searchKeyword.isNotEmpty) {
          final kw = _searchKeyword.toLowerCase();
          activeCustomers = activeCustomers.where((c) {
            return c['name'].toString().toLowerCase().contains(kw) ||
                c['customerNo'].toString().toLowerCase().contains(kw);
          }).toList();
        }

        if (mounted) {
          setState(() {
            _allCustomers = activeCustomers;
            _filteredCustomers = activeCustomers;
            _isLoading = false;
            _isSearching = false;
          });
        }
      } else {
        // ==============================================================
        // [LOGIKA NORMAL] - Untuk "Tidak Aktif" atau "Semua Status"
        // Ambil dari API Accurate, lalu cocokkan berdasarkan customerNo
        // PERUBAHAN: bandingkan customerNo (bukan internal ID angka)
        // ==============================================================
        final accurateCustomers = await _accurateService.getAccurateCustomers(
          keyword: _searchKeyword,
          statusFilter: 'ALL',
        );

        final registeredData = await _supabase
            .from('profiles')
            .select('accurate_customer_id')
            .not('accurate_customer_id', 'is', null)
            .neq('accurate_customer_id', '');

        // Set berisi customerNo yang sudah terdaftar (UPPERCASE)
        final Set<String> registeredNos = registeredData
            .map((p) => AccurateService.normalizeCustomerNo(
                  p['accurate_customer_id']?.toString() ?? '',
                ))
            .where((s) => s.isNotEmpty)
            .toSet();

        final mappedCustomers = accurateCustomers.map((customer) {
          // PERUBAHAN UTAMA: gunakan customerNo sebagai identifier,
          // bukan internal ID angka
          final custNo = AccurateService.normalizeCustomerNo(
            customer['customerNo']?.toString() ?? '',
          );
          return {
            ...customer,
            // Override field 'id' agar seluruh UI pakai customerNo (C.0001)
            'id': custNo,
            'isRegistered': custNo.isNotEmpty && registeredNos.contains(custNo),
          };
        }).toList();

        // Terapkan Filter INACTIVE secara lokal
        List<Map<String, dynamic>> finalResult = mappedCustomers;
        if (_statusFilter == 'INACTIVE') {
          finalResult =
              mappedCustomers.where((c) => c['isRegistered'] == false).toList();
        }

        finalResult.sort((a, b) {
          if (a['isRegistered'] == b['isRegistered']) return 0;
          return a['isRegistered'] ? 1 : -1;
        });

        if (mounted) {
          setState(() {
            _allCustomers = mappedCustomers;
            _filteredCustomers = finalResult;
            _isLoading = false;
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('Kredensial')
              ? 'Silakan sambungkan ulang Accurate di menu Integrasi.'
              : 'Gagal memuat data: $e';
          _isLoading = false;
          _isSearching = false;
        });
      }
    }
  }

  void _onFilterChanged(String? newValue) {
    if (newValue != null && newValue != _statusFilter) {
      setState(() {
        _statusFilter = newValue;
      });
      _fetchAndCompareCustomers();
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchKeyword = value);

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAndCompareCustomers();
    });
  }

  // PERUBAHAN: Salin No. Pelanggan (C.0001), bukan internal ID angka
  void _copyToClipboard(String customerNo) {
    Clipboard.setData(ClipboardData(text: customerNo));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              'No. Pelanggan "$customerNo" disalin!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Status Pelanggan Accurate',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAndCompareCustomers,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Cari nama toko atau no. pelanggan...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF94A3B8),
                                ),
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'ALL',
                              child: Text('Semua Status',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'ACTIVE',
                              child: Text('Aktif Saja',
                                  style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(
                              value: 'INACTIVE',
                              child: Text('Tidak Aktif',
                                  style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: _onFilterChanged,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isLoading && _errorMessage == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Text(
                    'Menampilkan ${_filteredCustomers.length} pelanggan Accurate:',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFB71C1C),
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFEE2E2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cloud_off_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: _fetchAndCompareCustomers,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 18),
                                    label: const Text('Coba Lagi'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB71C1C),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _filteredCustomers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.group_off_rounded,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Data Kosong',
                                      style: TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : isDesktop
                                ? _buildDesktopTable()
                                : _buildMobileList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFFF8F9FC)),
            dataRowMinHeight: 60,
            dataRowMaxHeight: 60,
            horizontalMargin: 24,
            columnSpacing: 24,
            columns: const [
              DataColumn(
                label: Expanded(
                  child: Text(
                    'Nama Pelanggan',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Kode',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ),
              // PERUBAHAN: label diubah dari "System ID" ke "No. Pelanggan"
              DataColumn(
                label: Text(
                  'No. Pelanggan',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Telepon',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Status',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ),
              DataColumn(
                label: Text(
                  'Aksi',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                ),
              ),
            ],
            rows: _filteredCustomers.map((c) {
              final name = c['name'] ?? 'Tanpa Nama';
              final customerNo = c['customerNo'] ?? '-';
              // PERUBAHAN: 'id' sekarang sudah berisi customerNo (C.0001)
              final displayNo = c['id']?.toString() ?? '';
              final phone = c['mobilePhone'] ?? '-';
              final isRegistered = c['isRegistered'] == true;
              final statusColor = isRegistered
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626);
              final statusBg = isRegistered
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2);
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      customerNo,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  DataCell(
                    Text(
                      displayNo,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(
                    Text(
                      phone,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isRegistered ? 'Aktif' : 'Tidak Aktif',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    // PERUBAHAN: salin customerNo (C.0001), bukan internal ID
                    !isRegistered
                        ? GestureDetector(
                            onTap: () => _copyToClipboard(displayNo),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy_rounded,
                                      size: 14, color: Color(0xFF3B82F6)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Salin No.',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        final name = customer['name'] ?? 'Tanpa Nama';
        final customerNo = customer['customerNo'] ?? '-';
        // PERUBAHAN: 'id' sekarang berisi customerNo (C.0001)
        final displayNo = customer['id']?.toString() ?? '';
        final phone = customer['mobilePhone'] ?? '-';
        final isRegistered = customer['isRegistered'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRegistered
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isRegistered
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: isRegistered
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRegistered
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRegistered
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isRegistered
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isRegistered ? 'Aktif' : 'Tidak Aktif',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isRegistered
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tag_rounded,
                                  size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              // PERUBAHAN: tampilkan customerNo sebagai identifier utama
                              Text(
                                '$customerNo  •  $displayNo',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // PERUBAHAN: salin customerNo (C.0001), bukan internal ID
                        if (!isRegistered)
                          InkWell(
                            onTap: () => _copyToClipboard(displayNo),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded,
                                      size: 14, color: Color(0xFF3B82F6)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Salin No.',
                                    style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 6),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
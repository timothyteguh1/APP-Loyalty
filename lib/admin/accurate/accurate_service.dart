import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upsol_loyalty/admin/admin_supabase.dart';

class AccurateService {
  final _supabase = Supabase.instance.client;

  static const String defaultClientId = '79aaa170-8897-4cf7-b0d1-b8ec78dd07d1';
  static const String defaultDbId = '2663607';

  static String get _redirectUri {
    return '${Uri.base.origin}/oauth_callback.html';
  }
  static const String _oauthBaseUrl = 'https://account.accurate.id';
  static const String _scope =
      'sales_invoice_view customer_view item_view sales_invoice_save sales_return_view';

  // =========================================================================
  // HELPER: Normalisasi customerNo → selalu UPPERCASE (C.0001 bukan c.0001)
  // =========================================================================
  static String normalizeCustomerNo(String raw) => raw.trim().toUpperCase();

  // =========================================================================
  // Tanggal mulai dinamis: selalu 1 Januari tahun berjalan
  // =========================================================================
  static String get _dateStartCurrentYear {
    final year = DateTime.now().year;
    return '01/01/$year';
  }

  static Future<Map<String, dynamic>> _proxy({
    required String accurateUrl,
    Map<String, String>? headers,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']!;
    final proxyUrl = '$supabaseUrl/functions/v1/accurate-proxy';

    final response = await http.post(
      Uri.parse(proxyUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseKey',
        'apikey': supabaseKey,
      },
      body: jsonEncode({
        'accurate_url': accurateUrl,
        'accurate_headers': headers ?? {},
        'method': method,
        if (body != null) 'accurate_body': body,
      }),
    );

    if (response.statusCode != 200) {
      throw 'Proxy error ${response.statusCode}: ${response.body}';
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static String buildAuthUrl(String clientId) {
    final params = {
      'client_id': clientId,
      'response_type': 'token',
      'redirect_uri': _redirectUri,
      'scope': _scope,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_oauthBaseUrl/oauth/authorize?$query';
  }

  static Future<void> saveCredentials(SupabaseClient admin, String clientId, String dbId) async {
    await admin.from('app_config').upsert([
      {'key': 'accurate_client_id', 'value': clientId},
      {'key': 'accurate_target_db_id', 'value': dbId},
    ], onConflict: 'key');
  }

  static Future<void> saveToken(SupabaseClient admin, String accessToken) async {
    final expiry = DateTime.now().add(const Duration(days: 14)).toIso8601String();
    final configs = [
      {'key': 'accurate_access_token', 'value': accessToken},
      {'key': 'accurate_token_expiry', 'value': expiry},
      {'key': 'accurate_db_session', 'value': ''},
      {'key': 'accurate_db_host', 'value': ''},
    ];
    for (final c in configs) {
      await admin.from('app_config').upsert(c, onConflict: 'key');
    }
  }

  static Future<Map<String, String>> loadConfig(SupabaseClient admin) async {
    final rows = await admin.from('app_config').select('key, value').inFilter('key', [
      'accurate_access_token', 'accurate_token_expiry', 'accurate_db_session',
      'accurate_db_host', 'accurate_db_id', 'accurate_client_id', 'accurate_target_db_id',
    ]);
    final config = <String, String>{};
    for (final row in rows) {
      config[row['key']] = row['value'] ?? '';
    }
    if ((config['accurate_client_id'] ?? '').isEmpty) config['accurate_client_id'] = defaultClientId;
    if ((config['accurate_target_db_id'] ?? '').isEmpty) config['accurate_target_db_id'] = defaultDbId;
    return config;
  }

  static bool isTokenValid(Map<String, String> config) {
    final token = config['accurate_access_token'] ?? '';
    final expiry = config['accurate_token_expiry'] ?? '';
    if (token.isEmpty) return false;
    if (expiry.isEmpty) return true;
    try {
      return DateTime.now().isBefore(DateTime.parse(expiry));
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDatabaseList(String accessToken) async {
    final data = await _proxy(
      accurateUrl: '$_oauthBaseUrl/api/db-list.do',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (data['s'] != true) throw data['d']?.toString() ?? 'Gagal ambil daftar database';
    final List<dynamic> dbs = data['d'] ?? [];
    return dbs.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, String>> openDatabase(String accessToken, String dbId) async {
    final dbList = await fetchDatabaseList(accessToken);
    Map<String, dynamic>? targetDb;
    for (final db in dbList) {
      final uid = db['uid']?.toString() ?? '';
      final id = db['id']?.toString() ?? '';
      if (uid == dbId || id == dbId) { targetDb = db; break; }
    }
    targetDb ??= dbList.isNotEmpty ? dbList.first : null;
    if (targetDb == null) throw 'Tidak ada database ditemukan';

    final realId = targetDb['id']?.toString() ?? dbId;
    final data = await _proxy(
      accurateUrl: '$_oauthBaseUrl/api/open-db.do?id=$realId',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (data['s'] != true) throw data['d']?.toString() ?? 'Gagal buka database';
    final host = data['host']?.toString() ?? 'https://public.accurate.id';
    final session = data['session']?.toString() ?? '';
    if (session.isEmpty) throw 'Session tidak ditemukan';
    return {'host': host, 'session': session};
  }

  static Future<void> saveSession(SupabaseClient admin, String dbId, String host, String session) async {
    final configs = [
      {'key': 'accurate_db_id', 'value': dbId},
      {'key': 'accurate_db_host', 'value': host},
      {'key': 'accurate_db_session', 'value': session},
    ];
    for (final c in configs) {
      await admin.from('app_config').upsert(c, onConflict: 'key');
    }
  }

  // =========================================================================
  // PRE-LOAD SEMUA FAKTUR dari rentang tanggal (tanpa filter customer)
  // Lalu group by customerNo ke Map untuk lookup O(1) per user.
  //
  // Alasan: Accurate API tidak support filter.customer secara reliable.
  // Faktur lama (nomor kecil) ada di halaman ke-2, ke-3, dst. yang tidak
  // terambil kalau pakai filter per-user + pageSize=50.
  // Dengan pre-load semua halaman sekali, tidak ada faktur yang terlewat.
  // =========================================================================
  static Future<Map<String, List<Map<String, dynamic>>>> _preloadAllInvoices({
    required String host,
    required String session,
    required String token,
    Function(String)? onProgress,
  }) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    int page = 1;
    int totalLoaded = 0;
    bool hasMore = true;

    while (hasMore) {
      onProgress?.call('Memuat semua faktur halaman $page...');
      print('  -> [PRE-LOAD FAKTUR] Halaman $page...');

      final params = <String, String>{
        'sp.page': '$page',
        'sp.pageSize': '100', 
        // --- PERBAIKAN DI SINI ---
        'fields':
            'id,number,transDate,dueDate,grandTotal,totalAmount,statusName,status,'
            'customer', // CUKUP TULIS 'customer' SAJA
        // -------------------------
        'filter.transDate.val[0]': _dateStartCurrentYear,
        'filter.transDate.val[1]': '31/12/2099',
        'filter.transDate.op': 'BETWEEN',
      };
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = '$host/accurate/api/sales-invoice/list.do?$queryString';

      final data = await _proxy(
        accurateUrl: url,
        headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
      );

      if (data['s'] == false) {
        if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
        throw data['d']?.toString() ?? 'Gagal ambil faktur';
      }

      final List<dynamic> invoices = data['d'] ?? [];
      final int totalCount = (data['totalCount'] as num?)?.toInt() ?? 0;

     for (final invoice in invoices) {
        // --- LOGIKA PEMBACAAN CUSTOMER YANG TAHAN BANTING ---
        String rawCustNo = '';
        
        // 1. Coba baca jika bentuknya nested object: "customer": {"no": "..."}
        if (invoice['customer'] is Map) {
          rawCustNo = invoice['customer']['customerNo']?.toString() ?? 
                      invoice['customer']['no']?.toString() ?? '';
        }
        
        // 2. Jika masih kosong, coba baca jika bentuknya flat key: "customer.no": "..."
        if (rawCustNo.isEmpty) {
          rawCustNo = invoice['customer.customerNo']?.toString() ?? 
                      invoice['customer.no']?.toString() ?? '';
        }

        final String custNo = normalizeCustomerNo(rawCustNo);
        // ---------------------------------------------------

        if (custNo.isEmpty) continue;
        grouped.putIfAbsent(custNo, () => []).add(Map<String, dynamic>.from(invoice));
      }

      totalLoaded += invoices.length;
      print('  -> [PRE-LOAD FAKTUR] Halaman $page: ${invoices.length} item, total dimuat: $totalLoaded / $totalCount');

      hasMore = invoices.isNotEmpty;
      page++;
      if (page > 100) hasMore = false; // safety cap: max 1000 halaman = 100000 faktur
    }

    print('  -> [PRE-LOAD FAKTUR] Selesai. Total faktur: $totalLoaded, '
        'unique customerNo: ${grouped.keys.length}');
    return grouped;
  }

  // =========================================================================
  // PRE-LOAD SEMUA RETUR dari rentang tanggal (tanpa filter customer)
  // Strategi sama dengan pre-load faktur di atas.
  // =========================================================================
  static Future<Map<String, List<Map<String, dynamic>>>> _preloadAllReturns({
    required String host,
    required String session,
    required String token,
    Function(String)? onProgress,
  }) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    int page = 1;
    int totalLoaded = 0;
    bool hasMore = true;

    while (hasMore) {
      onProgress?.call('Memuat semua retur halaman $page...');
      print('  -> [PRE-LOAD RETUR] Halaman $page...');

      final params = <String, String>{
        'sp.page': '$page',
        'sp.pageSize': '100',
        // --- PERBAIKAN DI SINI ---
        'fields':
            'id,number,transDate,totalAmount,grandTotal,statusName,status,'
            'customer', // CUKUP TULIS 'customer' SAJA
        // -------------------------
        'filter.transDate.val[0]': _dateStartCurrentYear,
        'filter.transDate.val[1]': '31/12/2099',
        'filter.transDate.op': 'BETWEEN',
      };

      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final data = await _proxy(
        accurateUrl: '$host/accurate/api/sales-return/list.do?$queryString',
        headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
      );

      if (data['s'] == false) {
        if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
        throw data['d']?.toString() ?? 'Gagal ambil retur';
      }

      final List<dynamic> returns = data['d'] ?? [];
      final int totalCount = (data['totalCount'] as num?)?.toInt() ?? 0;

      for (final ret in returns) {
        final String custNo = normalizeCustomerNo(
          ret['customer']?['customerNo']?.toString() ??
          ret['customer.customerNo']?.toString() ?? '',
        );
        if (custNo.isEmpty) continue;
        grouped.putIfAbsent(custNo, () => []).add(Map<String, dynamic>.from(ret));
      }

      totalLoaded += returns.length;
      print('  -> [PRE-LOAD RETUR] Halaman $page: ${returns.length} item, total dimuat: $totalLoaded / $totalCount');

      hasMore = returns.isNotEmpty;
      page++;
      if (page > 50) hasMore = false;
    }

    print('  -> [PRE-LOAD RETUR] Selesai. Total retur: $totalLoaded, '
        'unique customerNo: ${grouped.keys.length}');
    return grouped;
  }

  static Future<Map<String, dynamic>> fetchInvoiceDetail(
    String host, String session, String token, int invoiceId,
  ) async {
    final url = '$host/accurate/api/sales-invoice/detail.do?id=$invoiceId';
    final data = await _proxy(
      accurateUrl: url,
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );
    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil detail faktur';
    }
    return data;
  }

  static Future<Map<String, dynamic>> fetchReturnDetail(
    String host, String session, String token, int returnId,
  ) async {
    final url = '$host/accurate/api/sales-return/detail.do?id=$returnId';
    final data = await _proxy(
      accurateUrl: url,
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );
    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil detail retur';
    }
    return data;
  }

  static bool _isInvoiceFullyPaid(Map<String, dynamic> detail) {
    final String statusName = (detail['statusName'] ?? '').toString();
    final String status = (detail['status'] ?? '').toString().toUpperCase();
    if (statusName.toLowerCase().contains('belum')) return false;
    if (status == 'OUTSTANDING') return false;
    if (detail['outstanding'] == true) return false;
    if (status == 'PAID') return true;
    final String statusUpper = statusName.toUpperCase();
    if (statusUpper == 'LUNAS') return true;
    if (statusUpper == 'CLOSED') return true;
    final double primeOwing = (detail['primeOwing'] as num?)?.toDouble() ?? -1;
    final double primeReceipt = (detail['primeReceipt'] as num?)?.toDouble() ?? 0;
    if (primeOwing == 0 && primeReceipt > 0) return true;
    final receiptHistory = detail['receiptHistory'];
    if (receiptHistory is List && receiptHistory.isNotEmpty) {
      final double totalAmount = (detail['totalAmount'] as num?)?.toDouble() ?? 0;
      double totalPaid = 0;
      for (final receipt in receiptHistory) {
        totalPaid += (receipt['historyAmount'] as num?)?.toDouble() ?? 0;
      }
      if (totalAmount > 0 && totalPaid >= totalAmount) return true;
    }
    final remaining = detail['remainingPayment'] ?? detail['remainingAmount'];
    if (remaining != null) {
      final double remainVal = (remaining as num?)?.toDouble() ?? -1;
      if (remainVal == 0) return true;
    }
    return false;
  }

  static DateTime? _getPaymentDate(Map<String, dynamic> detail) {
    final candidates = [
      detail['lastPaymentDate'], detail['closeDate'],
      detail['closedDate'], detail['paymentDate'],
    ];
    for (final raw in candidates) {
      if (raw == null) continue;
      final str = raw.toString().trim();
      if (str.isEmpty) continue;
      try {
        if (str.contains('/')) return DateTime.parse(_parseAccurateDate(str));
        return DateTime.parse(str);
      } catch (_) { continue; }
    }
    final receiptHistory = detail['receiptHistory'];
    if (receiptHistory is List && receiptHistory.isNotEmpty) {
      final lastReceipt = receiptHistory.last;
      final historyDate = lastReceipt['historyDate']?.toString().trim() ?? '';
      if (historyDate.isNotEmpty) {
        try {
          if (historyDate.contains('/')) return DateTime.parse(_parseAccurateDate(historyDate));
          return DateTime.parse(historyDate);
        } catch (_) {}
      }
    }
    return null;
  }

  // =========================================================================
  // FUNGSI UTAMA SYNC
  //
  // Arsitektur baru (pre-load lokal):
  //   Step 1: Pre-load SEMUA faktur → group by customerNo ke Map
  //   Step 2: Pre-load SEMUA retur  → group by customerNo ke Map
  //   Step 3: Untuk setiap user, lookup dari Map → proses lokal
  //
  // Keunggulan vs pendekatan lama (filter per-user):
  //   - Tidak ada faktur yang terlewat karena pagination (FP.00876 dll.)
  //   - Jumlah API call jauh lebih sedikit (N_page vs N_user × N_page)
  //   - Filter customer Accurate API yg tidak reliable tidak jadi masalah
  // =========================================================================
  static Future<SyncResult> syncInvoicesToPoints({
    required SupabaseClient admin,
    required String host,
    required String session,
    Function(String)? onProgress,
  }) async {
    int totalInvoicesChecked = 0;
    int totalReturnsChecked = 0;
    int totalPointsAdded = 0;
    int totalPointsDeducted = 0;
    int totalUsersAffected = 0;
    int totalSkipped = 0;
    final List<String> errors = [];

    try {
      print('\n=== MULAI SYNC (Arsitektur Pre-Load Lokal) ===\n');
      // === KODE DEBUG TEMBAK LANGSUNG (HAPUS NANTI) ===
      print('🔍 [DEBUG] Mencari langsung faktur FP.00876.052026 di Accurate...');

      final tokenConfig = await admin
          .from('app_config').select('value')
          .eq('key', 'accurate_access_token').maybeSingle();
      final String token = tokenConfig?['value']?.toString() ?? '';
      if (token.isEmpty) throw 'Token Authorization tidak ditemukan di sistem.';

      final testUrl = '$host/accurate/api/sales-invoice/list.do'
          '?fields=id,number,customer.customerNo,statusName'
          '&filter.number.op=EQUAL&filter.number.val[0]=FP.00876.052026';
      
      final testRes = await _proxy(
        accurateUrl: testUrl,
        headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
      );
      
      if (testRes['s'] == true && testRes['d'] != null) {
        final List testData = testRes['d'];
        if (testData.isEmpty) {
          print('❌ [DEBUG] Faktur TIDAK DITEMUKAN di database Accurate.');
        } else {
          for (var item in testData) {
            // KITA CETAK SELURUH DATA MENTAHNYA
            print('✅ [DEBUG] DATA MENTAH DARI API:');
            print(item.toString()); 
          }
        }
      }
      // ================================================
      print('  -> [INFO] Filter tanggal mulai: $_dateStartCurrentYear');

      // ─────────────────────────────────────────────────────────────────────
      // Step 1 & 2: Pre-load semua faktur & retur sekaligus (satu kali)
      // Ini menggantikan loop fetch per-user yang melewatkan halaman ke-2+
      // ─────────────────────────────────────────────────────────────────────
      onProgress?.call('Memuat semua faktur dari Accurate...');
      final Map<String, List<Map<String, dynamic>>> allInvoicesByCustomer =
          await _preloadAllInvoices(
            host: host, session: session, token: token, onProgress: onProgress,
          );

      onProgress?.call('Memuat semua retur dari Accurate...');
      final Map<String, List<Map<String, dynamic>>> allReturnsByCustomer =
          await _preloadAllReturns(
            host: host, session: session, token: token, onProgress: onProgress,
          );

      final int totalInvoicesLoaded = allInvoicesByCustomer.values.fold(0, (s, l) => s + l.length);
      final int totalReturnsLoaded = allReturnsByCustomer.values.fold(0, (s, l) => s + l.length);
      print('\n=> Pre-load selesai: $totalInvoicesLoaded faktur, $totalReturnsLoaded retur\n');

      // ─────────────────────────────────────────────────────────────────────
      // Step 3: Ambil daftar user dari database
      // ─────────────────────────────────────────────────────────────────────
      onProgress?.call('Mencari data user...');
      final users = await admin
          .from('profiles')
          .select('id, full_name, points, accurate_customer_id, point_conversion_rate')
          .eq('approval_status', 'APPROVED')
          .not('accurate_customer_id', 'is', null)
          .neq('accurate_customer_id', '');

      print('=> Ditemukan ${users.length} toko/user yang valid di database untuk disync.');

      if (users.isEmpty) {
        return SyncResult(
          message: 'Tidak ada user valid.',
          totalInvoicesChecked: 0, totalPointsAdded: 0,
          totalUsersAffected: 0, totalSkipped: 0,
        );
      }

      final globalConfig = await admin
          .from('app_config').select('value')
          .eq('key', 'default_conversion_rate').maybeSingle();
      final int globalRate = int.tryParse(globalConfig?['value'] ?? '10000') ?? 10000;

      // ─────────────────────────────────────────────────────────────────────
      // Step 4: Proses setiap user dari data yang sudah di-cache di Map
      // ─────────────────────────────────────────────────────────────────────
      for (final user in users) {
        final String userId = user['id'];
        final String userName = user['full_name'] ?? 'Unknown';
        final String accurateCustomerNo = normalizeCustomerNo(
          user['accurate_customer_id'].toString(),
        );
        if (accurateCustomerNo.isEmpty) continue;

        final int conversionRate = (user['point_conversion_rate'] as num?)?.toInt() ?? globalRate;

        print('\n=== Memeriksa Toko: $userName (No. Pelanggan: $accurateCustomerNo) ===');
        onProgress?.call('Sync Toko: $userName...');

        try {
          // Ambil faktur & retur untuk user ini dari cache Map (O(1))
          final List<Map<String, dynamic>> userInvoices =
              allInvoicesByCustomer[accurateCustomerNo] ?? [];
          final List<Map<String, dynamic>> userReturns =
              allReturnsByCustomer[accurateCustomerNo] ?? [];

          print('  -> Faktur ditemukan: ${userInvoices.length}, Retur: ${userReturns.length}');

          int userPointsGained = 0;

          final existingHistory = await admin
              .from('point_history')
              .select('reference_id, reference_type, created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: true);

          final Set<String> claimedInvoices = {};
          final Set<String> claimedReturns = {};
          for (var history in existingHistory) {
            final type = history['reference_type'];
            final refId = history['reference_id']?.toString() ?? '';
            if (type == 'INVOICE') claimedInvoices.add(refId);
            if (type == 'RETURN') claimedReturns.add(refId);
          }

          // =============================================
          // 1. PROSES FAKTUR PENJUALAN (dari cache lokal)
          // =============================================
          if (userInvoices.isEmpty) {
            print('  -> (Tidak ada faktur untuk $userName di Accurate)');
          }

          for (final invoice in userInvoices) {
            final String invoiceNumber = invoice['number']?.toString() ?? '';
            final int invoiceId = (invoice['id'] as num?)?.toInt() ?? 0;

            if (invoiceNumber.isEmpty) continue;

            // Skip faktur berawalan "SI"
            if (invoiceNumber.toUpperCase().startsWith('SI')) {
              print('  -> [SKIP] Faktur $invoiceNumber diawali "SI", tidak diproses poin.');
              totalSkipped++;
              continue;
            }

            if (claimedInvoices.contains(invoiceNumber)) {
              print('  -> [SUDAH KLAIM] Faktur $invoiceNumber sudah pernah ditukar poin. Melewati...');
              continue;
            }

            totalInvoicesChecked++;
            if (invoiceId <= 0) { totalSkipped++; continue; }

            // Cross-check customerNo (double-check dari data cache)
            final String listCustNo = normalizeCustomerNo(
              invoice['customer']?['customerNo']?.toString() ??
              invoice['customer.customerNo']?.toString() ?? '',
            );
            if (listCustNo.isNotEmpty && listCustNo != accurateCustomerNo) {
              print('  -> [SKIP MUTLAK] Faktur $invoiceNumber milik $listCustNo, bukan $accurateCustomerNo!');
              totalSkipped++;
              continue;
            }

            onProgress?.call('Cek detail $invoiceNumber...');
            Map<String, dynamic> detailData;
            try {
              final detailResponse = await fetchInvoiceDetail(host, session, token, invoiceId);
              detailData = (detailResponse['d'] is Map)
                  ? Map<String, dynamic>.from(detailResponse['d']) : {};
            } catch (e) {
              errors.add('Faktur $invoiceNumber: Gagal ambil detail');
              totalSkipped++;
              continue;
            }

            // Cross-check MUTLAK customerNo di level detail
            final String detailCustNo = normalizeCustomerNo(
              detailData['customer']?['customerNo']?.toString() ?? '',
            );
            if (detailCustNo.isNotEmpty && detailCustNo != accurateCustomerNo) {
              print('  -> [SKIP MUTLAK] Faktur $invoiceNumber aslinya milik $detailCustNo, '
                  'bukan $userName ($accurateCustomerNo)! DITOLAK!');
              totalSkipped++;
              continue;
            }

            if (!_isInvoiceFullyPaid(detailData)) {
              print('  -> [SKIP] Faktur $invoiceNumber: BELUM LUNAS.');
              totalSkipped++;
              continue;
            }

            final String dueDateStr =
                detailData['dueDate']?.toString() ?? invoice['dueDate']?.toString() ?? '';
            if (dueDateStr.isNotEmpty) {
              final DateTime dueDate = DateTime.parse(_parseAccurateDate(dueDateStr));
              final DateTime? paymentDate = _getPaymentDate(detailData);
              if (paymentDate != null) {
                if (paymentDate.isAfter(dueDate)) {
                  print('  -> [SKIP] Faktur $invoiceNumber: TELAT BAYAR.');
                  totalSkipped++;
                  continue;
                }
              } else {
                if (DateTime.now().isAfter(dueDate)) {
                  print('  -> [SKIP] Faktur $invoiceNumber: Melewati jatuh tempo.');
                  totalSkipped++;
                  continue;
                }
              }
            }

            final double nominalFaktur =
                (detailData['grandTotal'] as num?)?.toDouble() ??
                (detailData['totalAmount'] as num?)?.toDouble() ??
                (invoice['grandTotal'] as num?)?.toDouble() ??
                (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
            if (nominalFaktur <= 0) { totalSkipped++; continue; }

            final int pointsEarned = (nominalFaktur / conversionRate).floor();
            if (pointsEarned <= 0) { totalSkipped++; continue; }

            await admin.from('point_history').insert({
              'user_id': userId,
              'amount': pointsEarned,
              'description': 'Faktur Lunas #$invoiceNumber',
              'reference_type': 'INVOICE',
              'reference_id': invoiceNumber,
              'created_at': DateTime.now().toIso8601String(),
            });

            userPointsGained += pointsEarned;
            totalPointsAdded += pointsEarned;
            print('  -> [BERHASIL FAKTUR] $invoiceNumber +$pointsEarned Poin');
          }
          print('  => Selesai mengecek semua faktur Penjualan untuk $userName.');

          // =============================================
          // 2. PROSES RETUR PENJUALAN (dari cache lokal)
          // =============================================
          if (userReturns.isEmpty) {
            print('  -> (Tidak ada retur untuk $userName di Accurate)');
          }

          for (final ret in userReturns) {
            final String returnNumber = ret['number']?.toString() ?? '';
            final int returnId = (ret['id'] as num?)?.toInt() ?? 0;
            if (returnNumber.isEmpty || returnId <= 0) continue;

            if (claimedReturns.contains(returnNumber)) {
              print('  -> [SUDAH KLAIM] Retur $returnNumber sudah pernah dipotong. Melewati...');
              continue;
            }
            totalReturnsChecked++;

            onProgress?.call('Cek detail retur $returnNumber...');
            Map<String, dynamic> returDetail;
            try {
              final resDetailRetur = await fetchReturnDetail(host, session, token, returnId);
              returDetail = (resDetailRetur['d'] is Map)
                  ? Map<String, dynamic>.from(resDetailRetur['d']) : {};
            } catch (e) {
              print('  -> [ERROR] Gagal ambil detail retur $returnNumber');
              continue;
            }

            // Cross-check MUTLAK customerNo di level detail
            final String exactReturnCustNo = normalizeCustomerNo(
              returDetail['customer']?['customerNo']?.toString() ?? '',
            );
            if (exactReturnCustNo.isNotEmpty && exactReturnCustNo != accurateCustomerNo) {
              print('  -> [SKIP RETUR MUTLAK] Retur $returnNumber aslinya milik $exactReturnCustNo, '
                  'bukan $userName ($accurateCustomerNo)! DITOLAK!');
              continue;
            }

            final double nominalRetur =
                (returDetail['grandTotal'] as num?)?.toDouble() ??
                (returDetail['totalAmount'] as num?)?.toDouble() ??
                (ret['grandTotal'] as num?)?.toDouble() ??
                (ret['totalAmount'] as num?)?.toDouble() ?? 0;
            if (nominalRetur <= 0) {
              print('  -> [SKIP RETUR] Retur $returnNumber nominal 0.');
              continue;
            }

            final int pointsDeducted = (nominalRetur / conversionRate).floor();
            if (pointsDeducted <= 0) {
              print('  -> [SKIP RETUR] Retur $returnNumber hasil potong 0.');
              continue;
            }

            await admin.from('point_history').insert({
              'user_id': userId,
              'amount': -pointsDeducted,
              'description': 'Retur Penjualan #$returnNumber',
              'reference_type': 'RETURN',
              'reference_id': returnNumber,
              'created_at': DateTime.now().toIso8601String(),
            });

            userPointsGained -= pointsDeducted;
            totalPointsDeducted += pointsDeducted;
            print('  -> [BERHASIL RETUR] Retur $returnNumber -$pointsDeducted Poin');
          }
          print('  => Selesai mengecek semua retur untuk $userName.');

          // =============================================
          // 3. UPDATE PROFIL POIN
          // =============================================
          if (userPointsGained != 0) {
            final allHistory = await admin.from('point_history').select('amount').eq('user_id', userId);
            int finalPoints = 0;
            for (var item in allHistory) {
              finalPoints += (item['amount'] as num?)?.toInt() ?? 0;
            }
            if (finalPoints < 0) finalPoints = 0;
            await admin.from('profiles').update({
              'points': finalPoints,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);
            totalUsersAffected++;
            print('  => [UPDATE] Poin profil $userName → $finalPoints Poin');
          }
        } catch (e) {
          if (e.toString() == 'SESSION_EXPIRED') rethrow;
          errors.add('$userName: $e');
        }
      }

      print('\n=== SYNC SELESAI ===\n');
      return SyncResult(
        message: 'Sync Selesai!\nFaktur baru dicek: $totalInvoicesChecked (+ $totalPointsAdded Poin).\n'
            'Retur baru dicek: $totalReturnsChecked (- $totalPointsDeducted Poin).\n'
            'Total $totalUsersAffected user diperbarui.',
        totalInvoicesChecked: totalInvoicesChecked,
        totalPointsAdded: totalPointsAdded,
        totalUsersAffected: totalUsersAffected,
        totalSkipped: totalSkipped,
        errors: errors,
      );
    } catch (e) { rethrow; }
  }

  static String _parseAccurateDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3)
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])).toIso8601String();
    } catch (_) {}
    return DateTime.now().toIso8601String();
  }

  static Future<void> disconnect(SupabaseClient admin) async {
    final keys = ['accurate_access_token', 'accurate_token_expiry', 'accurate_db_session', 'accurate_db_host', 'accurate_db_id'];
    for (final key in keys) {
      await admin.from('app_config').upsert({'key': key, 'value': ''}, onConflict: 'key');
    }
  }

  // =========================================================================
  // METHOD INSTANCE (tidak berubah)
  // =========================================================================

  Future<List<Map<String, dynamic>>> getAccurateCustomers({
    String keyword = '',
    String statusFilter = 'ALL',
  }) async {
    try {
      final config = await _supabase.from('app_config').select().inFilter(
        'key', ['accurate_db_host', 'accurate_access_token', 'accurate_db_session'],
      );
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }
      if (host == null || token == null || session == null ||
          host.isEmpty || session.isEmpty || token.isEmpty) {
        throw Exception('Kredensial Accurate tidak ditemukan.');
      }
      String urlStr =
          '$host/accurate/api/customer/list.do?fields=id,customerNo,name,email,mobilePhone,suspended&sp.pageSize=100';
      if (keyword.isNotEmpty) urlStr += '&keywords=${Uri.encodeComponent(keyword)}';
      if (statusFilter == 'ACTIVE') urlStr += '&filter.suspended.op=EQUAL&filter.suspended.val[0]=false';
      else if (statusFilter == 'INACTIVE') urlStr += '&filter.suspended.op=EQUAL&filter.suspended.val[0]=true';

      final response = await _proxy(
        accurateUrl: urlStr,
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
      );
      if (response['s'] == true && response['d'] != null) {
        return List<Map<String, dynamic>>.from(response['d']);
      } else {
        throw Exception('API Error: ${response['d']}');
      }
    } catch (e) { rethrow; }
  }

  Future<bool> updateCustomerToAccurate({
    required String customerNo,
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    try {
      final config = await _supabase.from('app_config').select().inFilter(
        'key', ['accurate_db_host', 'accurate_access_token', 'accurate_db_session'],
      );
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }
      if (host == null || token == null || session == null) return false;

      final int? internalId = await _getInternalIdByCustomerNo(
        normalizeCustomerNo(customerNo), host: host, token: token, session: session,
      );
      if (internalId == null || internalId <= 0) {
        debugPrint('updateCustomerToAccurate: internal ID tidak ditemukan untuk $customerNo');
        return false;
      }

      final Map<String, dynamic> bodyPayload = {'id': internalId, 'name': name};
      if (email != null && email.isNotEmpty) bodyPayload['email'] = email;
      if (phone != null && phone.isNotEmpty) bodyPayload['mobilePhone'] = phone;
      if (address != null && address.isNotEmpty) bodyPayload['billStreet'] = address;

      final response = await _proxy(
        accurateUrl: '$host/accurate/api/customer/save.do',
        method: 'POST',
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
        body: bodyPayload,
      );
      return response['s'] == true;
    } catch (e) {
      debugPrint('Error Update Accurate: $e');
      return false;
    }
  }

  Future<int?> _getInternalIdByCustomerNo(
    String customerNo, {String? host, String? token, String? session}
  ) async {
    try {
      if (host == null || token == null || session == null) return null;
      final urlStr =
          '$host/accurate/api/customer/list.do'
          '?fields=id,customerNo,name'
          '&keywords=${Uri.encodeComponent(customerNo)}'
          '&sp.pageSize=20';
      final response = await _proxy(
        accurateUrl: urlStr,
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
      );
      if (response['s'] == true && response['d'] != null) {
        final List data = response['d'];
        for (final item in data) {
          final no = normalizeCustomerNo(item['customerNo']?.toString() ?? '');
          if (no == customerNo) return (item['id'] as num?)?.toInt();
        }
      }
      return null;
    } catch (e) {
      debugPrint('_getInternalIdByCustomerNo error: $e');
      return null;
    }
  }

  Future<void> syncLocalToAccurate({
    required List<Map<String, dynamic>> profiles,
    Function(String)? onProgress,
  }) async {
    int successCount = 0;
    int failCount = 0;
    for (var profile in profiles) {
      final String? custNo = profile['accurate_customer_id'];
      if (custNo == null || custNo.isEmpty) continue;
      onProgress?.call('Mensinkronkan ${profile['full_name']}...');
      final bool success = await updateCustomerToAccurate(
        customerNo: custNo, name: profile['full_name'] ?? '',
        phone: profile['phone'], address: profile['address'], email: profile['email'],
      );
      if (success) successCount++; else failCount++;
    }
    onProgress?.call('Sync Selesai! Berhasil: $successCount, Gagal: $failCount');
  }

  Future<void> autoSyncAccurateToSupabase() async {
    try {
      print('\n🔍 === MULAI PROSES AUTO SYNC PENYISIRAN MASAL ===');
      final supabase = AdminSupabase.client;
      final profiles = await supabase.from('profiles').select('accurate_customer_id').not('accurate_customer_id', 'is', null);
      final Set<String> registeredNos = profiles
          .map((p) => normalizeCustomerNo(p['accurate_customer_id'].toString()))
          .toSet();

      int totalDiundang = 0;
      int currentPage = 1;
      bool hasMore = true;

      while (hasMore) {
        print('📄 Menyisir Accurate Halaman: $currentPage...');
        final customers = await getAccurateCustomersPaged(page: currentPage);
        if (customers.isEmpty) { hasMore = false; break; }

        for (var customer in customers) {
          final String customerNo = normalizeCustomerNo(customer['customerNo']?.toString() ?? '');
          final String email = customer['email']?.toString().trim() ?? '';
          final String name = customer['name']?.toString() ?? 'Pelanggan Accurate';
          final String phone = customer['mobilePhone']?.toString() ?? '';
          if (customerNo.isEmpty) continue;

          if (!registeredNos.contains(customerNo) && email.isNotEmpty) {
            print('   ⏳ Mengundang: $name ($email) — No. Pelanggan: $customerNo');
            try {
              final res = await supabase.auth.admin.inviteUserByEmail(email);
              if (res.user?.id != null) {
                await supabase.from('profiles').upsert({
                  'id': res.user!.id, 'email': email, 'full_name': name,
                  'phone': phone, 'accurate_customer_id': customerNo,
                  'approval_status': 'APPROVED', 'is_profile_completed': false, 'has_password': false,
                });
                registeredNos.add(customerNo);
                totalDiundang++;
                print('   ✅ Sukses diundang.');
              }
            } catch (e) { print('   ❌ Gagal mengundang $email: $e'); }
          }
        }
        if (customers.length < 100) hasMore = false;
        else currentPage++;
        if (currentPage > 50) hasMore = false;
      }
      print('\n🏁 === SYNC SELESAI. Total email baru diundang: $totalDiundang ===\n');
    } catch (e) { print('\n❌ ERROR FATAL: $e\n'); rethrow; }
  }

  Future<List<Map<String, dynamic>>> getAccurateCustomersPaged({required int page}) async {
    final config = await _supabase.from('app_config').select().inFilter(
      'key', ['accurate_db_host', 'accurate_access_token', 'accurate_db_session'],
    );
    String? host, token, session;
    for (var row in config) {
      if (row['key'] == 'accurate_db_host') host = row['value'];
      if (row['key'] == 'accurate_access_token') token = row['value'];
      if (row['key'] == 'accurate_db_session') session = row['value'];
    }
    String urlStr = '$host/accurate/api/customer/list.do?fields=id,customerNo,name,email,mobilePhone&sp.pageSize=100&sp.page=$page';
    final response = await _proxy(
      accurateUrl: urlStr,
      headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session!},
    );
    if (response['s'] == true && response['d'] != null) {
      return List<Map<String, dynamic>>.from(response['d']);
    }
    return [];
  }

  Future<Map<String, dynamic>?> getCustomerByCustomerNo(String customerNo) async {
    try {
      final config = await _supabase.from('app_config').select().inFilter(
        'key', ['accurate_db_host', 'accurate_access_token', 'accurate_db_session'],
      );
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }
      if (host == null || token == null || session == null) return null;
      final String normalized = normalizeCustomerNo(customerNo);
      final String urlStr =
          '$host/accurate/api/customer/list.do'
          '?fields=id,customerNo,name,email,mobilePhone'
          '&keywords=${Uri.encodeComponent(normalized)}'
          '&sp.pageSize=20';
      final response = await _proxy(
        accurateUrl: urlStr,
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
      );
      if (response['s'] == true && response['d'] != null) {
        final List data = response['d'];
        for (final item in data) {
          final no = normalizeCustomerNo(item['customerNo']?.toString() ?? '');
          if (no == normalized) return Map<String, dynamic>.from(item);
        }
      }
      return null;
    } catch (e) { debugPrint('Error getCustomerByCustomerNo: $e'); return null; }
  }

  @Deprecated('Gunakan getCustomerByCustomerNo(customerNo)')
  Future<Map<String, dynamic>?> getCustomerById(String customerNo) =>
      getCustomerByCustomerNo(customerNo);
}

class SyncResult {
  final String message;
  final int totalInvoicesChecked;
  final int totalPointsAdded;
  final int totalUsersAffected;
  final int totalSkipped;
  final List<String> errors;
  SyncResult({
    required this.message,
    required this.totalInvoicesChecked,
    required this.totalPointsAdded,
    required this.totalUsersAffected,
    required this.totalSkipped,
    this.errors = const [],
  });
}
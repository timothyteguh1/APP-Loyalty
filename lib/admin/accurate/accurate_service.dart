import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upsol_loyalty/admin/admin_supabase.dart';

class AccurateService {
  final _supabase = Supabase.instance.client;

  static const String _clientId = '79aaa170-8897-4cf7-b0d1-b8ec78dd07d1';
  // Ganti 'const' menjadi 'getter' agar bisa dinamis
  static String get _redirectUri {
    // Uri.base.origin akan otomatis menjadi 'http://localhost:3000' saat di laptop
    // dan menjadi 'https://loyalty.programdeus.my.id' saat sudah online!
    return '${Uri.base.origin}/oauth_callback.html';
  }
  static const String _oauthBaseUrl = 'https://account.accurate.id';
  static const String _scope =
      'sales_invoice_view customer_view item_view sales_invoice_save sales_return_view';
  static const String _knownDbId = '2570323';

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

  static String buildAuthUrl() {
    final params = {
      'client_id': _clientId,
      'response_type': 'token',
      'redirect_uri': _redirectUri,
      'scope': _scope,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_oauthBaseUrl/oauth/authorize?$query';
  }

  static Future<void> saveToken(
    SupabaseClient admin,
    String accessToken,
  ) async {
    final expiry = DateTime.now()
        .add(const Duration(days: 14))
        .toIso8601String();
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
    final rows = await admin
        .from('app_config')
        .select('key, value')
        .inFilter('key', [
          'accurate_access_token',
          'accurate_token_expiry',
          'accurate_db_session',
          'accurate_db_host',
          'accurate_db_id',
        ]);
    final config = <String, String>{};
    for (final row in rows) {
      config[row['key']] = row['value'] ?? '';
    }
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

  static Future<List<Map<String, dynamic>>> fetchDatabaseList(
    String accessToken,
  ) async {
    final data = await _proxy(
      accurateUrl: '$_oauthBaseUrl/api/db-list.do',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (data['s'] != true)
      throw data['d']?.toString() ?? 'Gagal ambil daftar database';
    final List<dynamic> dbs = data['d'] ?? [];
    return dbs.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, String>> openDatabase(
    String accessToken,
    String dbId,
  ) async {
    final dbList = await fetchDatabaseList(accessToken);
    Map<String, dynamic>? targetDb;
    for (final db in dbList) {
      final uid = db['uid']?.toString() ?? '';
      final id = db['id']?.toString() ?? '';
      if (uid == dbId || id == dbId) {
        targetDb = db;
        break;
      }
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

  static Future<void> saveSession(
    SupabaseClient admin,
    String dbId,
    String host,
    String session,
  ) async {
    final configs = [
      {'key': 'accurate_db_id', 'value': dbId},
      {'key': 'accurate_db_host', 'value': host},
      {'key': 'accurate_db_session', 'value': session},
    ];
    for (final c in configs) {
      await admin.from('app_config').upsert(c, onConflict: 'key');
    }
  }

  // ============================================================
  // FAKTUR PENJUALAN
  // ============================================================
  static Future<Map<String, dynamic>> fetchSalesInvoices(
    String host,
    String session,
    String token, {
    int? customerId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'sp.page': '$page',
      'sp.pageSize': '$pageSize',
      'fields':
          'id,number,transDate,dueDate,grandTotal,totalAmount,statusName,status,customer.id,customer.name',
      'filter.transDate.val[0]': '01/01/2000',
      'filter.transDate.val[1]': '31/12/2099',
      'filter.transDate.op': 'BETWEEN',
    };

    if (customerId != null) {
      params['filter.customer.id.val[0]'] = '$customerId';
      params['filter.customer.id.op'] = 'EQUAL';
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '$host/accurate/api/sales-invoice/list.do?$queryString';

    final data = await _proxy(
      accurateUrl: url,
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );

    return data;
  }

  static Future<Map<String, dynamic>> fetchInvoiceDetail(
    String host,
    String session,
    String token,
    int invoiceId,
  ) async {
    final url = '$host/accurate/api/sales-invoice/detail.do?id=$invoiceId';

    final data = await _proxy(
      accurateUrl: url,
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );

    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true)
        throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil detail faktur';
    }
    return data;
  }

  // ============================================================
  // RETUR PENJUALAN (SALES RETURN)
  // ============================================================
  static Future<Map<String, dynamic>> fetchSalesReturns(
    String host,
    String session,
    String token, {
    int? customerId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'sp.page': '$page',
      'sp.pageSize': '$pageSize',
      'fields':
          'id,number,transDate,totalAmount,grandTotal,statusName,status,customer.id,customer.name',
      'filter.transDate.val[0]': '01/01/2000',
      'filter.transDate.val[1]': '31/12/2099',
      'filter.transDate.op': 'BETWEEN',
    };

    if (customerId != null) {
      params['filter.customer.id.val[0]'] = '$customerId';
      params['filter.customer.id.op'] = 'EQUAL';
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final data = await _proxy(
      accurateUrl: '$host/accurate/api/sales-return/list.do?$queryString',
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );

    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true)
        throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil retur penjualan';
    }
    return data;
  }

  // FUNGSI BARU: AMBIL DETAIL RETUR
  static Future<Map<String, dynamic>> fetchReturnDetail(
    String host,
    String session,
    String token,
    int returnId,
  ) async {
    final url = '$host/accurate/api/sales-return/detail.do?id=$returnId';

    final data = await _proxy(
      accurateUrl: url,
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );

    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true)
        throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil detail retur';
    }
    return data;
  }

  // UPDATE: Fungsi ini sekarang mendukung AJAX (Pencarian Server-Side dan Filter Status)
  Future<List<Map<String, dynamic>>> getAccurateCustomers({
    String keyword = '',
    String statusFilter = 'ALL',
  }) async {
    try {
      final config = await _supabase.from('app_config').select().inFilter(
        'key',
        ['accurate_db_host', 'accurate_access_token', 'accurate_db_session'],
      );
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }
      if (host == null ||
          token == null ||
          session == null ||
          host.isEmpty ||
          session.isEmpty ||
          token.isEmpty) {
        throw Exception('Kredensial Accurate tidak ditemukan.');
      }

      // Tambahkan pageSize 100 agar cukup banyak yang ditarik sekali waktu, dan field 'suspended'
      String urlStr =
          '$host/accurate/api/customer/list.do?fields=id,customerNo,name,email,mobilePhone,suspended&sp.pageSize=100';

      // Terapkan Keyword Search (Accurate pakai parameter 'keywords' dengan huruf 'S')
      if (keyword.isNotEmpty) {
        urlStr += '&keywords=${Uri.encodeComponent(keyword)}';
      }

      // Terapkan Filter Status (suspended = true artinya INACTIVE)
      if (statusFilter == 'ACTIVE') {
        urlStr += '&filter.suspended.op=EQUAL&filter.suspended.val[0]=false';
      } else if (statusFilter == 'INACTIVE') {
        urlStr += '&filter.suspended.op=EQUAL&filter.suspended.val[0]=true';
      }

      final url = Uri.parse(urlStr);
      final response = await _proxy(
        accurateUrl: url.toString(),
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
      );

      if (response['s'] == true && response['d'] != null) {
        return List<Map<String, dynamic>>.from(response['d']);
      } else {
        throw Exception('API Error: ${response['d']}');
      }
    } catch (e) {
      rethrow;
    }
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
    final double primeReceipt =
        (detail['primeReceipt'] as num?)?.toDouble() ?? 0;
    if (primeOwing == 0 && primeReceipt > 0) return true;

    final receiptHistory = detail['receiptHistory'];
    if (receiptHistory is List && receiptHistory.isNotEmpty) {
      final double totalAmount =
          (detail['totalAmount'] as num?)?.toDouble() ?? 0;
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
      detail['lastPaymentDate'],
      detail['closeDate'],
      detail['closedDate'],
      detail['paymentDate'],
    ];

    for (final raw in candidates) {
      if (raw == null) continue;
      final str = raw.toString().trim();
      if (str.isEmpty) continue;
      try {
        if (str.contains('/')) return DateTime.parse(_parseAccurateDate(str));
        return DateTime.parse(str);
      } catch (_) {
        continue;
      }
    }

    final receiptHistory = detail['receiptHistory'];
    if (receiptHistory is List && receiptHistory.isNotEmpty) {
      final lastReceipt = receiptHistory.last;
      final historyDate = lastReceipt['historyDate']?.toString().trim() ?? '';
      if (historyDate.isNotEmpty) {
        try {
          if (historyDate.contains('/'))
            return DateTime.parse(_parseAccurateDate(historyDate));
          return DateTime.parse(historyDate);
        } catch (_) {}
      }
    }
    return null;
  }

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
      onProgress?.call('Mencari data user...');
      print('\n=== MULAI SYNC ===\n');

      final tokenConfig = await admin
          .from('app_config')
          .select('value')
          .eq('key', 'accurate_access_token')
          .maybeSingle();
      final String token = tokenConfig?['value']?.toString() ?? '';

      if (token.isEmpty) throw 'Token Authorization tidak ditemukan di sistem.';

      final users = await admin
          .from('profiles')
          .select(
            'id, full_name, points, accurate_customer_id, point_conversion_rate',
          )
          .eq('approval_status', 'APPROVED')
          .not('accurate_customer_id', 'is', null)
          .neq('accurate_customer_id', '');

      print(
        '=> Ditemukan ${users.length} toko/user yang valid di database untuk disync.',
      );

      if (users.isEmpty) {
        return SyncResult(
          message: 'Tidak ada user valid.',
          totalInvoicesChecked: 0,
          totalPointsAdded: 0,
          totalUsersAffected: 0,
          totalSkipped: 0,
        );
      }

      final globalConfig = await admin
          .from('app_config')
          .select('value')
          .eq('key', 'default_conversion_rate')
          .maybeSingle();
      final int globalRate =
          int.tryParse(globalConfig?['value'] ?? '10000') ?? 10000;

      for (final user in users) {
        final String userId = user['id'];
        final String userName = user['full_name'] ?? 'Unknown';
        final String accurateCustomerId = user['accurate_customer_id']
            .toString()
            .trim();
        final int conversionRate =
            (user['point_conversion_rate'] as num?)?.toInt() ?? globalRate;
        final int currentPoints = (user['points'] as num?)?.toInt() ?? 0;

        print('\n=== Memeriksa Toko: $userName (ID: $accurateCustomerId) ===');
        onProgress?.call('Sync Toko: $userName...');

        try {
          int userPointsGained = 0;

          final existingHistory = await admin
              .from('point_history')
              .select('reference_id, reference_type')
              .eq('user_id', userId);

          final Set<String> claimedInvoices = {};
          final Set<String> claimedReturns = {};

          for (var history in existingHistory) {
            final type = history['reference_type'];
            final refId = history['reference_id']?.toString() ?? '';
            if (type == 'INVOICE') claimedInvoices.add(refId);
            if (type == 'RETURN') claimedReturns.add(refId);
          }

          // =============================================
          // 1. PROSES FAKTUR PENJUALAN
          // =============================================
          int page = 1;
          bool hasMore = true;
          while (hasMore) {
            final result = await fetchSalesInvoices(
              host,
              session,
              token,
              customerId: int.tryParse(accurateCustomerId),
              page: page,
              pageSize: 50,
            );
            final List<dynamic> invoices = result['d'] ?? [];
            final int totalCount =
                (result['totalCount'] as num?)?.toInt() ?? invoices.length;

            if (invoices.isEmpty) {
              print(
                '  -> (Tidak ada data faktur Penjualan di Accurate untuk $userName)',
              );
            }

            for (final invoice in invoices) {
              final String invoiceNumber = invoice['number']?.toString() ?? '';
              final int invoiceId = (invoice['id'] as num?)?.toInt() ?? 0;

              if (invoiceNumber.isEmpty) continue;

              if (claimedInvoices.contains(invoiceNumber)) {
                print(
                  '  -> [SUDAH KLAIM] Faktur $invoiceNumber sudah pernah ditukar poin. Melewati...',
                );
                continue;
              }

              totalInvoicesChecked++;

              if (invoiceId <= 0) {
                totalSkipped++;
                continue;
              }

              final String listCustId =
                  invoice['customer']?['id']?.toString() ??
                  invoice['customer.id']?.toString() ??
                  '';
              if (listCustId.isNotEmpty && listCustId != accurateCustomerId) {
                totalSkipped++;
                continue;
              }

              onProgress?.call('Cek detail $invoiceNumber...');

              Map<String, dynamic> detailData;
              try {
                final detailResponse = await fetchInvoiceDetail(
                  host,
                  session,
                  token,
                  invoiceId,
                );
                detailData = (detailResponse['d'] is Map)
                    ? Map<String, dynamic>.from(detailResponse['d'])
                    : {};
              } catch (e) {
                errors.add('Faktur $invoiceNumber: Gagal ambil detail');
                totalSkipped++;
                continue;
              }

              // [GEMBOK 2 MUTLAK INVOICE]
              final String detailCustId =
                  detailData['customer']?['id']?.toString() ?? '';
              if (detailCustId != accurateCustomerId) {
                print(
                  '  -> [SKIP MUTLAK] Faktur $invoiceNumber aslinya milik ID $detailCustId, bukan milik $userName! DITOLAK!',
                );
                totalSkipped++;
                continue;
              }

              if (!_isInvoiceFullyPaid(detailData)) {
                print(
                  '  -> [SKIP] Faktur $invoiceNumber: BELUM LUNAS. Lompat ke faktur berikutnya...',
                );
                totalSkipped++;
                continue;
              }

              final String dueDateStr =
                  detailData['dueDate']?.toString() ??
                  invoice['dueDate']?.toString() ??
                  '';
              if (dueDateStr.isNotEmpty) {
                final DateTime dueDate = DateTime.parse(
                  _parseAccurateDate(dueDateStr),
                );
                DateTime? paymentDate = _getPaymentDate(detailData);

                if (paymentDate != null) {
                  if (paymentDate.isAfter(dueDate)) {
                    print(
                      '  -> [SKIP] Faktur $invoiceNumber: TELAT BAYAR. Lompat ke faktur berikutnya...',
                    );
                    totalSkipped++;
                    continue;
                  }
                } else {
                  if (DateTime.now().isAfter(dueDate)) {
                    print(
                      '  -> [SKIP] Faktur $invoiceNumber: Melewati jatuh tempo. Lompat ke faktur berikutnya...',
                    );
                    totalSkipped++;
                    continue;
                  }
                }
              }

              final double nominalFaktur =
                  (detailData['grandTotal'] as num?)?.toDouble() ??
                  (detailData['totalAmount'] as num?)?.toDouble() ??
                  (invoice['grandTotal'] as num?)?.toDouble() ??
                  (invoice['totalAmount'] as num?)?.toDouble() ??
                  0;

              if (nominalFaktur <= 0) {
                totalSkipped++;
                continue;
              }

              final int pointsEarned = (nominalFaktur / conversionRate).floor();
              if (pointsEarned <= 0) {
                totalSkipped++;
                continue;
              }

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
              print(
                '  -> [BERHASIL FAKTUR] $invoiceNumber dapet +$pointsEarned Poin',
              );
            }

            hasMore = (page * 50) < totalCount;
            page++;
            if (page > 10) hasMore = false;
          }

          print(
            '  => Selesai mengecek semua faktur Penjualan untuk $userName.',
          );

          // =============================================
          // 2. PROSES RETUR PENJUALAN
          // =============================================
          int pageRetur = 1;
          bool hasMoreRetur = true;
          while (hasMoreRetur) {
            final resultRetur = await fetchSalesReturns(
              host,
              session,
              token,
              customerId: int.tryParse(accurateCustomerId),
              page: pageRetur,
              pageSize: 50,
            );
            final List<dynamic> returns = resultRetur['d'] ?? [];
            final int totalCountRetur =
                (resultRetur['totalCount'] as num?)?.toInt() ?? returns.length;

            if (returns.isEmpty) {
              print(
                '  -> (Tidak ada data retur Penjualan di Accurate untuk $userName)',
              );
            }

            for (final ret in returns) {
              final String returnNumber = ret['number']?.toString() ?? '';
              final int returnId = (ret['id'] as num?)?.toInt() ?? 0;

              if (returnNumber.isEmpty || returnId <= 0) continue;

              if (claimedReturns.contains(returnNumber)) {
                print(
                  '  -> [SUDAH KLAIM] Retur $returnNumber sudah pernah dipotong poinnya. Melewati...',
                );
                continue;
              }

              totalReturnsChecked++;

              // [GEMBOK 1 LIST RETUR]
              final String listReturnCustId =
                  ret['customer']?['id']?.toString() ??
                  ret['customer.id']?.toString() ??
                  '';
              if (listReturnCustId.isNotEmpty &&
                  listReturnCustId != accurateCustomerId) {
                continue; // Skip diam-diam biar gak menuhin log kalo ada dari list
              }

              onProgress?.call('Cek detail retur $returnNumber...');

              // --- AMBIL DETAIL RETUR ---
              Map<String, dynamic> returDetail;
              try {
                final resDetailRetur = await fetchReturnDetail(
                  host,
                  session,
                  token,
                  returnId,
                );
                returDetail = (resDetailRetur['d'] is Map)
                    ? Map<String, dynamic>.from(resDetailRetur['d'])
                    : {};
              } catch (e) {
                print('  -> [ERROR] Gagal ambil detail retur $returnNumber');
                continue;
              }

              // [GEMBOK 2 MUTLAK RETUR] Validasi ketat ID Customer dari Detail
              final String exactReturnCustId =
                  returDetail['customer']?['id']?.toString() ?? '';
              if (exactReturnCustId != accurateCustomerId) {
                print(
                  '  -> [SKIP RETUR MUTLAK] Retur $returnNumber aslinya milik ID $exactReturnCustId, bukan milik $userName! DITOLAK!',
                );
                continue;
              }

              final double nominalRetur =
                  (returDetail['grandTotal'] as num?)?.toDouble() ??
                  (returDetail['totalAmount'] as num?)?.toDouble() ??
                  (ret['grandTotal'] as num?)?.toDouble() ??
                  (ret['totalAmount'] as num?)?.toDouble() ??
                  0;

              if (nominalRetur <= 0) {
                print(
                  '  -> [SKIP RETUR] Retur $returnNumber nominalnya 0. Melewati...',
                );
                continue;
              }

              final int pointsDeducted = (nominalRetur / conversionRate)
                  .floor();
              if (pointsDeducted <= 0) {
                print(
                  '  -> [SKIP RETUR] Retur $returnNumber hasil potong poin 0. Melewati...',
                );
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
              print(
                '  -> [BERHASIL RETUR] Retur $returnNumber diproses! Poin dipotong -$pointsDeducted Poin',
              );
            }

            hasMoreRetur = (pageRetur * 50) < totalCountRetur;
            pageRetur++;
            if (pageRetur > 10) hasMoreRetur = false;
          }

          print('  => Selesai mengecek semua retur untuk $userName.');

          // =============================================
          // 3. UPDATE PROFIL POIN (KALKULASI ULANG AKURAT)
          // =============================================
          if (userPointsGained != 0) {
            // Kita hitung total poin terbaru MURNI dari riwayat di Supabase
            final allHistory = await admin
                .from('point_history')
                .select('amount')
                .eq('user_id', userId);

            int finalPoints = 0;
            for (var item in allHistory) {
              finalPoints += (item['amount'] as num?)?.toInt() ?? 0;
            }

            // Poin tidak boleh minus
            if (finalPoints < 0) finalPoints = 0;

            await admin
                .from('profiles')
                .update({
                  'points': finalPoints,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', userId);
            totalUsersAffected++;
            print(
              '  => [UPDATE] Poin profil $userName dikalkulasi ulang menjadi: $finalPoints Poin',
            );
          }
        } catch (e) {
          if (e.toString() == 'SESSION_EXPIRED') rethrow;
          errors.add('$userName: $e');
        }
      }

      print('\n=== SYNC SELESAI ===\n');
      return SyncResult(
        message:
            'Sync Selesai!\nFaktur baru dicek: $totalInvoicesChecked (+ $totalPointsAdded Poin).\nRetur baru dicek: $totalReturnsChecked (- $totalPointsDeducted Poin).\nTotal $totalUsersAffected user diperbarui.',
        totalInvoicesChecked: totalInvoicesChecked,
        totalPointsAdded: totalPointsAdded,
        totalUsersAffected: totalUsersAffected,
        totalSkipped: totalSkipped,
        errors: errors,
      );
    } catch (e) {
      rethrow;
    }
  }

  static String _parseAccurateDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3)
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        ).toIso8601String();
    } catch (_) {}
    return DateTime.now().toIso8601String();
  }

  static Future<void> disconnect(SupabaseClient admin) async {
    final keys = [
      'accurate_access_token',
      'accurate_token_expiry',
      'accurate_db_session',
      'accurate_db_host',
      'accurate_db_id',
    ];
    for (final key in keys) {
      await admin.from('app_config').upsert({
        'key': key,
        'value': '',
      }, onConflict: 'key');
    }
  }

// =========================================================================
  // FITUR 1: TEMBAK BALIK KE ACCURATE (BI-DIRECTIONAL SYNC)
  // Dipanggil saat user klik "Simpan" di halaman Edit Profile
  // =========================================================================
  Future<bool> updateCustomerToAccurate({
    required String customerId,
    required String name,
    String? email,
    String? phone,
  }) async {
    try {
      // 1. Ambil Kredensial Accurate dari tabel app_config (Sama seperti getAccurateCustomers)
      final config = await _supabase.from('app_config').select().inFilter(
        'key',
        ['accurate_db_host', 'accurate_access_token', 'accurate_db_session'],
      );
      
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }

      // Pastikan kredensial lengkap
      if (host == null || token == null || session == null || 
          host.isEmpty || session.isEmpty || token.isEmpty) {
        print('Kredensial Accurate tidak lengkap, batal update.');
        return false;
      }

      // 2. Siapkan Data yang mau di-update
      final Map<String, dynamic> bodyPayload = {
        'id': customerId,
        'name': name,
      };

      if (email != null && email.isNotEmpty) bodyPayload['email'] = email;
      if (phone != null && phone.isNotEmpty) bodyPayload['mobilePhone'] = phone;

      // 3. Tembak API Accurate menggunakan fungsi _proxy agar aman dari CORS Web!
      final response = await _proxy(
        accurateUrl: '$host/accurate/api/customer/save.do',
        method: 'POST',
        headers: {
          'Authorization': 'Bearer $token',
          'X-Session-ID': session,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: bodyPayload,
      );

      // 4. Cek hasil kembalian dari Accurate
      if (response['s'] == true) {
        print('Berhasil tembak balik data ke Accurate!');
        return true; 
      }
      
      print('Gagal dari server Accurate: ${response['d']}');
      return false;
    } catch (e) {
      print('Error Tembak Balik Accurate: $e');
      return false;
    }
  }

Future<void> autoSyncAccurateToSupabase() async {
    try {
      print('\n🔍 === MULAI PROSES AUTO SYNC PENYISIRAN MASAL ===');
      
      final supabase = AdminSupabase.client; 
      final profiles = await supabase
          .from('profiles')
          .select('accurate_customer_id')
          .not('accurate_customer_id', 'is', null);

      final Set<String> registeredIds = profiles
          .map((p) => p['accurate_customer_id'].toString().trim())
          .toSet();
      
      int totalDiundang = 0;
      int currentPage = 1;
      bool hasMore = true;

      // KITA LOOPING SAMPAI SEMUA HALAMAN HABIS
      while (hasMore) {
        print('📄 Menyisir Accurate Halaman: $currentPage...');
        
        // Ambil data per halaman (Kita pakai fungsi bantuan baru di bawah)
        final customers = await getAccurateCustomersPaged(page: currentPage);
        
        if (customers.isEmpty) {
          hasMore = false;
          break;
        }

        for (var customer in customers) {
          final systemId = customer['id']?.toString().trim() ?? '';
          final email = customer['email']?.toString().trim() ?? '';
          final name = customer['name']?.toString() ?? 'Pelanggan Accurate';
          final phone = customer['mobilePhone']?.toString() ?? '';

          if (!registeredIds.contains(systemId) && email.isNotEmpty) {
            print('   ⏳ Mengundang: $name ($email)');
            try {
              final res = await supabase.auth.admin.inviteUserByEmail(email);
              if (res.user?.id != null) {
                await supabase.from('profiles').upsert({
                  'id': res.user!.id, 
                  'email': email,
                  'full_name': name,
                  'phone': phone,
                  'accurate_customer_id': systemId,
                  'approval_status': 'PENDING', 
                  'is_profile_completed': false, 
                });
                totalDiundang++;
                print('   ✅ Sukses diundang.');
              }
            } catch (e) {
              print('   ❌ Gagal mengundang $email: $e');
            }
          }
        }

        // Jika data yang ditarik kurang dari 100, berarti ini halaman terakhir
        if (customers.length < 100) {
          hasMore = false;
        } else {
          currentPage++;
        }
        
        // Safety break agar tidak looping selamanya jika ada error
        if (currentPage > 50) hasMore = false; 
      }
      
      print('\n🏁 === SYNC SELESAI. Total email baru diundang: $totalDiundang ===\n');
    } catch (e) {
      print('\n❌ ERROR FATAL: $e\n');
      rethrow;
    }
  }

  // FUNGSI BANTUAN UNTUK AMBIL DATA PER HALAMAN
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

    // Gunakan parameter sp.page untuk berpindah halaman
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

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AccurateService {
  final _supabase = Supabase.instance.client;

  static const String _clientId = '79aaa170-8897-4cf7-b0d1-b8ec78dd07d1';
  static const String _redirectUri = 'http://localhost:3000/oauth_callback.html';
  static const String _oauthBaseUrl = 'https://account.accurate.id';
  static const String _scope = 'sales_invoice_view customer_view item_view sales_invoice_save sales_return_view'; 
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
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$_oauthBaseUrl/oauth/authorize?$query';
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
      'accurate_access_token', 'accurate_token_expiry', 'accurate_db_session', 'accurate_db_host', 'accurate_db_id',
    ]);
    final config = <String, String>{};
    for (final row in rows) { config[row['key']] = row['value'] ?? ''; }
    return config;
  }

  static bool isTokenValid(Map<String, String> config) {
    final token = config['accurate_access_token'] ?? '';
    final expiry = config['accurate_token_expiry'] ?? '';
    if (token.isEmpty) return false;
    if (expiry.isEmpty) return true;
    try { return DateTime.now().isBefore(DateTime.parse(expiry)); } catch (_) { return false; }
  }

  static Future<List<Map<String, dynamic>>> fetchDatabaseList(String accessToken) async {
    final data = await _proxy(accurateUrl: '$_oauthBaseUrl/api/db-list.do', headers: {'Authorization': 'Bearer $accessToken'});
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
    final data = await _proxy(accurateUrl: '$_oauthBaseUrl/api/open-db.do?id=$realId', headers: {'Authorization': 'Bearer $accessToken'});

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
    for (final c in configs) { await admin.from('app_config').upsert(c, onConflict: 'key'); }
  }

  // ============================================================
  // FAKTUR PENJUALAN - LIST
  // ============================================================
  static Future<Map<String, dynamic>> fetchSalesInvoices(
    String host, String session, String token, { int? customerId, int page = 1, int pageSize = 50,
  }) async {
    final params = <String, String>{
      'sp.page': '$page', 'sp.pageSize': '$pageSize',
      'fields': 'id,number,transDate,dueDate,grandTotal,totalAmount,statusName,status,customer.id,customer.name',
      'filter.transDate.val[0]': '01/01/2000',
      'filter.transDate.val[1]': '31/12/2099',
      'filter.transDate.op': 'BETWEEN', 
    };
    
    if (customerId != null) {
      params['filter.customer.id.val[0]'] = '$customerId';
      params['filter.customer.id.op'] = 'EQUAL';
    }

    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final url = '$host/accurate/api/sales-invoice/list.do?$queryString';
    
    final data = await _proxy(accurateUrl: url, headers: {
      'X-Session-ID': session,
      'Authorization': 'Bearer $token'
    });
    
    return data;
  }

  // ============================================================
  // FAKTUR PENJUALAN - DETAIL
  // ============================================================
  static Future<Map<String, dynamic>> fetchInvoiceDetail(
    String host, String session, String token, int invoiceId,
  ) async {
    final url = '$host/accurate/api/sales-invoice/detail.do?id=$invoiceId';
    
    final data = await _proxy(accurateUrl: url, headers: {
      'X-Session-ID': session,
      'Authorization': 'Bearer $token'
    });

    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil detail faktur';
    }
    return data;
  }

  // ============================================================
  // RETUR PENJUALAN (SALES RETURN)
  // ============================================================
  static Future<Map<String, dynamic>> fetchSalesReturns(
    String host, String session, String token, { int? customerId, int page = 1, int pageSize = 50,
  }) async {
    final params = <String, String>{
      'sp.page': '$page', 'sp.pageSize': '$pageSize',
      'fields': 'id,number,transDate,totalAmount,grandTotal,statusName,status,customer.id,customer.name',
      'filter.transDate.val[0]': '01/01/2000',
      'filter.transDate.val[1]': '31/12/2099',
      'filter.transDate.op': 'BETWEEN',
    };
    
    if (customerId != null) {
      params['filter.customer.id.val[0]'] = '$customerId';
      params['filter.customer.id.op'] = 'EQUAL';
    }

    final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    
    final data = await _proxy(accurateUrl: '$host/accurate/api/sales-return/list.do?$queryString', headers: {
      'X-Session-ID': session,
      'Authorization': 'Bearer $token'
    });

    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil retur penjualan';
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getAccurateCustomers() async {
    try {
      final config = await _supabase.from('app_config').select().inFilter('key', ['accurate_db_host', 'accurate_access_token', 'accurate_db_session']);
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }
      if (host == null || token == null || session == null || host.isEmpty || session.isEmpty || token.isEmpty) { 
        throw Exception('Kredensial Accurate tidak ditemukan.'); 
      }

      final url = Uri.parse('$host/accurate/api/customer/list.do?fields=id,customerNo,name,mobilePhone');
      final response = await _proxy(accurateUrl: url.toString(), headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session});
      if (response['s'] == true && response['d'] != null) {
        return List<Map<String, dynamic>>.from(response['d']);
      } else { throw Exception('API Error: ${response['d']}'); }
    } catch (e) { rethrow; }
  }

  // ============================================================
  // HELPER: Cek apakah faktur LUNAS dari data detail
  // ============================================================
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

  // ============================================================
  // HELPER: Ambil tanggal bayar/close dari detail faktur
  // ============================================================
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
        if (str.contains('/')) {
          return DateTime.parse(_parseAccurateDate(str));
        }
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
          if (historyDate.contains('/')) {
            return DateTime.parse(_parseAccurateDate(historyDate));
          }
          return DateTime.parse(historyDate);
        } catch (_) {}
      }
    }

    return null;
  }

  // ============================================================
  // FUNGSI INTI: SYNC FAKTUR & RETUR
  // ============================================================
  static Future<SyncResult> syncInvoicesToPoints({
    required SupabaseClient admin,
    required String host,
    required String session,
    Function(String)? onProgress,
  }) async {
    int totalInvoicesChecked = 0; int totalReturnsChecked = 0;
    int totalPointsAdded = 0; int totalPointsDeducted = 0;
    int totalUsersAffected = 0; int totalSkipped = 0;
    final List<String> errors = [];

    try {
      onProgress?.call('Mencari data user...');
      print('=== MULAI SYNC ===');

      final tokenConfig = await admin.from('app_config').select('value').eq('key', 'accurate_access_token').maybeSingle();
      final String token = tokenConfig?['value']?.toString() ?? '';

      if (token.isEmpty) throw 'Token Authorization tidak ditemukan di sistem. Silakan login Accurate ulang.';
      
      final users = await admin.from('profiles').select('id, full_name, points, accurate_customer_id, point_conversion_rate')
          .eq('approval_status', 'APPROVED').not('accurate_customer_id', 'is', null).neq('accurate_customer_id', '');

      if (users.isEmpty) {
        print('INFO: Tidak ada user yang di-approve & punya Accurate ID');
        return SyncResult(message: 'Tidak ada user dengan Accurate Customer ID.', totalInvoicesChecked: 0, totalPointsAdded: 0, totalUsersAffected: 0, totalSkipped: 0);
      }

      final globalConfig = await admin.from('app_config').select('value').eq('key', 'default_conversion_rate').maybeSingle();
      final int globalRate = int.tryParse(globalConfig?['value'] ?? '10000') ?? 10000;

      for (final user in users) {
        final String userId = user['id'];
        final String userName = user['full_name'] ?? 'Unknown';
        final String accurateCustomerId = user['accurate_customer_id'].toString().trim();
        final int conversionRate = (user['point_conversion_rate'] as num?)?.toInt() ?? globalRate;
        final int currentPoints = (user['points'] as num?)?.toInt() ?? 0;

        print('\nMemeriksa Toko: $userName (ID: $accurateCustomerId)');
        onProgress?.call('Sync Toko: $userName...');

        try {
          int userPointsGained = 0; 
          
          // =============================================
          // 1. PROSES FAKTUR PENJUALAN
          // =============================================
          int page = 1; bool hasMore = true;
          while (hasMore) {
            final result = await fetchSalesInvoices(host, session, token, customerId: int.tryParse(accurateCustomerId), page: page, pageSize: 50);
            final List<dynamic> invoices = result['d'] ?? [];
            final int totalCount = (result['totalCount'] as num?)?.toInt() ?? invoices.length;

            for (final invoice in invoices) {
              totalInvoicesChecked++;
              final int invoiceId = (invoice['id'] as num?)?.toInt() ?? 0;
              final String invoiceNumber = invoice['number']?.toString() ?? '';

              if (invoiceNumber.isEmpty || invoiceId <= 0) { 
                print('  -> [SKIP] Faktur $invoiceNumber: Data kosong atau ID 0.');
                totalSkipped++; continue; 
              }

              // [GEMBOK 1] Cek List (Kalau API Accurate kasih ID di list)
              final String listCustId = invoice['customer']?['id']?.toString() ?? invoice['customer.id']?.toString() ?? '';
              if (listCustId.isNotEmpty && listCustId != accurateCustomerId) {
                print('  -> [SKIP] Faktur $invoiceNumber nyasar di list (Milik ID $listCustId)');
                totalSkipped++; continue;
              }

              // --- Anti-double: Sudah pernah disync? ---
              final existing = await admin.from('point_history').select('id').eq('reference_type', 'INVOICE').eq('reference_id', invoiceNumber).maybeSingle();
              if (existing != null) { 
                print('  -> [SKIP] Faktur $invoiceNumber: Sudah pernah diklaim.');
                totalSkipped++; continue; 
              }

              // --- AMBIL DETAIL FAKTUR ---
              onProgress?.call('Detail faktur $invoiceNumber...');
              
              Map<String, dynamic> detailData;
              try {
                final detailResponse = await fetchInvoiceDetail(host, session, token, invoiceId);
                detailData = (detailResponse['d'] is Map) ? Map<String, dynamic>.from(detailResponse['d']) : {};
              } catch (e) {
                print('  -> [ERROR] Gagal ambil detail $invoiceNumber: $e');
                errors.add('Faktur $invoiceNumber: Gagal ambil detail ($e)');
                totalSkipped++; continue;
              }

              // [GEMBOK 2 MUTLAK] Validasi ID dari Detail Faktur
              final String detailCustId = detailData['customer']?['id']?.toString() ?? '';
              if (detailCustId.isNotEmpty && detailCustId != accurateCustomerId) {
                print('  -> [SKIP MUTLAK] Faktur $invoiceNumber aslinya milik ID $detailCustId, bukan $accurateCustomerId! DITOLAK!');
                totalSkipped++; 
                continue;
              }

              // --- CEK 1: Apakah LUNAS? ---
              final bool isFullyPaid = _isInvoiceFullyPaid(detailData);
              final String statusDebug = detailData['statusName']?.toString() ?? detailData['status']?.toString() ?? 'UNKNOWN';
              
              if (!isFullyPaid) {
                print('  -> [SKIP] Faktur $invoiceNumber: BELUM LUNAS (status: $statusDebug)');
                totalSkipped++; continue;
              }

              // --- CEK 2: Apakah bayar SEBELUM jatuh tempo? ---
              final String dueDateStr = detailData['dueDate']?.toString() ?? invoice['dueDate']?.toString() ?? '';
              if (dueDateStr.isNotEmpty) {
                final DateTime dueDate = DateTime.parse(_parseAccurateDate(dueDateStr));
                DateTime? paymentDate = _getPaymentDate(detailData);
                
                if (paymentDate != null) {
                  if (paymentDate.isAfter(dueDate)) {
                    print('  -> [SKIP] Faktur $invoiceNumber: TELAT BAYAR (tempo: $dueDate)');
                    totalSkipped++; continue;
                  }
                } else {
                  if (DateTime.now().isAfter(dueDate)) {
                    print('  -> [SKIP] Faktur $invoiceNumber: Melewati jatuh tempo, tgl bayar tidak jelas.');
                    totalSkipped++; continue;
                  }
                }
              }

              // --- HITUNG POIN (DIPERBAIKI) ---
              final double nominalFaktur = (detailData['grandTotal'] as num?)?.toDouble() 
                  ?? (detailData['totalAmount'] as num?)?.toDouble() 
                  ?? (invoice['grandTotal'] as num?)?.toDouble() 
                  ?? (invoice['totalAmount'] as num?)?.toDouble() ?? 0;

              if (nominalFaktur <= 0) { 
                print('  -> [SKIP] Faktur $invoiceNumber: Nominal 0 (totalAmount tidak terbaca).');
                totalSkipped++; continue; 
              }

              final int pointsEarned = (nominalFaktur / conversionRate).floor();
              if (pointsEarned <= 0) { totalSkipped++; continue; }

              // --- SIMPAN POIN ---
              await admin.from('point_history').insert({
                'user_id': userId, 'amount': pointsEarned, 'description': 'Faktur Lunas #$invoiceNumber',
                'reference_type': 'INVOICE', 'reference_id': invoiceNumber, 'created_at': DateTime.now().toIso8601String(),
              });
              userPointsGained += pointsEarned;
              totalPointsAdded += pointsEarned;
              print('  -> [SUCCESS] Faktur $invoiceNumber: +$pointsEarned Poin (nominal: $nominalFaktur, rate: $conversionRate)');
            }
            hasMore = (page * 50) < totalCount; page++; if (page > 10) hasMore = false;
          }

          // =============================================
          // 2. PROSES RETUR PENJUALAN
          // =============================================
          int pageRetur = 1; bool hasMoreRetur = true;
          while (hasMoreRetur) {
            final resultRetur = await fetchSalesReturns(host, session, token, customerId: int.tryParse(accurateCustomerId), page: pageRetur, pageSize: 50);
            final List<dynamic> returns = resultRetur['d'] ?? [];
            final int totalCountRetur = (resultRetur['totalCount'] as num?)?.toInt() ?? returns.length;

            for (final ret in returns) {
              totalReturnsChecked++;
              final String returnNumber = ret['number']?.toString() ?? '';
              final double nominalRetur = (ret['totalAmount'] as num?)?.toDouble() ?? (ret['grandTotal'] as num?)?.toDouble() ?? 0;

              // [GEMBOK RETUR] Validasi ID Customer
              final String returnCustomerId = ret['customer']?['id']?.toString() ?? ret['customer.id']?.toString() ?? '';
              if (returnCustomerId.isNotEmpty && returnCustomerId != accurateCustomerId) {
                continue;
              }

              if (returnNumber.isEmpty || nominalRetur <= 0) continue;

              final existingRetur = await admin.from('point_history').select('id').eq('reference_type', 'RETURN').eq('reference_id', returnNumber).maybeSingle();
              if (existingRetur != null) continue;

              final int pointsDeducted = (nominalRetur / conversionRate).floor();
              if (pointsDeducted <= 0) continue;

              await admin.from('point_history').insert({
                'user_id': userId, 'amount': -pointsDeducted, 'description': 'Retur Penjualan #$returnNumber',
                'reference_type': 'RETURN', 'reference_id': returnNumber, 'created_at': DateTime.now().toIso8601String(),
              });
              userPointsGained -= pointsDeducted; 
              totalPointsDeducted += pointsDeducted;
            }
            hasMoreRetur = (pageRetur * 50) < totalCountRetur; pageRetur++; if (pageRetur > 10) hasMoreRetur = false;
          }

          // =============================================
          // 3. UPDATE PROFIL POIN
          // =============================================
          if (userPointsGained != 0) { 
            int finalPoints = currentPoints + userPointsGained;
            if (finalPoints < 0) finalPoints = 0; 
            await admin.from('profiles').update({'points': finalPoints, 'updated_at': DateTime.now().toIso8601String()}).eq('id', userId);
            totalUsersAffected++;
            print('  => [UPDATE] Saldo akhir $userName: $finalPoints Poin (perubahan: ${userPointsGained > 0 ? "+$userPointsGained" : "$userPointsGained"})');
          }

        } catch (e) {
          if (e.toString() == 'SESSION_EXPIRED') rethrow;
          errors.add('$userName: $e');
        }
      }

      return SyncResult(
        message: 'Sync Selesai!\nFaktur dicek: $totalInvoicesChecked (+ $totalPointsAdded Poin).\nRetur dicek: $totalReturnsChecked (- $totalPointsDeducted Poin).\nTotal $totalUsersAffected user diperbarui.',
        totalInvoicesChecked: totalInvoicesChecked, totalPointsAdded: totalPointsAdded,
        totalUsersAffected: totalUsersAffected, totalSkipped: totalSkipped, errors: errors,
      );
    } catch (e) { rethrow; }
  }

  static String _parseAccurateDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])).toIso8601String();
    } catch (_) {}
    return DateTime.now().toIso8601String();
  }

  static Future<void> disconnect(SupabaseClient admin) async {
    final keys = ['accurate_access_token', 'accurate_token_expiry', 'accurate_db_session', 'accurate_db_host', 'accurate_db_id'];
    for (final key in keys) { await admin.from('app_config').upsert({'key': key, 'value': ''}, onConflict: 'key'); }
  }
}

class SyncResult {
  final String message; final int totalInvoicesChecked; final int totalPointsAdded; final int totalUsersAffected; final int totalSkipped; final List<String> errors;
  SyncResult({ required this.message, required this.totalInvoicesChecked, required this.totalPointsAdded, required this.totalUsersAffected, required this.totalSkipped, this.errors = const [], });
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upsol_loyalty/admin/admin_supabase.dart';

class AccurateService {
  final _supabase = Supabase.instance.client;

  static const String defaultClientId = '79aaa170-8897-4cf7-b0d1-b8ec78dd07d1';
  static const String defaultDbId = '2663607';

  static String get _redirectUri => '${Uri.base.origin}/oauth_callback.html';
  static const String _oauthBaseUrl = 'https://account.accurate.id';
  static const String _scope =
      'sales_invoice_view customer_view item_view sales_invoice_save sales_return_view';

  static String normalizeCustomerNo(String raw) => raw.trim().toUpperCase();

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

  static Future<Map<String, List<Map<String, dynamic>>>> _preloadAllInvoices({
    required String host, required String session, required String token,
    required String startDateStr, required String endDateStr, Function(String)? onProgress,
  }) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    int page = 1; bool hasMore = true;
    while (hasMore) {
      onProgress?.call('Memuat semua faktur halaman $page...');
      final params = <String, String>{
        'sp.page': '$page', 'sp.pageSize': '100',
        'fields': 'id,number,transDate,dueDate,grandTotal,totalAmount,statusName,status,customer',
        'filter.transDate.val[0]': startDateStr, 'filter.transDate.val[1]': endDateStr,
        'filter.transDate.op': 'BETWEEN',
      };
      final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final data = await _proxy(
        accurateUrl: '$host/accurate/api/sales-invoice/list.do?$queryString',
        headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
      );
      if (data['s'] == false) {
        if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
        throw data['d']?.toString() ?? 'Gagal ambil faktur';
      }
      final List<dynamic> invoices = data['d'] ?? [];
      print('[PRELOAD] Halaman $page: ${invoices.length} faktur diterima dari API');
      for (final invoice in invoices) {
        String rawCustNo = '';
        if (invoice['customer'] is Map) {
          rawCustNo = invoice['customer']['customerNo']?.toString() ??
              invoice['customer']['no']?.toString() ?? '';
        }
        if (rawCustNo.isEmpty) {
          rawCustNo = invoice['customer.customerNo']?.toString() ??
              invoice['customer.no']?.toString() ?? '';
        }
        final String custNo = normalizeCustomerNo(rawCustNo);
        print('[PRELOAD]   ${invoice['number']} | transDate: ${invoice['transDate']} '
            '| custNo_norm: "$custNo"${custNo.isEmpty ? " ⚠️ SKIP" : ""}');
        if (custNo.isEmpty) continue;
        grouped.putIfAbsent(custNo, () => []).add(Map<String, dynamic>.from(invoice));
      }
      hasMore = invoices.isNotEmpty;
      page++;
      if (page > 100) hasMore = false;
    }
    return grouped;
  }

  static Future<Map<String, List<Map<String, dynamic>>>> _preloadAllReturns({
    required String host, required String session, required String token,
    required String startDateStr, required String endDateStr, Function(String)? onProgress,
  }) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    int page = 1; bool hasMore = true;
    while (hasMore) {
      onProgress?.call('Memuat semua retur halaman $page...');
      final params = <String, String>{
        'sp.page': '$page', 'sp.pageSize': '100',
        'fields': 'id,number,transDate,totalAmount,grandTotal,statusName,status,customer',
        'filter.transDate.val[0]': startDateStr, 'filter.transDate.val[1]': endDateStr,
        'filter.transDate.op': 'BETWEEN',
      };
      final queryString = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      final data = await _proxy(
        accurateUrl: '$host/accurate/api/sales-return/list.do?$queryString',
        headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
      );
      if (data['s'] == false) {
        if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
        throw data['d']?.toString() ?? 'Gagal ambil retur';
      }
      final List<dynamic> returns = data['d'] ?? [];
      for (final ret in returns) {
        final String custNo = normalizeCustomerNo(
            ret['customer']?['customerNo']?.toString() ??
            ret['customer.customerNo']?.toString() ?? '');
        if (custNo.isEmpty) continue;
        grouped.putIfAbsent(custNo, () => []).add(Map<String, dynamic>.from(ret));
      }
      hasMore = returns.isNotEmpty;
      page++;
      if (page > 50) hasMore = false;
    }
    return grouped;
  }

  static Future<Map<String, dynamic>> fetchInvoiceDetail(
      String host, String session, String token, int invoiceId) async {
    final data = await _proxy(
      accurateUrl: '$host/accurate/api/sales-invoice/detail.do?id=$invoiceId',
      headers: {'X-Session-ID': session, 'Authorization': 'Bearer $token'},
    );
    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil detail faktur';
    }
    return data;
  }

  static Future<Map<String, dynamic>> fetchReturnDetail(
      String host, String session, String token, int returnId) async {
    final data = await _proxy(
      accurateUrl: '$host/accurate/api/sales-return/detail.do?id=$returnId',
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
      final historyDate = receiptHistory.last['historyDate']?.toString().trim() ?? '';
      if (historyDate.isNotEmpty) {
        try {
          if (historyDate.contains('/')) return DateTime.parse(_parseAccurateDate(historyDate));
          return DateTime.parse(historyDate);
        } catch (_) {}
      }
    }
    return null;
  }

  static DateTime _extractDate(Map<String, dynamic> detail, Map<String, dynamic> fallback) {
    final str = detail['transDate']?.toString() ?? fallback['transDate']?.toString() ?? '';
    if (str.isEmpty) return DateTime.now();
    if (str.contains('/')) return DateTime.parse(_parseAccurateDate(str));
    try { return DateTime.parse(str); } catch (_) { return DateTime.now(); }
  }

  // ── Helper: cari multiplier dari tier rules ──────────────────────────────
  static double _findMultiplier(double rupiah, List<dynamic> rawTiers) {
    for (var tier in rawTiers) {
      double min = (tier['min'] as num?)?.toDouble() ?? 0;
      double? max = tier['max'] != null ? (tier['max'] as num).toDouble() : null;
      if (rupiah >= min && (max == null || rupiah <= max)) {
        return (tier['multiplier'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }

  static Future<SyncResult> syncInvoicesToPoints({
    required SupabaseClient admin,
    required String host,
    required String session,
    required DateTime startDate,
    required DateTime endDate,
    Function(String)? onProgress,
  }) async {
    int totalInvoicesChecked = 0; int totalReturnsChecked = 0;
    int totalPointsAdded = 0; int totalPointsDeducted = 0;
    int totalUsersAffected = 0; int totalSkipped = 0;
    final List<String> errors = [];

    try {
      final tokenConfig = await admin
          .from('app_config').select('value').eq('key', 'accurate_access_token').maybeSingle();
      final String token = tokenConfig?['value']?.toString() ?? '';
      if (token.isEmpty) throw 'Token Authorization tidak ditemukan di sistem.';

      final String startStr = DateFormat('dd/MM/yyyy').format(startDate);
      final String endStr = DateFormat('dd/MM/yyyy').format(endDate);

      onProgress?.call('Memuat semua faktur ($startStr - $endStr)...');
      final allInvoicesByCustomer = await _preloadAllInvoices(
        host: host, session: session, token: token,
        startDateStr: startStr, endDateStr: endStr, onProgress: onProgress,
      );

      onProgress?.call('Memuat semua retur ($startStr - $endStr)...');
      final allReturnsByCustomer = await _preloadAllReturns(
        host: host, session: session, token: token,
        startDateStr: startStr, endDateStr: endStr, onProgress: onProgress,
      );

      onProgress?.call('Menyiapkan konfigurasi sistem...');
      final graceConfig = await admin
          .from('app_config').select('value').eq('key', 'grace_period_days').maybeSingle();
      int gracePeriodDays = int.tryParse(graceConfig?['value']?.toString() ?? '0') ?? 0;

      Map<String, dynamic> tierRules = {};
      try {
        final tr = await admin
            .from('app_config').select('value').eq('key', 'point_tiering_rules').maybeSingle();
        if (tr != null && tr['value'] != null) tierRules = jsonDecode(tr['value'].toString());
      } catch (e) { print('Gagal load tier rules: $e'); }

      final int baseAmount = tierRules['base_amount'] ?? 100000;
      final List<dynamic> rawTiers = tierRules['tiers'] ?? [];

      print('\n════════════════════════════════════════════════════════');
      print('SYNC START  $startStr → $endStr');
      print('Grace period : $gracePeriodDays hari | Base: Rp $baseAmount | Tiers: ${rawTiers.length}');
      print('════════════════════════════════════════════════════════\n');

      onProgress?.call('Mencari data user...');
      final users = await admin
          .from('profiles')
          .select('id, full_name, points, accurate_customer_id')
          .eq('approval_status', 'APPROVED')
          .not('accurate_customer_id', 'is', null)
          .neq('accurate_customer_id', '');
      if (users.isEmpty) {
        return SyncResult(message: 'Tidak ada user valid.',
            totalInvoicesChecked: 0, totalPointsAdded: 0,
            totalUsersAffected: 0, totalSkipped: 0);
      }

      for (final user in users) {
        final String userId = user['id'];
        final String userName = user['full_name'] ?? 'Unknown';
        final String accurateCustomerNo =
            normalizeCustomerNo(user['accurate_customer_id'].toString());
        if (accurateCustomerNo.isEmpty) continue;

        onProgress?.call('Sync Toko: $userName...');
        print('\n┌─────────────────────────────────────────────────────');
        print('│ USER: $userName | CUST: $accurateCustomerNo');

        try {
          final List<Map<String, dynamic>> userInvoices =
              allInvoicesByCustomer[accurateCustomerNo] ?? [];
          final List<Map<String, dynamic>> userReturns =
              allReturnsByCustomer[accurateCustomerNo] ?? [];

          print('│ Faktur cache: ${userInvoices.length} | Retur cache: ${userReturns.length}');
          print('└─────────────────────────────────────────────────────');

          final existingHistory = await admin
              .from('point_history')
              .select('reference_id, reference_type')
              .eq('user_id', userId);
          final Set<String> claimedInvoices = {};
          final Set<String> claimedReturns = {};
          for (var h in existingHistory) {
            final type = h['reference_type'];
            final refId = h['reference_id']?.toString() ?? '';
            if (type == 'INVOICE') claimedInvoices.add(refId);
            if (type == 'RETURN') claimedReturns.add(refId);
          }
          print('[FILTER] Diklaim: ${claimedInvoices.length} faktur, ${claimedReturns.length} retur');

          final List<Map<String, dynamic>> validTransactions = [];

          // ── 1. FILTER FAKTUR BARU ────────────────────────────────────────
          for (final invoice in userInvoices) {
            final String invoiceNumber = invoice['number']?.toString() ?? '';
            final int invoiceId = (invoice['id'] as num?)?.toInt() ?? 0;
            print('\n[FAKTUR] $invoiceNumber (id=$invoiceId)');

            if (invoiceNumber.isEmpty || invoiceId <= 0) {
              print('  → SKIP: nomor/id tidak valid'); totalSkipped++; continue;
            }
            if (invoiceNumber.toUpperCase().startsWith('SI')) {
              print('  → SKIP: prefix SI'); totalSkipped++; continue;
            }
            if (claimedInvoices.contains(invoiceNumber)) {
              print('  → SKIP: sudah diklaim'); totalSkipped++; continue;
            }

            final String listCustNo = normalizeCustomerNo(
              invoice['customer']?['customerNo']?.toString() ??
              invoice['customer.customerNo']?.toString() ?? '',
            );
            if (listCustNo.isNotEmpty && listCustNo != accurateCustomerNo) {
              print('  → SKIP: custNo tidak match'); totalSkipped++; continue;
            }

            Map<String, dynamic> detailData;
            try {
              final detailResponse = await fetchInvoiceDetail(host, session, token, invoiceId);
              detailData = (detailResponse['d'] is Map)
                  ? Map<String, dynamic>.from(detailResponse['d'] as Map) : {};
            } catch (e) {
              print('  → SKIP: gagal ambil detail — $e');
              errors.add('Faktur $invoiceNumber: Gagal ambil detail'); continue;
            }

            final String detailCustNo =
                normalizeCustomerNo(detailData['customer']?['customerNo']?.toString() ?? '');
            if (detailCustNo.isNotEmpty && detailCustNo != accurateCustomerNo) {
              print('  → SKIP: custNo detail tidak match'); totalSkipped++; continue;
            }

            final String sName = (detailData['statusName'] ?? '').toString();
            final String sCode = (detailData['status'] ?? '').toString();
            final bool fullyPaid = _isInvoiceFullyPaid(detailData);
            print('  statusName="$sName" status="$sCode" → lunas=$fullyPaid');
            if (!fullyPaid) { print('  → SKIP: belum lunas'); totalSkipped++; continue; }

            final String dueDateStr =
                detailData['dueDate']?.toString() ?? invoice['dueDate']?.toString() ?? '';
            if (dueDateStr.isNotEmpty) {
              final DateTime adjustedDueDate =
                  DateTime.parse(_parseAccurateDate(dueDateStr))
                      .add(Duration(days: gracePeriodDays));
              final DateTime? paymentDate = _getPaymentDate(detailData);
              print('  adjustedDue=$adjustedDueDate | paymentDate=$paymentDate');
              if (paymentDate != null) {
                if (paymentDate.isAfter(adjustedDueDate)) {
                  print('  → SKIP: terlambat bayar'); totalSkipped++; continue;
                }
              } else {
                if (DateTime.now().isAfter(adjustedDueDate)) {
                  print('  → SKIP: paymentDate null & now > due'); totalSkipped++; continue;
                }
              }
            }

            final double nominalFaktur =
                (detailData['grandTotal'] as num?)?.toDouble() ??
                (detailData['totalAmount'] as num?)?.toDouble() ??
                (invoice['grandTotal'] as num?)?.toDouble() ??
                (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
            if (nominalFaktur <= 0) { print('  → SKIP: nominal 0'); totalSkipped++; continue; }

            print('  ✅ LOLOS — Rp ${nominalFaktur.toStringAsFixed(0)}');
            validTransactions.add({
              'type': 'INVOICE', 'ref_id': invoiceNumber,
              'nominal': nominalFaktur, 'date': _extractDate(detailData, invoice),
            });
            totalInvoicesChecked++;
          }

          // ── 2. FILTER RETUR BARU ─────────────────────────────────────────
          for (final ret in userReturns) {
            final String returnNumber = ret['number']?.toString() ?? '';
            final int returnId = (ret['id'] as num?)?.toInt() ?? 0;
            if (returnNumber.isEmpty || returnId <= 0 || claimedReturns.contains(returnNumber)) continue;

            Map<String, dynamic> returDetail;
            try {
              final res = await fetchReturnDetail(host, session, token, returnId);
              returDetail = (res['d'] is Map) ? Map<String, dynamic>.from(res['d'] as Map) : {};
            } catch (e) { continue; }

            final String retCustNo =
                normalizeCustomerNo(returDetail['customer']?['customerNo']?.toString() ?? '');
            if (retCustNo.isNotEmpty && retCustNo != accurateCustomerNo) continue;

            final double nominalRetur =
                (returDetail['grandTotal'] as num?)?.toDouble() ??
                (returDetail['totalAmount'] as num?)?.toDouble() ??
                (ret['grandTotal'] as num?)?.toDouble() ??
                (ret['totalAmount'] as num?)?.toDouble() ?? 0;
            if (nominalRetur <= 0) continue;

            print('[RETUR] $returnNumber ✅ Rp ${nominalRetur.toStringAsFixed(0)}');
            validTransactions.add({
              'type': 'RETURN', 'ref_id': returnNumber,
              'nominal': nominalRetur, 'date': _extractDate(returDetail, ret),
            });
            totalReturnsChecked++;
          }

          validTransactions.sort(
              (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

          print('\n[VALID TRX] $userName: ${validTransactions.length} transaksi baru');

          // ── Ambil yearly_accumulations dari DB (bukan hanya dari validTransactions) ──
          final yearlyRes = await admin
              .from('yearly_accumulations').select().eq('user_id', userId);
          Map<int, Map<String, dynamic>> yearlyData = {};
          for (var row in yearlyRes) {
            yearlyData[row['year'] as int] = Map<String, dynamic>.from(row);
          }

          Set<int> affectedYears = {};

          // ── 3. INSERT TRANSAKSI BARU ─────────────────────────────────────
          // accurate_points di yearlyData digunakan untuk menghitung tier SETELAH
          // semua transaksi baru ini masuk. Mulai dari nilai yang sudah ada di DB.
          for (final trx in validTransactions) {
            final int year = (trx['date'] as DateTime).year;
            affectedYears.add(year);

            if (!yearlyData.containsKey(year)) {
              yearlyData[year] = {
                'user_id': userId, 'year': year,
                'accurate_points': 0, 'reward_points_given': 0,
              };
            }

            final accData = yearlyData[year]!;
            final double nominal = trx['nominal'];
            int poinMentah = (nominal / baseAmount).floor();
            if (trx['type'] == 'RETURN') poinMentah = -poinMentah;

            accData['accurate_points'] =
                (accData['accurate_points'] as int) + poinMentah;
            if ((accData['accurate_points'] as int) < 0) accData['accurate_points'] = 0;

            // Insert dengan amount=0 dan multiplier_used=0 dulu
            // akan di-update benar di Step 4
            await admin.from('point_history').insert({
              'user_id': userId,
              'amount': 0,
              'base_nominal': nominal,
              'multiplier_used': 0.0, // akan di-update di Step 4
              'description': trx['type'] == 'INVOICE'
                  ? 'Faktur Lunas #${trx['ref_id']}'
                  : 'Retur Penjualan #${trx['ref_id']}',
              'reference_type': trx['type'],
              'reference_id': trx['ref_id'],
              'created_at': (trx['date'] as DateTime).toIso8601String(),
            });
          }

          bool hasUpdates = false;

          // ── 4. RETROACTIVE UPDATE + simpan multiplier_used ───────────────
          // accurate_points di yearlyData sekarang = nilai DB lama + transaksi baru
          // Ini yang dipakai untuk menentukan tier final
          for (int year in affectedYears) {
            final accData = yearlyData[year]!;
            double currentRupiah = (accData['accurate_points'] as int) * baseAmount.toDouble();
            double currentMultiplier = _findMultiplier(currentRupiah, rawTiers);

            print('\n══════════════════════════════════════════════════════════');
            print('RETROAKTIF TAHUN $year — $userName');
            print('Akumulasi: Rp ${currentRupiah.toStringAsFixed(0)} | Tier: ${currentMultiplier}x');
            print('──────────────────────────────────────────────────────────');

            final allYearHistory = await admin
                .from('point_history')
                .select()
                .eq('user_id', userId)
                .gte('created_at', '$year-01-01T00:00:00.000Z')
                .lte('created_at', '$year-12-31T23:59:59.999Z')
                .inFilter('reference_type', ['INVOICE', 'RETURN'])
                .order('created_at', ascending: true);

            for (var h in allYearHistory) {
              double nominal = (h['base_nominal'] as num?)?.toDouble() ?? 0;
              if (nominal <= 0) continue;

              int basePoin = (nominal / baseAmount).floor();
              int expectedAmount = (basePoin * currentMultiplier).floor();
              if (h['reference_type'] == 'RETURN') expectedAmount = -expectedAmount;

              int currentAmount = (h['amount'] as num?)?.toInt() ?? 0;
              double savedMultiplier = (h['multiplier_used'] as num?)?.toDouble() ?? 0.0;
              int diff = expectedAmount - currentAmount;
              bool multiplierChanged = savedMultiplier != currentMultiplier;

              print('${h['reference_type']} ${h['reference_id']}'
                  ' | Rp ${nominal.toStringAsFixed(0)}'
                  ' | ${basePoin}p x ${currentMultiplier}x → ${expectedAmount}p'
                  ' | db=${currentAmount}p | saved_mult=${savedMultiplier}x'
                  ' | diff=${diff > 0 ? "+$diff" : "$diff"}'
                  '${(diff != 0 || multiplierChanged) ? " ← UPDATE" : " ✓"}');

              // Update jika amount berubah ATAU multiplier_used belum tersimpan
              if (diff != 0 || multiplierChanged) {
                await admin
                    .from('point_history')
                    .update({
                      'amount': expectedAmount,
                      'multiplier_used': currentMultiplier, // simpan multiplier yang dipakai
                    })
                    .eq('id', h['id']);
                if (diff > 0) totalPointsAdded += diff;
                else if (diff < 0) totalPointsDeducted += diff.abs();
                hasUpdates = true;
              }
            }
            print('══════════════════════════════════════════════════════════\n');
          }

          // ── 5. SIMPAN TOTAL & UPDATE SALDO ───────────────────────────────
          if (hasUpdates || validTransactions.isNotEmpty) {
            for (final accData in yearlyData.values) {
              await admin.from('yearly_accumulations').upsert({
                'user_id': userId,
                'year': accData['year'],
                'accurate_points': accData['accurate_points'],
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'user_id, year');
            }

            // Hitung saldo dari INVOICE & RETURN saja (exclude RESET_*)
            final allHistory = await admin
                .from('point_history')
                .select('amount')
                .eq('user_id', userId)
                .inFilter('reference_type', ['INVOICE', 'RETURN']);
            int finalPoints = 0;
            for (var item in allHistory) {
              finalPoints += (item['amount'] as num?)?.toInt() ?? 0;
            }
            if (finalPoints < 0) finalPoints = 0;
            await admin.from('profiles').update({
              'points': finalPoints,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);

            print('[SALDO] $userName → $finalPoints poin');
            totalUsersAffected++;
          } else {
            print('[SALDO] $userName → tidak ada perubahan');
          }

        } catch (e) {
          if (e.toString() == 'SESSION_EXPIRED') rethrow;
          errors.add('$userName: $e');
          print('[ERROR] $userName: $e');
        }
      }

      print('\n════════════════════════════════════════════════════════');
      print('SYNC SELESAI | Faktur: $totalInvoicesChecked (+$totalPointsAdded p)'
          ' | Retur: $totalReturnsChecked (-$totalPointsDeducted p)'
          ' | Skipped: $totalSkipped | Users: $totalUsersAffected');
      if (errors.isNotEmpty) { for (final e in errors) print('  ERR: $e'); }
      print('════════════════════════════════════════════════════════\n');

      return SyncResult(
        message: 'Sync Selesai!\n'
            'Faktur baru: $totalInvoicesChecked (+$totalPointsAdded Poin).\n'
            'Retur baru: $totalReturnsChecked (-$totalPointsDeducted Poin).\n'
            '$totalUsersAffected user diperbarui.',
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
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]),
        ).toIso8601String();
      }
    } catch (_) {}
    return DateTime.now().toIso8601String();
  }

  static Future<void> disconnect(SupabaseClient admin) async {
    final keys = [
      'accurate_access_token', 'accurate_token_expiry',
      'accurate_db_session', 'accurate_db_host', 'accurate_db_id',
    ];
    for (final key in keys) {
      await admin.from('app_config').upsert({'key': key, 'value': ''}, onConflict: 'key');
    }
  }

  Future<List<Map<String, dynamic>>> getAccurateCustomers(
      {String keyword = '', String statusFilter = 'ALL'}) async {
    try {
      final config = await _supabase.from('app_config').select().inFilter('key', [
        'accurate_db_host', 'accurate_access_token', 'accurate_db_session',
      ]);
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
          headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session});
      if (response['s'] == true && response['d'] != null) {
        return List<Map<String, dynamic>>.from(response['d']);
      } else { throw Exception('API Error: ${response['d']}'); }
    } catch (e) { rethrow; }
  }

  Future<bool> updateCustomerToAccurate({
    required String customerNo, required String name,
    String? email, String? phone, String? address,
  }) async {
    try {
      final config = await _supabase.from('app_config').select().inFilter('key', [
        'accurate_db_host', 'accurate_access_token', 'accurate_db_session',
      ]);
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
      if (internalId == null || internalId <= 0) return false;
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
    } catch (e) { return false; }
  }

  Future<int?> _getInternalIdByCustomerNo(String customerNo,
      {String? host, String? token, String? session}) async {
    try {
      if (host == null || token == null || session == null) return null;
      final urlStr =
          '$host/accurate/api/customer/list.do?fields=id,customerNo,name'
          '&keywords=${Uri.encodeComponent(customerNo)}&sp.pageSize=20';
      final response = await _proxy(
        accurateUrl: urlStr,
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
      );
      if (response['s'] == true && response['d'] != null) {
        final List data = response['d'];
        for (final item in data) {
          if (normalizeCustomerNo(item['customerNo']?.toString() ?? '') == customerNo) {
            return (item['id'] as num?)?.toInt();
          }
        }
      }
      return null;
    } catch (e) { return null; }
  }

  Future<void> syncLocalToAccurate({
    required List<Map<String, dynamic>> profiles,
    Function(String)? onProgress,
  }) async {
    int successCount = 0; int failCount = 0;
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
      final supabase = AdminSupabase.client;
      final profiles = await supabase
          .from('profiles').select('accurate_customer_id').not('accurate_customer_id', 'is', null);
      final Set<String> registeredNos = profiles
          .map((p) => normalizeCustomerNo(p['accurate_customer_id'].toString()))
          .toSet();
      int currentPage = 1; bool hasMore = true;
      while (hasMore) {
        final customers = await getAccurateCustomersPaged(page: currentPage);
        if (customers.isEmpty) break;
        for (var customer in customers) {
          final String customerNo = normalizeCustomerNo(customer['customerNo']?.toString() ?? '');
          final String email = customer['email']?.toString().trim() ?? '';
          final String name = customer['name']?.toString() ?? 'Pelanggan Accurate';
          final String phone = customer['mobilePhone']?.toString() ?? '';
          if (customerNo.isNotEmpty && !registeredNos.contains(customerNo) && email.isNotEmpty) {
            try {
              final res = await supabase.auth.admin.inviteUserByEmail(email);
              if (res.user?.id != null) {
                await supabase.from('profiles').upsert({
                  'id': res.user!.id, 'email': email, 'full_name': name,
                  'phone': phone, 'accurate_customer_id': customerNo,
                  'approval_status': 'APPROVED', 'is_profile_completed': false, 'has_password': false,
                });
                registeredNos.add(customerNo);
              }
            } catch (_) {}
          }
        }
        if (customers.length < 100) hasMore = false; else currentPage++;
        if (currentPage > 50) hasMore = false;
      }
    } catch (e) { rethrow; }
  }

  Future<List<Map<String, dynamic>>> getAccurateCustomersPaged({required int page}) async {
    final config = await _supabase.from('app_config').select().inFilter('key', [
      'accurate_db_host', 'accurate_access_token', 'accurate_db_session',
    ]);
    String? host, token, session;
    for (var row in config) {
      if (row['key'] == 'accurate_db_host') host = row['value'];
      if (row['key'] == 'accurate_access_token') token = row['value'];
      if (row['key'] == 'accurate_db_session') session = row['value'];
    }
    final String urlStr =
        '$host/accurate/api/customer/list.do?fields=id,customerNo,name,email,mobilePhone'
        '&sp.pageSize=100&sp.page=$page';
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
      final config = await _supabase.from('app_config').select().inFilter('key', [
        'accurate_db_host', 'accurate_access_token', 'accurate_db_session',
      ]);
      String? host, token, session;
      for (var row in config) {
        if (row['key'] == 'accurate_db_host') host = row['value'];
        if (row['key'] == 'accurate_access_token') token = row['value'];
        if (row['key'] == 'accurate_db_session') session = row['value'];
      }
      if (host == null || token == null || session == null) return null;
      final String normalized = normalizeCustomerNo(customerNo);
      final String urlStr =
          '$host/accurate/api/customer/list.do?fields=id,customerNo,name,email,mobilePhone'
          '&keywords=${Uri.encodeComponent(normalized)}&sp.pageSize=20';
      final response = await _proxy(
        accurateUrl: urlStr,
        headers: {'Authorization': 'Bearer $token', 'X-Session-ID': session},
      );
      if (response['s'] == true && response['d'] != null) {
        final List data = response['d'];
        for (final item in data) {
          if (normalizeCustomerNo(item['customerNo']?.toString() ?? '') == normalized) {
            return Map<String, dynamic>.from(item);
          }
        }
      }
      return null;
    } catch (e) { return null; }
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
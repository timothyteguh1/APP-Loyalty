import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

class AccurateService {
  static const String _clientId = '79aaa170-8897-4cf7-b0d1-b8ec78dd07d1';
  static const String _redirectUri = 'http://localhost:3000/oauth_callback.html';
  static const String _oauthBaseUrl = 'https://account.accurate.id';
  static const String _scope = 'sales_invoice_view customer_view item_view sales_invoice_save';
  static const String _knownDbId = 'a4512d3a-0595-4bf9-bc6f-9d89016f0ffc';

  // ============================================================
  // PROXY - Semua request ke Accurate lewat Edge Function
  // Ini menghindari CORS error di Flutter Web
  // ============================================================
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

  // ============================================================
  // BUILD AUTH URL
  // ============================================================
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

  // ============================================================
  // SAVE TOKEN
  // ============================================================
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

  // ============================================================
  // LOAD CONFIG
  // ============================================================
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

  // ============================================================
  // AMBIL DAFTAR DATABASE (via proxy)
  // ============================================================
  static Future<List<Map<String, dynamic>>> fetchDatabaseList(String accessToken) async {
    final data = await _proxy(
      accurateUrl: '$_oauthBaseUrl/api/db-list.do',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (data['s'] != true) throw data['d']?.toString() ?? 'Gagal ambil daftar database';
    final List<dynamic> dbs = data['d'] ?? [];
    return dbs.cast<Map<String, dynamic>>();
  }

  // ============================================================
  // BUKA DATABASE (via proxy)
  // ============================================================
  static Future<Map<String, String>> openDatabase(String accessToken, String dbId) async {
    // Ambil daftar DB dulu untuk dapat integer ID yang benar
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

    // FIX: host dan session ada di TOP LEVEL response, bukan di dalam data['d']
    // Response format: { "d": ["Proses Berhasil Dilakukan"], "host": "https://...", "session": "xxx", "s": true }
    final host = data['host']?.toString() ?? 'https://public.accurate.id';
    final session = data['session']?.toString() ?? '';
    if (session.isEmpty) throw 'Session tidak ditemukan';

    return {'host': host, 'session': session};
  }

  // ============================================================
  // SAVE SESSION
  // ============================================================
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
  // AMBIL FAKTUR PENJUALAN (via proxy)
  // ============================================================
  static Future<Map<String, dynamic>> fetchSalesInvoices(
    String host,
    String session, {
    int? customerId,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, String>{
      'sp.page': '$page',
      'sp.pageSize': '$pageSize',
      'fields': 'id,number,transactionDate,grandTotal,customer.id,customer.name',
    };
    if (customerId != null) params['filter.customer.id'] = '$customerId';

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final data = await _proxy(
      accurateUrl: '$host/accurate/api/sales-invoice/list.do?$queryString',
      headers: {'X-Session-ID': session},
    );

    if (data['s'] == false) {
      if (data['d']?.toString().contains('session') == true) throw 'SESSION_EXPIRED';
      throw data['d']?.toString() ?? 'Gagal ambil faktur';
    }

    return data;
  }

  // ============================================================
  // BUAT FAKTUR DI ACCURATE dari transaksi Upsol (via proxy)
  // Dipanggil saat QR scan berhasil
  // ============================================================
  static Future<String?> createSalesInvoice({
    required String host,
    required String session,
    required int accurateCustomerId,
    required String customerName,
    required double amount,
    required String description,
    required String upsolRefId, // reference_id dari point_history
  }) async {
    try {
      // Format tanggal untuk Accurate: dd/MM/yyyy
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      // Buat body faktur
      final invoiceBody = {
        'transactionDate': dateStr,
        'customer.id': '$accurateCustomerId',
        'description': description,
        // Detail item faktur
        'detailItem[0].itemNo': 'UPSOL-TXN',
        'detailItem[0].name': description,
        'detailItem[0].quantity': '1',
        'detailItem[0].unitPrice': '${amount.toInt()}',
        'detailItem[0].discountPercent': '0',
      };

      final data = await _proxy(
        accurateUrl: '$host/accurate/api/sales-invoice/save.do',
        headers: {'X-Session-ID': session},
        method: 'POST',
        body: invoiceBody,
      );

      if (data['s'] == true) {
        return data['d']?['number']?.toString(); // Return nomor faktur
      }
      return null;
    } catch (e) {
      // Jangan throw — gagal buat faktur tidak boleh blokir poin
      return null;
    }
  }

  // ============================================================
  // SYNC FAKTUR ACCURATE → POIN LOKAL
  // Anti-double via reference_id = nomor faktur
  // ============================================================
  static Future<SyncResult> syncInvoicesToPoints({
    required SupabaseClient admin,
    required String host,
    required String session,
    Function(String)? onProgress,
  }) async {
    int totalInvoicesChecked = 0;
    int totalPointsAdded = 0;
    int totalUsersAffected = 0;
    int totalSkipped = 0;
    final List<String> errors = [];

    try {
      onProgress?.call('Mengambil daftar user dengan Accurate ID...');

      final users = await admin
          .from('profiles')
          .select('id, full_name, points, accurate_customer_id, point_conversion_rate')
          .eq('approval_status', 'APPROVED')
          .not('accurate_customer_id', 'is', null)
          .neq('accurate_customer_id', '');

      if (users.isEmpty) {
        return SyncResult(
          message: 'Tidak ada user dengan Accurate Customer ID.',
          totalInvoicesChecked: 0,
          totalPointsAdded: 0,
          totalUsersAffected: 0,
          totalSkipped: 0,
        );
      }

      onProgress?.call('Ditemukan ${users.length} user. Mulai sync...');

      final globalConfig = await admin
          .from('app_config')
          .select('value')
          .eq('key', 'default_conversion_rate')
          .maybeSingle();
      final int globalRate = int.tryParse(globalConfig?['value'] ?? '10000') ?? 10000;

      for (final user in users) {
        final String userId = user['id'];
        final String userName = user['full_name'] ?? 'Unknown';
        final String accurateCustomerId = user['accurate_customer_id'].toString();
        final int conversionRate = (user['point_conversion_rate'] as num?)?.toInt() ?? globalRate;
        final int currentPoints = (user['points'] as num?)?.toInt() ?? 0;

        onProgress?.call('Sync: $userName...');

        try {
          int userPointsGained = 0;
          int page = 1;
          bool hasMore = true;

          while (hasMore) {
            final result = await fetchSalesInvoices(
              host, session,
              customerId: int.tryParse(accurateCustomerId),
              page: page,
              pageSize: 50,
            );

            final List<dynamic> invoices = result['d'] ?? [];
            final int totalCount = (result['totalCount'] as num?)?.toInt() ?? invoices.length;

            for (final invoice in invoices) {
              totalInvoicesChecked++;
              final String invoiceNumber = invoice['number']?.toString() ?? '';
              final double grandTotal = (invoice['grandTotal'] as num?)?.toDouble() ?? 0;

              if (invoiceNumber.isEmpty || grandTotal <= 0) {
                totalSkipped++;
                continue;
              }

              // Anti-double check
              final existing = await admin
                  .from('point_history')
                  .select('id')
                  .eq('reference_type', 'INVOICE')
                  .eq('reference_id', invoiceNumber)
                  .eq('user_id', userId)
                  .maybeSingle();

              if (existing != null) {
                totalSkipped++;
                continue;
              }

              final int pointsEarned = (grandTotal / conversionRate).floor();
              if (pointsEarned <= 0) {
                totalSkipped++;
                continue;
              }

              // Insert ke point_history
              await admin.from('point_history').insert({
                'user_id': userId,
                'amount': pointsEarned,
                'description': 'Faktur #$invoiceNumber (Rp ${grandTotal.toStringAsFixed(0)})',
                'reference_type': 'INVOICE',
                'reference_id': invoiceNumber,
                'created_at': invoice['transactionDate'] != null
                    ? _parseAccurateDate(invoice['transactionDate'].toString())
                    : DateTime.now().toIso8601String(),
              });

              userPointsGained += pointsEarned;
            }

            hasMore = (page * 50) < totalCount;
            page++;
            if (page > 10) hasMore = false; // Safety limit
          }

          if (userPointsGained > 0) {
            await admin.from('profiles').update({
              'points': currentPoints + userPointsGained,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);
            totalPointsAdded += userPointsGained;
            totalUsersAffected++;
          }
        } catch (e) {
          if (e.toString() == 'SESSION_EXPIRED') rethrow;
          errors.add('$userName: $e');
        }
      }

      return SyncResult(
        message: 'Sync selesai! $totalInvoicesChecked faktur dicek, +$totalPointsAdded poin ke $totalUsersAffected user. $totalSkipped dilewati.',
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

  // Helper: parse tanggal dari format Accurate "dd/MM/yyyy" ke ISO
  static String _parseAccurateDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        ).toIso8601String();
      }
    } catch (_) {}
    return DateTime.now().toIso8601String();
  }

  // ============================================================
  // DISCONNECT
  // ============================================================
  static Future<void> disconnect(SupabaseClient admin) async {
    final keys = [
      'accurate_access_token', 'accurate_token_expiry',
      'accurate_db_session', 'accurate_db_host', 'accurate_db_id',
    ];
    for (final key in keys) {
      await admin.from('app_config').upsert({'key': key, 'value': ''}, onConflict: 'key');
    }
  }
}

// ============================================================
// SYNC RESULT MODEL
// ============================================================
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
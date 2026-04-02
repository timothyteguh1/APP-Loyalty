import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  // ============================================================
  // FUNGSI DAFTAR (BARU - SESUAI SCOPE PDF)
  // ============================================================
  Future<void> signUp({
    required String email,
    required String password,
    required String phone,
    required String fullName, // Nama Toko
    required String picName,
    required String storeAddress,
    required String domisili,
    required String ktpNumber,
    Uint8List? ktpImageBytes, // Data gambar KTP
    String? ktpFileName, // Nama file KTP
  }) async {
    try {
      // 1. Daftarkan ke Supabase Auth
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      if (res.user == null) {
        throw 'Gagal membuat akun. Coba lagi.';
      }

      final String userId = res.user!.id;

      // 2. Upload Foto KTP ke Storage (jika ada)
      String? ktpImageUrl;
      if (ktpImageBytes != null && ktpFileName != null) {
        final ext = ktpFileName.split('.').last;
        final fileName = 'ktp_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _supabase.storage.from('upsol-assets').uploadBinary(
              fileName,
              ktpImageBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        ktpImageUrl =
            _supabase.storage.from('upsol-assets').getPublicUrl(fileName);
      }

      // 3. Update tabel profiles dengan data lengkap
      //    (Row profiles sudah otomatis dibuat oleh trigger Supabase saat signUp)
      //    Kita tinggal UPDATE dengan data tambahan
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'pic_name': picName,
        'phone': phone,
        'store_address': storeAddress,
        'domisili': domisili,
        'ktp_number': ktpNumber,
        'ktp_image_url': ktpImageUrl,
        'approval_status': 'PENDING', // Pastikan status PENDING
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        throw 'Email ini sudah terdaftar. Coba login saja.';
      }
      throw 'Gagal mendaftar: ${e.message}';
    } catch (e) {
      // Jika error bukan AuthException, langsung lempar
      if (e is String) rethrow;
      throw 'Gagal mendaftar: $e';
    }
  }

  // ============================================================
  // FUNGSI LOGIN FLEKSIBEL (EMAIL ATAU NO HP)
  // ============================================================
  Future<void> signIn({required String identifier, required String password}) async {
    try {
      String emailToLogin = identifier.trim();

      // Deteksi apakah input adalah No HP (angka semua / diawali +)
      final bool isPhone = _isPhoneNumber(identifier.trim());

      if (isPhone) {
        // Cari email yang terkait dengan No HP ini dari tabel profiles
        // Kita pakai .maybeSingle() agar tidak error jika tidak ditemukan
        final result = await _supabase
            .from('profiles')
            .select('id')
            .eq('phone', identifier.trim())
            .maybeSingle();

        if (result == null) {
          throw 'Nomor HP tidak ditemukan. Pastikan sudah terdaftar.';
        }

        // Ambil email dari auth.users via admin atau workaround:
        // Karena kita tidak bisa query auth.users dari client,
        // kita simpan email juga di profiles saat registrasi.
        // Alternatif: cari di profiles jika kita tambah kolom email di profiles.
        // Untuk sekarang, kita gunakan pendekatan: user harus ingat emailnya juga.
        // ATAU kita lookup lewat Supabase Auth Admin API (butuh service role).
        //
        // SOLUSI PRAGMATIS: Kita tambah lookup email via RPC atau
        // kita minta user tetap login pakai email.
        // Untuk saat ini, kita coba cara ini:

        // Gunakan RPC function untuk mendapatkan email berdasarkan phone
        final emailResult = await _supabase.rpc('get_email_by_phone', params: {
          'phone_input': identifier.trim(),
        });

        if (emailResult == null || emailResult.toString().isEmpty) {
          throw 'Nomor HP tidak terkait dengan akun manapun.';
        }

        emailToLogin = emailResult.toString();
      }

      // Login dengan email
      await _supabase.auth.signInWithPassword(
        email: emailToLogin,
        password: password,
      );
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login') ||
          e.message.contains('invalid_credentials')) {
        throw 'Email/No HP atau Password salah. Cek lagi ya!';
      } else if (e.message.contains('Email not confirmed')) {
        throw 'Email belum diverifikasi. Cek inbox kamu.';
      }
      throw 'Login gagal: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal terhubung. Periksa internetmu.';
    }
  }

  // ============================================================
  // CEK STATUS APPROVAL USER
  // ============================================================
  Future<String> checkApprovalStatus() async {
    final user = currentUser;
    if (user == null) return 'UNKNOWN';

    try {
      final data = await _supabase
          .from('profiles')
          .select('approval_status')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return 'PENDING';
      return data['approval_status'] ?? 'PENDING';
    } catch (e) {
      return 'PENDING';
    }
  }

  // ============================================================
  // AMBIL DATA PROFILE LENGKAP (untuk Rejected Page dll)
  // ============================================================
  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return data;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // UPDATE PROFILE (untuk perbaiki data setelah REJECTED)
  // ============================================================
  Future<void> updateProfileForResubmit({
    required String fullName,
    required String picName,
    required String phone,
    required String storeAddress,
    required String domisili,
    required String ktpNumber,
    Uint8List? ktpImageBytes,
    String? ktpFileName,
  }) async {
    final user = currentUser;
    if (user == null) throw 'User tidak ditemukan';

    try {
      String? ktpImageUrl;
      if (ktpImageBytes != null && ktpFileName != null) {
        final ext = ktpFileName.split('.').last;
        final fileName =
            'ktp_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _supabase.storage.from('upsol-assets').uploadBinary(
              fileName,
              ktpImageBytes,
              fileOptions: const FileOptions(upsert: true),
            );

        ktpImageUrl =
            _supabase.storage.from('upsol-assets').getPublicUrl(fileName);
      }

      final updateData = <String, dynamic>{
        'full_name': fullName,
        'pic_name': picName,
        'phone': phone,
        'store_address': storeAddress,
        'domisili': domisili,
        'ktp_number': ktpNumber,
        'approval_status': 'PENDING', // Reset ke PENDING
        'rejection_reason': null, // Bersihkan alasan lama
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (ktpImageUrl != null) {
        updateData['ktp_image_url'] = ktpImageUrl;
      }

      await _supabase.from('profiles').update(updateData).eq('id', user.id);
    } catch (e) {
      throw 'Gagal memperbarui data: $e';
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ============================================================
  // HELPER: Deteksi apakah string adalah nomor telepon
  // ============================================================
  bool _isPhoneNumber(String input) {
    // Hapus spasi dan strip
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Cek apakah diawali + atau angka, dan sisanya angka semua
    if (cleaned.startsWith('+')) {
      return RegExp(r'^\+\d{8,15}$').hasMatch(cleaned);
    }
    // Atau angka murni (08xxx)
    return RegExp(r'^\d{8,15}$').hasMatch(cleaned);
  }
}
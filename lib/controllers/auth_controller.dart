import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/email_notification_service.dart';

class AuthController {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  // ============================================================
  // FUNGSI DAFTAR (DENGAN EMAIL VERIFIKASI)
  // ============================================================
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String phone,
    required String fullName,
    required String picName,
    required String storeAddress,
    required String domisili,
    required String ktpNumber,
    String? accurateCustomerId, // [NEW] Parameter Kode Pelanggan
    Uint8List? ktpImageBytes,
    String? ktpFileName,
  }) async {
    try {
      // [PENTING] Mencegah string kosong masuk dan menabrak Unique Constraint di Database
      final validAccurateId = (accurateCustomerId != null && accurateCustomerId.trim().isNotEmpty) 
          ? accurateCustomerId.trim() 
          : null;

      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'pic_name': picName,
          'phone': phone,
          'store_address': storeAddress,
          'domisili': domisili,
          'ktp_number': ktpNumber,
          'accurate_customer_id': validAccurateId, // [NEW] Simpan ke metadata
        },
      );

      if (res.user == null) {
        throw 'Gagal membuat akun. Coba lagi.';
      }

      final String userId = res.user!.id;
      final bool needsEmailVerification = (res.session == null);

      String? ktpImageUrl;
      if (ktpImageBytes != null && ktpFileName != null) {
        final ext = ktpFileName.split('.').last;
        final fileName = 'ktp_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        try {
          await _supabase.storage.from('upsol-assets').uploadBinary(
                fileName, ktpImageBytes,
                fileOptions: const FileOptions(upsert: true),
              );
          ktpImageUrl = _supabase.storage.from('upsol-assets').getPublicUrl(fileName);
        } catch (e) {
          debugPrint('KTP upload note: $e');
        }
      }

      // Pastikan data profil terupdate dengan KTP URL (jika ada) dan accurate_customer_id
      try {
        final updateData = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (ktpImageUrl != null) updateData['ktp_image_url'] = ktpImageUrl;
        if (validAccurateId != null) updateData['accurate_customer_id'] = validAccurateId; // [NEW] Fallback Update

        if (updateData.length > 1) { // Hanya update jika ada KTP atau Accurate ID
          await _supabase.from('profiles').update(updateData).eq('id', userId);
        }
      } catch (e) {
        debugPrint('Profile update note: $e');
      }

      // ======= EMAIL NOTIFIKASI: Notify Admin tentang pendaftaran baru =======
      try {
        final adminConfig = await _supabase
            .from('app_config')
            .select('value')
            .eq('key', 'admin_emails')
            .maybeSingle();
        if (adminConfig != null) {
          final adminEmails = (adminConfig['value'] as String)
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
          for (final adminEmail in adminEmails) {
            EmailNotificationService.sendNewRegistration(
              toEmail: adminEmail,
              userName: fullName,
              userPhone: phone,
            );
          }
        }
      } catch (_) {}
      // ======= END EMAIL =======

      return {
        'needsEmailVerification': needsEmailVerification,
        'email': email,
        'userId': userId,
      };
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        throw 'Email ini sudah terdaftar. Coba login saja.';
      }
      if (e.message.contains('rate limit') || e.message.contains('over_email_send_rate_limit')) {
        throw 'Terlalu banyak percobaan. Tunggu beberapa menit.';
      }
      throw 'Gagal mendaftar: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal mendaftar: $e';
    }
  }

  // ============================================================
  // KIRIM ULANG EMAIL VERIFIKASI
  // ============================================================
  Future<void> resendVerificationEmail({required String email}) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      if (e.message.contains('rate limit') || e.message.contains('over_email_send_rate_limit')) {
        throw 'Terlalu sering mengirim. Tunggu beberapa menit.';
      }
      throw 'Gagal mengirim ulang: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal mengirim ulang email verifikasi.';
    }
  }

  // ============================================================
  // LUPA PASSWORD — Kirim email reset
  // ============================================================
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      if (e.message.contains('rate limit') || e.message.contains('over_email_send_rate_limit')) {
        throw 'Terlalu sering mengirim. Tunggu beberapa menit.';
      }
      throw 'Gagal mengirim email reset: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal mengirim email reset password.';
    }
  }

  // ============================================================
  // FUNGSI LOGIN
  // ============================================================
  Future<void> signIn({required String identifier, required String password}) async {
    try {
      String emailToLogin = identifier.trim();
      final bool isPhone = _isPhoneNumber(identifier.trim());

      if (isPhone) {
        final result = await _supabase
            .from('profiles').select('id').eq('phone', identifier.trim()).maybeSingle();
        if (result == null) throw 'Nomor HP tidak ditemukan. Pastikan sudah terdaftar.';

        final emailResult = await _supabase.rpc('get_email_by_phone', params: {'phone_input': identifier.trim()});
        if (emailResult == null || emailResult.toString().isEmpty) throw 'Nomor HP tidak terkait dengan akun manapun.';
        emailToLogin = emailResult.toString();
      }

      await _supabase.auth.signInWithPassword(email: emailToLogin, password: password);
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login') || e.message.contains('invalid_credentials')) {
        throw 'Email/No HP atau Password salah. Cek lagi ya!';
      } else if (e.message.contains('Email not confirmed') || e.message.contains('email_not_confirmed')) {
        throw 'EMAIL_NOT_CONFIRMED';
      }
      throw 'Login gagal: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal terhubung. Periksa internetmu.';
    }
  }

  // ============================================================
  // CEK STATUS APPROVAL
  // ============================================================
  Future<String> checkApprovalStatus() async {
    final user = currentUser;
    if (user == null) return 'UNKNOWN';
    try {
      final data = await _supabase.from('profiles').select('approval_status').eq('id', user.id).maybeSingle();
      if (data == null) return 'PENDING';
      return data['approval_status'] ?? 'PENDING';
    } catch (e) { return 'PENDING'; }
  }

  // ============================================================
  // AMBIL PROFILE
  // ============================================================
  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      return await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
    } catch (e) { return null; }
  }

  // ============================================================
  // UPDATE PROFILE (setelah REJECTED)
  // ============================================================
  Future<void> updateProfileForResubmit({
    required String fullName, required String picName,
    required String phone, required String storeAddress,
    required String domisili, required String ktpNumber,
    Uint8List? ktpImageBytes, String? ktpFileName,
  }) async {
    final user = currentUser;
    if (user == null) throw 'User tidak ditemukan';
    try {
      String? ktpImageUrl;
      if (ktpImageBytes != null && ktpFileName != null) {
        final ext = ktpFileName.split('.').last;
        final fileName = 'ktp_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('upsol-assets').uploadBinary(fileName, ktpImageBytes, fileOptions: const FileOptions(upsert: true));
        ktpImageUrl = _supabase.storage.from('upsol-assets').getPublicUrl(fileName);
      }

      final updateData = <String, dynamic>{
        'full_name': fullName, 'pic_name': picName, 'phone': phone,
        'store_address': storeAddress, 'domisili': domisili, 'ktp_number': ktpNumber,
        'approval_status': 'PENDING', 'rejection_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (ktpImageUrl != null) updateData['ktp_image_url'] = ktpImageUrl;

      await _supabase.from('profiles').update(updateData).eq('id', user.id);
    } catch (e) { throw 'Gagal memperbarui data: $e'; }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ============================================================
  // HELPER
  // ============================================================
  bool _isPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) return RegExp(r'^\+\d{8,15}$').hasMatch(cleaned);
    return RegExp(r'^\d{8,15}$').hasMatch(cleaned);
  }
}
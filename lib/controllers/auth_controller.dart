import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/email_notification_service.dart';

class AuthController {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  // ============================================================
  // FUNGSI DAFTAR (JALUR MANDIRI)
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
    String? accurateCustomerId,
  }) async {
    try {
      final validAccurateId = (accurateCustomerId != null && accurateCustomerId.trim().isNotEmpty)
          ? accurateCustomerId.trim()
          : null;

      String finalEmail = email.trim();
      bool isDummyEmail = false;
      
      if (finalEmail.isEmpty) {
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        finalEmail = '$cleanPhone@bka.local'; 
        isDummyEmail = true;
      }

      final AuthResponse res = await _supabase.auth.signUp(
        email: finalEmail,
        password: password,
        data: {
          'full_name': fullName,
          'pic_name': picName,
        },
      );

      final user = res.user;
      if (user == null) throw 'Gagal membuat akun. Coba lagi.';

      await _supabase.from('profiles').update({
        'full_name': fullName,
        'pic_name': picName,
        'phone': phone,
        'store_address': storeAddress,
        'domisili': domisili,
        'ktp_number': ktpNumber,
        'accurate_customer_id': validAccurateId,
        'email': isDummyEmail ? null : finalEmail, 
        'has_password': true,
        'is_profile_completed': true,
        'approval_status': 'PENDING',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      final String userId = user.id;
      final bool needsEmailVerification = !isDummyEmail && (res.session == null);

      // ======= EMAIL NOTIFIKASI ADMIN =======
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
        'email': finalEmail,
        'userId': userId,
      };
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        throw 'Akun ini sudah terdaftar. Coba login saja.';
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

  Future<void> resendVerificationEmail({required String email}) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      if (e.message.contains('rate limit')) throw 'Terlalu sering mengirim. Tunggu beberapa menit.';
      throw 'Gagal mengirim ulang: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal mengirim ulang email verifikasi.';
    }
  }

  // ============================================================
  // MINTA BANTUAN RESET PASSWORD KE ADMIN
  // ============================================================
  Future<void> requestPasswordResetToAdmin({required String identifier}) async {
    try {
      String cleanId = identifier.trim().toLowerCase();
      final bool isPhone = _isPhoneNumber(cleanId);
      
      if (isPhone && cleanId.startsWith('+62')) {
        cleanId = cleanId.replaceFirst('+62', '0');
      }

      // 1. Ambil nama toko (Dibungkus try-catch agar aplikasi tidak crash jika Supabase mengunci tabel profiles untuk anonim)
      Map<String, dynamic>? userData;
      try {
        if (isPhone) {
          userData = await _supabase.from('profiles').select('full_name, phone').eq('phone', cleanId).maybeSingle();
        } else {
          userData = await _supabase.from('profiles').select('full_name, phone').eq('email', cleanId).maybeSingle();
        }
      } catch (e) {
        debugPrint('Pencarian nama diabaikan karena gembok RLS Supabase: $e');
      }

      final String userName = userData?['full_name'] ?? 'User BKA (Data dilindungi)';
      final String userPhone = userData?['phone'] ?? cleanId;

      // 2. Ambil list email admin dari app_config
      final adminConfig = await _supabase
          .from('app_config')
          .select('value')
          .eq('key', 'admin_emails')
          .maybeSingle();

      if (adminConfig != null && adminConfig['value'] != null) {
        final adminEmails = (adminConfig['value'] as String)
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        if (adminEmails.isEmpty) throw 'Email admin belum disetel di database.';

        // 3. Tembak email ke masing-masing admin via Edge Function menggunakan template baru
        bool isSuccess = false;
        for (final adminEmail in adminEmails) {
          final result = await EmailNotificationService.sendPasswordResetRequest(
            toEmail: adminEmail,
            userName: userName,
            userPhone: userPhone,
          );
          if (result) isSuccess = true; // Anggap sukses jika minimal 1 terkirim
        }

        if (!isSuccess) throw 'Gagal meneruskan email melalui Edge Function.';
      } else {
        throw 'Konfigurasi email admin tidak ditemukan di database.';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Error sistem: ${e.toString()}'; 
    }
  }

  // ============================================================
  // FUNGSI LOGIN
  // ============================================================
  Future<void> signIn({required String identifier, required String password}) async {
    String emailToLogin = identifier.trim().toLowerCase();
    
    try {
      final bool isPhone = _isPhoneNumber(identifier.trim());

      if (isPhone) {
        final result = await _supabase
            .from('profiles')
            .select('id')
            .eq('phone', identifier.trim())
            .maybeSingle();
        if (result == null) throw 'Nomor HP tidak ditemukan. Pastikan sudah terdaftar.';

        final emailResult = await _supabase.rpc(
          'get_email_by_phone',
          params: {'phone_input': identifier.trim()},
        );
        if (emailResult == null || emailResult.toString().isEmpty) {
          throw 'Nomor HP tidak terkait dengan akun manapun.';
        }
        emailToLogin = emailResult.toString();
      }

      final profileCheck = await _supabase
          .from('profiles')
          .select('has_password')
          .eq('email', emailToLogin)
          .maybeSingle();

      bool hasPassword = profileCheck?['has_password'] == true;

      if (!hasPassword && profileCheck == null) {
        try {
          final rpcResult = await _supabase.rpc(
            'get_profile_by_auth_email',
            params: {'email_input': emailToLogin},
          );
          if (rpcResult != null) {
            hasPassword = rpcResult['has_password'] == true;
          }
        } catch (_) {}
      }

      if (!hasPassword) {
        throw 'NEEDS_OTP_LOGIN';
      }

      await _supabase.auth.signInWithPassword(
        email: emailToLogin,
        password: password,
      );

      final user = _supabase.auth.currentUser;
      if (user != null) {
        final latestProfile = await _supabase
            .from('profiles')
            .select('approval_status')
            .eq('id', user.id)
            .maybeSingle();
            
        if (latestProfile != null && latestProfile['approval_status'] == 'PENDING') {
           if (emailToLogin.endsWith('@bka.local')) {
             throw 'PHONE_NOT_VERIFIED_YET';
           }
        }
      }

    } on AuthException catch (e) {
      if (e.message.contains('Invalid login') || e.message.contains('invalid_credentials')) {
        throw 'Email/No HP atau Password salah. Cek lagi ya!';
      } else if (e.message.contains('Email not confirmed') || e.message.contains('email_not_confirmed')) {
        if (emailToLogin.endsWith('@bka.local')) {
          throw 'PHONE_NOT_VERIFIED_YET';
        }
        throw 'EMAIL_NOT_CONFIRMED';
      }
      throw 'Login gagal: ${e.message}';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Gagal terhubung. Periksa internetmu.';
    }
  }

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

  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

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
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'pic_name': picName,
        'phone': phone,
        'store_address': storeAddress,
        'domisili': domisili,
        'ktp_number': ktpNumber,
        'approval_status': 'PENDING',
        'rejection_reason': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      throw 'Gagal memperbarui data: $e';
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  bool _isPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+')) return RegExp(r'^\+\d{8,15}$').hasMatch(cleaned);
    return RegExp(r'^\d{8,15}$').hasMatch(cleaned);
  }
}
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  // Instance Supabase biar ga perlu dipanggil ulang terus
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. GET USER (Cek sesi saat ini)
  User? get currentUser => _supabase.auth.currentUser;

  // 2. REGISTER (Daftar Akun Baru)
  // Kita simpan 'name' dan 'role' langsung di Metadata user biar gampang diambil.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'owner', // Default owner untuk pendaftar pertama
  }) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': role, 
          // Metadata ini aman tersimpan di server Supabase Auth
        },
      );
    } on AuthException catch (e) {
      // Error spesifik dari Supabase (misal: email sudah ada)
      throw e.message;
    } catch (e) {
      // Error lain (koneksi, dll)
      throw 'Terjadi kesalahan saat pendaftaran: $e';
    }
  }

  // 3. LOGIN (Masuk Akun)
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // Error spesifik (password salah, user tidak ditemukan)
      throw e.message;
    } catch (e) {
      throw 'Gagal login: $e';
    }
  }

  // 4. LOGOUT (Keluar)
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
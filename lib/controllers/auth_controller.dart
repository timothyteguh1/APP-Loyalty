import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  // --- FUNGSI DAFTAR ---
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String domisili,
  }) async {
    try {
      // 1. Mendaftarkan ke Auth (Pemicu Robot SQL)
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'domisili': domisili, 
        },
      );

      // [LETAK KODE INSERT MANUAL]
      // Jika Robot SQL gagal, Anda bisa mengaktifkan baris di bawah ini:
      /*
      if (res.user != null) {
        await _supabase.from('profiles').insert({
          'id': res.user!.id,
          'full_name': name,
          'domicile': domisili, // Menggunakan 'domicile'
          'points': 0,
        });
      }
      */
    } on AuthException catch (e) {
      throw e.message;
    } catch (e) {
      throw 'Gagal mendaftar: $e';
    }
  }

  // --- FUNGSI LOGIN ---
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'otp_page.dart'; // [TAMBAHAN] Pastikan file otp_page.dart sudah dibuat
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class EmailEntryPage extends StatefulWidget {
  const EmailEntryPage({super.key});

  @override
  State<EmailEntryPage> createState() => _EmailEntryPageState();
}

class _EmailEntryPageState extends State<EmailEntryPage> {
  final _emailController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan alamat email yang valid!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, approval_status, is_profile_completed')
          .eq('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        // [NOTIFIKASI 1: AKUN BELUM ADA]
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akun belum terdaftar. Silakan buat akun baru.'), 
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 2),
          ),
        );
        // User tidak ada di database, arahkan ke daftar baru
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
      } else {
        final isCompleted = response['is_profile_completed'] == true;
        final status = response['approval_status'];

        if (status == 'PENDING' && !isCompleted) {
          // [NOTIFIKASI 2: AKUN ACCURATE TAPI BELUM LENGKAP]
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akun dari Accurate ditemukan! Mengirim kode OTP ke email Anda...'), 
              backgroundColor: Color(0xFF10B981), // Warna Hijau Success
              duration: Duration(seconds: 3),
            ),
          );

          // [ROMBAKAN ALUR OTP]
          // USER ACCURATE TERDETEKSI! 
          // 1. Kirim OTP ke emailnya
          await _supabase.auth.signInWithOtp(email: email);
          
          // 2. Pindah ke halaman input OTP
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => OtpPage(email: email)));
          }
        } else {
          // [NOTIFIKASI 3: AKUN SUDAH AKTIF NORMAL]
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akun aktif ditemukan. Silakan login.'), 
              backgroundColor: Colors.blueAccent,
              duration: Duration(seconds: 2),
            ),
          );
          // User lama yang sudah aktif, arahkan ke login biasa
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_circle_rounded, size: 80, color: Color(0xFFB71C1C)),
              const SizedBox(height: 24),
              const Text('Selamat Datang', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text('Masukkan email Anda untuk melanjutkan', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 40),
              CustomTextField(
                controller: _emailController,
                label: 'Alamat Email',
                hint: 'contoh@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Lanjutkan',
                onPressed: _isLoading ? () {} : _checkEmail,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
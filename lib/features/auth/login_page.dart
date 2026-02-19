import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import '../home/home_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authController = AuthController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    // 1. Validasi Input Kosong
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Email dan Password harus diisi ya.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Proses Login
      await _authController.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      
      // 3. Sukses -> Pindah ke Home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );

    } on AuthException catch (e) {
      // --- [BAGIAN PENTING: PENERJEMAH ERROR] ---
      String friendlyMessage = "Terjadi kesalahan. Coba lagi nanti.";
      
      // Cek pesan error dari Supabase (biasanya "Invalid login credentials")
      if (e.message.contains('Invalid login') || e.message.contains('invalid_credentials')) {
        friendlyMessage = "Email atau Password salah. Cek lagi ya!";
      } else if (e.message.contains('Email not confirmed')) {
        friendlyMessage = "Email belum diverifikasi. Cek inbox kamu.";
      }
      
      _showError(friendlyMessage);
      
    } catch (e) {
      // Error lain (koneksi, dll)
      _showError("Gagal terhubung. Periksa internetmu.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating, // Biar melayang lebih cantik
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            // Logo
            Image.asset('assets/images/logo.png', height: 80), 
            const SizedBox(height: 40),
            
            const Text(
              "Selamat Datang di Upsol",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Form
            CustomTextField(label: "Email", hint: "Masukkan email", controller: _emailController),
            const SizedBox(height: 20),
            CustomTextField(label: "Password", hint: "Masukkan password", controller: _passwordController, isPassword: true),
            
            // Lupa Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                   // Nanti kita buat fitur reset password
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Reset Password segera hadir!")));
                },
                child: const Text("Lupa Password?", style: TextStyle(color: Color(0xFFD32F2F))),
              ),
            ),
            
            const SizedBox(height: 20),

            // Tombol Masuk
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Masuk", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 30),

            // Link Daftar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Apakah belum punya akun? ", style: TextStyle(color: Colors.grey)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                  },
                  child: const Text("Daftar Disini", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
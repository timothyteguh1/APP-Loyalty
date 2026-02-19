import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import '../home/home_page.dart';
import 'register_page.dart';
import '../../utils/ui_helpers.dart'; // Pastikan file ini sudah ada (lihat kode helper sebelumnya)

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authController = AuthController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Variabel loading lokal tidak diperlukan lagi untuk tombol, 
  // karena kita pakai Overlay Loading (showLoading)
  // Tapi kita tetap simpan untuk mencegah double-tap
  bool _isProcessing = false;

  Future<void> _handleLogin() async {
    // 1. Validasi Input Kosong
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showCustomSnackBar("Email dan Password harus diisi ya.", Colors.orange);
      return;
    }

    // Cegah double tap
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // 2. TAMPILKAN LOADING SCENE
    showLoading(context);

    try {
      // 3. Proses Login ke Supabase
      await _authController.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      
      // 4. TUTUP LOADING SCENE
      hideLoading(context);

      // 5. SUKSES -> PINDAH KE HOME (Hapus riwayat halaman login)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );

    } on AuthException catch (e) {
      if (mounted) hideLoading(context); // Tutup loading kalau gagal
      
      // Terjemahkan Error agar user paham
      String friendlyMessage = "Terjadi kesalahan. Coba lagi nanti.";
      if (e.message.contains('Invalid login') || e.message.contains('invalid_credentials')) {
        friendlyMessage = "Email atau Password salah. Cek lagi ya!";
      } else if (e.message.contains('Email not confirmed')) {
        friendlyMessage = "Email belum diverifikasi. Cek inbox kamu.";
      }
      
      _showCustomSnackBar(friendlyMessage, Colors.red);
      
    } catch (e) {
      if (mounted) hideLoading(context); // Tutup loading kalau error koneksi
      _showCustomSnackBar("Gagal terhubung. Periksa internetmu.", Colors.red);
      
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Helper untuk SnackBar Custom yang cantik
  void _showCustomSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, 
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center( // Center agar di layar besar (Web/Tablet) tetap di tengah
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO APLIKASI
              Image.asset(
                'assets/images/logo.png', 
                height: 80,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 80, color: Colors.red),
              ), 
              const SizedBox(height: 40),
              
              const Text(
                "Selamat Datang di Upsol",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                "Masuk untuk melanjutkan",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // INPUT EMAIL
              CustomTextField(
                label: "Email", 
                hint: "Masukkan email", 
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              
              // INPUT PASSWORD
              CustomTextField(
                label: "Password", 
                hint: "Masukkan password", 
                controller: _passwordController, 
                isPassword: true
              ),
              
              // LUPA PASSWORD
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                     _showCustomSnackBar("Fitur Reset Password segera hadir!", Colors.grey);
                  },
                  child: const Text("Lupa Password?", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w600)),
                ),
              ),
              
              const SizedBox(height: 20),

              // TOMBOL MASUK
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F), // Merah Upsol
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Lebih tumpul
                    elevation: 2,
                  ),
                  onPressed: _handleLogin, // Panggil fungsi login
                  child: const Text(
                    "Masuk", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // LINK DAFTAR
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Belum punya akun? ", style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () {
                      // Pindah ke Register Page dengan animasi Slide (Opsional, kalau mau pakai helper)
                      // navigateTo(context, const RegisterPage()); 
                      
                      // Atau pakai cara biasa:
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                    },
                    child: const Text(
                      "Daftar Disini", 
                      style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
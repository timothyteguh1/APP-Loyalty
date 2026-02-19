import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import '../home/home_page.dart';
import '../../utils/ui_helpers.dart'; // Import Helper UI

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _authController = AuthController();
  
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedDomisili;
  bool _isProcessing = false; // Flag untuk cegah double tap

  final List<String> _listDomisili = [
    'Surabaya', 'Sidoarjo', 'Gresik', 'Malang', 'Jakarta', 'Lainnya'
  ];

  Future<void> _handleRegister() async {
    // 1. Validasi Input Dasar
    if (_emailController.text.isEmpty || _nameController.text.isEmpty || _selectedDomisili == null) {
      _showCustomSnackBar("Semua data wajib diisi ya!", Colors.orange);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showCustomSnackBar("Konfirmasi password tidak cocok.", Colors.red);
      return;
    }
    
    if (_passwordController.text.length < 6) {
      _showCustomSnackBar("Password minimal 6 karakter.", Colors.orange);
      return;
    }

    // Cegah Double Tap
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // 2. TAMPILKAN LOADING SCENE
    showLoading(context);

    try {
      // 3. Proses Sign Up
      await _authController.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        domisili: _selectedDomisili!, 
      );
      
      if (!mounted) return;

      // 4. SUKSES -> TUTUP LOADING
      hideLoading(context);

      _showCustomSnackBar("Pendaftaran Berhasil! Selamat datang.", Colors.green);

      // 5. PINDAH KE HOME
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (context) => const HomePage()), 
        (route) => false
      );

    } on AuthException catch (e) {
      if (mounted) hideLoading(context);
      
      // Terjemahkan Error
      String friendlyMsg = "Gagal mendaftar.";
      if (e.message.contains("User already registered")) {
        friendlyMsg = "Email ini sudah terdaftar. Coba login saja.";
      } else if (e.message.contains("weak_password")) {
        friendlyMsg = "Password terlalu lemah.";
      }

      _showCustomSnackBar(friendlyMsg, Colors.red);

    } catch (e) {
      if (mounted) hideLoading(context);
      _showCustomSnackBar("Terjadi kesalahan koneksi.", Colors.red);
      
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

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
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Buat Akun", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Logo Kecil di atas
                Image.asset('assets/images/logo.png', height: 60),
                const SizedBox(height: 30),
                
                const Text("Lengkapi Data Diri", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 30),
                
                // Form Fields
                CustomTextField(
                  label: "Nama Lengkap", 
                  hint: "Masukkan nama anda", 
                  controller: _nameController,
                  keyboardType: TextInputType.name, // Pastikan ini sesuai CustomTextField kamu
                ),
                const SizedBox(height: 15),
                
                CustomTextField(
                  label: "Email", 
                  hint: "Contoh: user@email.com", 
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),
                
                // DROPDOWN DOMISILI YANG LEBIH CANTIK
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Domisili", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                      ),
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.grey),
                      hint: const Text("Pilih Kota Domisili", style: TextStyle(fontSize: 14, color: Colors.grey)),
                      value: _selectedDomisili,
                      items: _listDomisili.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _selectedDomisili = v),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                CustomTextField(label: "Password", hint: "Minimal 6 karakter", controller: _passwordController, isPassword: true),
                const SizedBox(height: 15),
                CustomTextField(label: "Konfirmasi Password", hint: "Ulangi password", controller: _confirmPasswordController, isPassword: true),
                
                const SizedBox(height: 40),
                
                // TOMBOL DAFTAR
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), // Merah Upsol
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _handleRegister,
                    child: const Text("Daftar Sekarang", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
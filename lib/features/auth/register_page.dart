import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';

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
  bool _isLoading = false;

  final List<String> _listDomisili = ['Surabaya', 'Biak', 'Jakarta', 'Lainnya'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset('assets/images/logo.png', height: 80),
              const SizedBox(height: 20),
              const Text("Daftar Sekarang", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              CustomTextField(label: "Email", hint: "Masukkan email", controller: _emailController),
              const SizedBox(height: 15),
              CustomTextField(label: "Nama", hint: "Masukkan nama anda", controller: _nameController),
              const SizedBox(height: 15),
              
              // Field Domisili
              const Align(alignment: Alignment.centerLeft, child: Text("Domisili", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                ),
                hint: const Text("Pilih Domisili", style: TextStyle(fontSize: 14)),
                value: _selectedDomisili,
                items: _listDomisili.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedDomisili = v),
              ),
              const SizedBox(height: 15),
              CustomTextField(label: "Password", hint: "Masukkan password", controller: _passwordController, isPassword: true),
              const SizedBox(height: 15),
              CustomTextField(label: "Konfirmasi Password", hint: "Masukkan password lagi", controller: _confirmPasswordController, isPassword: true),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _isLoading ? null : () async {
                    if (_passwordController.text != _confirmPasswordController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password tidak cocok!")));
                      return;
                    }
                    // Jalankan _authController.signUp di sini...
                  },
                  child: const Text("Daftar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart'; // Sesuaikan path jika beda
import '../../widgets/primary_button.dart';   // Sesuaikan path jika beda

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.userMetadata?['full_name'] ?? '';
    }
  }

  // --- FUNGSI UPDATE DENGAN PROTEKSI CRASH ---
  Future<void> _updateProfile() async {
    // 1. MATIKAN KEYBOARD DULUAN (Wajib)
    // Ini agar layout stabil sebelum halaman ditutup
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isLoading = true);
    
    try {
      // 2. Update data ke Supabase
      final UserResponse response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
          },
        ),
      );

      // 3. Refresh Session Local agar halaman depan sadar ada perubahan
      if (response.user != null) {
        await _supabase.auth.refreshSession();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
        
        // 4. JEDA PENYELAMAT (Anti-Crash)
        // Kita tunggu 500ms agar animasi keyboard turun selesai 100%
        // Baru setelah itu kita tutup halamannya.
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
           Navigator.pop(context); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal update: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profil", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
            ),
            const SizedBox(height: 30),

            CustomTextField(
              label: "Nama Lengkap",
              hint: "Masukkan nama",
              controller: _nameController,
            ),
            const SizedBox(height: 20),
            
            // Email biasanya read-only
            IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: CustomTextField(
                  label: "Email",
                  hint: "Email",
                  controller: _emailController,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // TOMBOL SIMPAN (Yang tadi bikin crash)
            PrimaryButton(
              text: "SIMPAN PERUBAHAN",
              isLoading: _isLoading,
              onPressed: _updateProfile, // Memanggil fungsi aman di atas
            ),
          ],
        ),
      ),
    );
  }
}